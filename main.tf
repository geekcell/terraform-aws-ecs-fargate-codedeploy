/**
 * # Terraform AWS ECS Fargate CodeDeploy
 *
 * This Terraform module offers a streamlined solution for deploying and managing AWS Elastic Container Service (ECS)
 * on AWS Fargate in your AWS account. AWS Fargate is a serverless compute engine designed for running containers,
 * enabling you to focus on your applications without worrying about managing the underlying infrastructure. By
 * utilizing this Terraform module, you can effectively set up and manage your containerized applications, ensuring
 * they are highly available and can scale to accommodate increased traffic.
 *
 * Our team possesses in-depth knowledge of AWS container services and has fine-tuned this module to deliver the best
 * possible experience for users. The module encompasses all essential configurations, making it simple to use and
 * integrate into your existing AWS ecosystem. Whether you are just beginning your journey with containerized
 * applications or seeking a more efficient approach to manage your workloads, this Terraform module offers a
 * preconfigured solution for seamless scalability and high availability."
 */

locals {
  # Try to extract these values from taskDef if not provided
  lb_container_name = coalesce(var.load_balancer_container_name, try(var.task_container_definitions[0].name, null))
  lb_container_port = coalesce(var.load_balancer_container_port, try(var.task_container_definitions[0].portMappings[0].containerPort, null))
}

#
# Task Definition
#
module "task_definition" {
  source = "github.com/geekcell/terraform-aws-ecs-task-definition.git?ref=main"

  name = coalesce(var.task_definition_name, var.name)

  # FARGATE SPECIFIC
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]

  # Pass-through
  enable_execute_command           = var.enable_execute_command
  cpu                              = var.task_cpu
  memory                           = var.task_memory
  container_definitions            = var.task_container_definitions
  operating_system_family          = var.task_operating_system_family
  cpu_architecture                 = var.task_cpu_architecture
  ephemeral_storage_size_in_gib    = var.task_ephemeral_storage_size_in_gib
  volumes                          = var.task_volumes
  inference_accelerators           = var.task_inference_accelerators
  proxy_configuration              = var.task_proxy_configuration
  additional_execute_role_policies = var.task_additional_execute_role_policies
  additional_task_role_policies    = var.task_additional_task_role_policies
  tags                             = var.tags
}

#
# ECS Service
#
resource "aws_ecs_service" "main" {
  name = var.name

  task_definition                    = module.task_definition.arn
  cluster                            = var.ecs_cluster_name
  desired_count                      = var.desired_count
  deployment_maximum_percent         = var.deployment_maximum_percent
  deployment_minimum_healthy_percent = var.deployment_minimum_healthy_percent
  health_check_grace_period_seconds  = var.health_check_grace_period_seconds
  platform_version                   = var.platform_version
  enable_execute_command             = var.enable_execute_command

  # FARGATE specific
  launch_type         = "FARGATE"
  scheduling_strategy = "REPLICA"

  # CODE_DEPLOY specific
  wait_for_steady_state = false
  force_new_deployment  = false

  deployment_controller {
    type = "CODE_DEPLOY"
  }

  # CODE_DEPLOY does only support a single LB
  load_balancer {
    container_name   = local.lb_container_name
    container_port   = local.lb_container_port
    target_group_arn = aws_lb_target_group.main["blue"].arn
  }

  network_configuration {
    assign_public_ip = var.assign_public_ip
    security_groups  = var.security_group_ids
    subnets          = var.subnet_ids
  }

  dynamic "service_registries" {
    for_each = var.service_registries

    content {
      registry_arn   = service_registries.value.registry_arn
      port           = service_registries.value.port
      container_name = service_registries.value.container_name
      container_port = service_registries.value.container_port
    }
  }

  # Tags
  enable_ecs_managed_tags = var.enable_ecs_managed_tags
  propagate_tags          = var.propagate_tags
  tags                    = var.tags

  lifecycle {
    # These values will be updated by CodeDeploy after the initial setup and
    # can not be touched directly by TF again
    ignore_changes = [task_definition, network_configuration, load_balancer, desired_count]
  }

  depends_on = [module.task_definition, aws_lb_target_group.main]
}

#
# LB Target Groups
#
# https://github.com/hashicorp/terraform-provider-aws/issues/636
resource "random_id" "target_group" {
  for_each = toset(["blue", "green"])

  byte_length = 2
  keepers = {
    name     = "${var.name}-${each.value}"
    protocol = var.target_group_protocol
    vpc_id   = data.aws_subnet.main.vpc_id
  }
}

resource "aws_lb_target_group" "main" {
  for_each = toset(["blue", "green"])

  name = "${var.name}-${random_id.target_group[each.value].id}"

  vpc_id            = data.aws_subnet.main.vpc_id
  port              = local.lb_container_port
  protocol          = var.target_group_protocol
  protocol_version  = var.target_group_protocol_version
  proxy_protocol_v2 = var.target_group_proxy_protocol_v2

  slow_start             = var.target_group_slow_start
  connection_termination = var.target_group_connection_termination
  deregistration_delay   = var.target_group_deregistration_delay

  load_balancing_algorithm_type = var.target_group_load_balancing_algorithm_type

  # ECS specific value
  target_type = "ip"

  health_check {
    protocol = coalesce(var.target_group_health_check_protocol, var.target_group_protocol)
    port     = coalesce(var.target_group_health_check_port, local.lb_container_port)
    path     = var.target_group_health_check_path
    matcher  = var.target_group_health_check_matcher

    healthy_threshold   = var.target_group_health_check_healthy_threshold
    unhealthy_threshold = var.target_group_health_check_unhealthy_threshold

    interval = var.target_group_health_check_interval
    timeout  = var.target_group_health_check_timeout
  }

  lifecycle {
    create_before_destroy = true
  }
}

#
# AWS Application Load Balancer Listener
#
resource "aws_lb_listener" "main" {
  count = var.lb_listener == null ? 1 : 0

  load_balancer_arn = var.lb_arn
  port              = var.lb_listener_port
  protocol          = var.lb_listener_protocol

  ssl_policy      = var.lb_listener_protocol == "HTTPS" ? var.lb_listener_ssl_policy : null
  alpn_policy     = var.lb_listener_alpn_policy
  certificate_arn = var.lb_listener_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main["blue"].arn
  }

  lifecycle {
    # This changes on every deployment and will lead to downtime if changed to the wrong TG by TF
    ignore_changes = [default_action]
  }

  tags = var.tags

  depends_on = [aws_lb_target_group.main]
}

resource "aws_lb_listener" "test_listener" {
  count = var.enable_lb_test_listener && var.lb_test_listener == null ? 1 : 0

  load_balancer_arn = var.lb_arn
  port              = var.lb_test_listener_port
  protocol          = var.lb_test_listener_protocol

  ssl_policy      = var.lb_test_listener_protocol == "HTTPS" ? var.lb_test_listener_ssl_policy : null
  alpn_policy     = var.lb_test_listener_alpn_policy
  certificate_arn = var.lb_test_listener_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main["green"].arn
  }

  lifecycle {
    # This changes on every deployment and will lead to downtime if changed to the wrong TG by TF
    ignore_changes = [default_action]
  }

  depends_on = [aws_lb_target_group.main]
}

#
# CodeDeploy
#
resource "aws_codedeploy_app" "main" {
  name             = var.name
  compute_platform = "ECS"

  tags = var.tags
}

resource "aws_codedeploy_deployment_group" "main" {
  app_name               = aws_codedeploy_app.main.name
  deployment_group_name  = var.name
  deployment_config_name = var.codedeploy_deployment_config_name
  service_role_arn       = module.iam_role_codedeploy.arn

  ecs_service {
    cluster_name = var.ecs_cluster_name
    service_name = aws_ecs_service.main.name
  }

  deployment_style {
    deployment_type   = "BLUE_GREEN"
    deployment_option = "WITH_TRAFFIC_CONTROL"
  }

  blue_green_deployment_config {
    deployment_ready_option {
      action_on_timeout    = var.codedeploy_deployment_ready_wait_time_in_minutes == 0 ? "CONTINUE_DEPLOYMENT" : "STOP_DEPLOYMENT"
      wait_time_in_minutes = var.codedeploy_deployment_ready_wait_time_in_minutes
    }

    terminate_blue_instances_on_deployment_success {
      action                           = var.codedeploy_termination_action
      termination_wait_time_in_minutes = var.codedeploy_termination_wait_time_in_minutes
    }
  }

  auto_rollback_configuration {
    enabled = length(var.codedeploy_auto_rollback_events) > 0 ? true : false
    events  = var.codedeploy_auto_rollback_events
  }

  alarm_configuration {
    enabled = length(var.codedeploy_cloudwatch_alarm_names) > 0 ? true : false
    alarms  = var.codedeploy_cloudwatch_alarm_names
  }

  load_balancer_info {
    target_group_pair_info {
      # The listeners are arrays with a max size of 1: https://docs.aws.amazon.com/codedeploy/latest/APIReference/API_TrafficRoute.html
      prod_traffic_route {
        listener_arns = [var.lb_listener == null ? aws_lb_listener.main[0].arn : var.lb_listener]
      }

      dynamic "test_traffic_route" {
        for_each = var.enable_lb_test_listener || var.lb_test_listener != null ? [1] : []

        content {
          listener_arns = [var.lb_test_listener == null ? aws_lb_listener.main[0].arn : var.lb_test_listener]
        }
      }

      target_group {
        name = aws_lb_target_group.main["blue"].name
      }

      target_group {
        name = aws_lb_target_group.main["green"].name
      }
    }
  }

  depends_on = [aws_lb_target_group.main]

  tags = var.tags
}

#
# Cloudwatch
#
resource "aws_cloudwatch_log_group" "main" {
  count = var.create_cloudwatch_log_group ? 1 : 0

  name = coalesce(var.cloudwatch_log_group_name, "/aws/ecs/${var.ecs_cluster_name}/${var.name}")
}

#
# IAM Roles
#
module "iam_role_codedeploy" {
  source = "github.com/geekcell/terraform-aws-iam-role?ref=v1"

  name            = coalesce(var.codedeploy_role_name, "${var.name}-codedeploy")
  use_name_prefix = var.codedeploy_role_name_prefix

  assume_roles = { "Service" : { identifiers = ["codedeploy.amazonaws.com"] } }
  policy_arns  = ["arn:aws:iam::aws:policy/AWSCodeDeployRoleForECS"]
}
