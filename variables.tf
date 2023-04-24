## NAMING
variable "name" {
  description = "Base name of the created resources."
  type        = string
}

variable "tags" {
  description = "Tags to add to the created resources."
  default     = {}
  type        = map(any)
}

## TASK DEFINITION
variable "task_definition_name" {
  description = "Name of the task definition. Defaults to the base name."
  default     = null
  type        = string
}

variable "task_container_definitions" {
  description = "A list of valid container definitions provided as a valid HCL object list."
  type        = any
}

variable "task_memory" {
  description = "Amount (in MiB) of memory used by the task."
  default     = 2048
  type        = number
}

variable "task_cpu" {
  description = "Number of CPU units used by the task."
  default     = 1024
  type        = number
}

variable "task_operating_system_family" {
  description = "OS family required by the task."
  default     = "LINUX"
  type        = string

  validation {
    condition = contains([
      "LINUX", "WINDOWS_SERVER_2019_FULL", "WINDOWS_SERVER_2019_CORE", "WINDOWS_SERVER_2022_FULL",
      "WINDOWS_SERVER_2022_CORE"
    ], var.task_operating_system_family)
    error_message = "Value must be `X86_64` or `ARM64`."
  }
}

variable "task_cpu_architecture" {
  description = "CPU architecture required by the task."
  default     = "X86_64"
  type        = string

  validation {
    condition     = contains(["X86_64", "ARM64"], var.task_cpu_architecture)
    error_message = "Value must be `X86_64` or `ARM64`."
  }
}

variable "task_ephemeral_storage_size_in_gib" {
  description = "The amount of ephemeral storage (in GiB) to allocate to the task."
  default     = 20
  type        = number

  validation {
    condition     = var.task_ephemeral_storage_size_in_gib >= 20 && var.task_ephemeral_storage_size_in_gib <= 200
    error_message = "Value must be between 20 and 200."
  }
}

variable "task_volumes" {
  description = "A list of volume definitions."
  default     = []
  type = list(object({
    name      = string
    host_path = string

    docker_volume_configuration = optional(object({
      autoprovision = bool
      driver        = string
      driver_opts   = map(any)
      labels        = map(any)
      scope         = string
    }))

    efs_volume_configuration = optional(object({
      file_system_id          = string
      root_directory          = optional(string)
      transit_encryption      = optional(string)
      transit_encryption_port = optional(number)

      authorization_config = optional(object({
        access_point_id = string
        iam             = optional(string)
      }))
    }))
  }))
}

variable "task_inference_accelerators" {
  description = "List of Elastic Inference accelerators associated with the task."
  default     = []
  type = list(object({
    name = string
    type = string
  }))
}

variable "task_proxy_configuration" {
  description = "Configuration details for an App Mesh proxy."
  default     = null
  type = object({
    container_name = string
    properties     = map(any)
    type           = optional(string, "APPMESH")
  })
}

variable "task_additional_execute_role_policies" {
  description = "Additional policy ARNs to attach to the execution role."
  default     = []
  type        = list(string)
}

variable "task_additional_task_role_policies" {
  description = "Additional policy ARNs to attach to the task role."
  default     = []
  type        = list(string)
}

## ECS SERVICE
variable "ecs_cluster_name" {
  description = "ARN of an ECS cluster for the service."
  type        = string
}

variable "platform_version" {
  description = "Platform version on which to run your service."
  default     = "1.4.0"
  type        = string
}

variable "desired_count" {
  description = "Number of instances of the task definition to place and keep running."
  default     = 1
  type        = number
}

variable "deployment_minimum_healthy_percent" {
  description = "Lower limit (as a percentage of the service's `desired_count`) of the number of running tasks that must remain running and healthy in a service during a deployment."
  default     = 100
  type        = number
}

variable "deployment_maximum_percent" {
  description = "Upper limit (as a percentage of the service's `desired_count`) of the number of running tasks that can be running in a service during a deployment."
  default     = 200
  type        = number
}

variable "health_check_grace_period_seconds" {
  description = "Seconds to ignore failing load balancer health checks on newly instantiated tasks to prevent premature shutdown."
  default     = 0
  type        = number

  validation {
    condition     = var.health_check_grace_period_seconds >= 0 && var.health_check_grace_period_seconds <= 2147483647
    error_message = "Value must be between 0 and 2147483647."
  }
}

variable "assign_public_ip" {
  description = "Assign a public IP address to the ENI."
  default     = false
  type        = bool
}

variable "security_group_ids" {
  description = "Security groups associated with the task or service. If you do not specify a security group, the default security group for the VPC is used."
  default     = []
  type        = list(string)
}

variable "subnet_ids" {
  description = "Subnets associated with the task or service."
  type        = list(string)
}

variable "propagate_tags" {
  description = "Specifies whether to propagate the tags from the task definition or the service to the tasks."
  default     = "SERVICE"
  type        = string

  validation {
    condition     = contains(["SERVICE", "TASK_DEFINITION"], var.propagate_tags)
    error_message = "Value must be `SERVICE` or `TASK_DEFINITION`."
  }
}

variable "enable_ecs_managed_tags" {
  description = "Specifies whether to enable Amazon ECS managed tags for the tasks within the service."
  default     = false
  type        = bool
}

variable "service_registries" {
  description = "Service discovery registries for the service."
  default     = []
  type = list(object({
    registry_arn   = string
    port           = number
    container_name = optional(string)
    container_port = optional(number)
  }))
}

variable "enable_execute_command" {
  description = "Specifies whether to enable Amazon ECS Exec for the tasks within the service."
  default     = true
  type        = bool
}

# LOAD BALANCER
variable "load_balancer_container_name" {
  description = "Name of the container to associate with the load balancer (as it appears in a container definition). Default: Will use the name of the **first** container in the `task_container_definitions`."
  default     = null
  type        = string
}

variable "load_balancer_container_port" {
  description = "Port on the container to associate with the load balancer. Default: Will use the containerPort of the **first** containers **first** portMapping in the `task_container_definitions`."
  default     = null
  type        = number
}

# CODEDEPLOY
variable "codedeploy_auto_rollback_events" {
  description = "The event type or types that trigger a rollback. If none are defined `auto_rollback` will be disabled."
  default     = ["DEPLOYMENT_FAILURE", "DEPLOYMENT_STOP_ON_ALARM"]
  type        = list(string)
}

variable "codedeploy_deployment_ready_wait_time_in_minutes" {
  description = "The number of minutes to wait before the status of a blue/green deployment changed to Stopped if rerouting is not started manually. If set to 0 the deployment will continue without waiting for approval."
  default     = 0
  type        = number
}

variable "codedeploy_termination_action" {
  description = "The action to take on instances in the original environment after a successful blue/green deployment."
  default     = "TERMINATE"
  type        = string
}

variable "codedeploy_termination_wait_time_in_minutes" {
  description = "The number of minutes to wait after a successful blue/green deployment before terminating instances from the original environment."
  default     = 0
  type        = number
}

variable "codedeploy_deployment_config_name" {
  description = "The name of the group's deployment config."
  default     = "CodeDeployDefault.ECSAllAtOnce"
  type        = string
}

variable "codedeploy_role_name" {
  description = "The name of the role that allows CodeDeploy to make calls to ECS, Auto Scaling, and CloudWatch on your behalf."
  default     = null
  type        = string
}

variable "codedeploy_role_name_prefix" {
  description = "Whether to prefix the CodeDeploy role name."
  default     = false
  type        = bool
}

# CLOUDWATCH
variable "codedeploy_cloudwatch_alarm_names" {
  description = "Cloudwatch alarm NAMES (not ARNs) to add to the deployment group. Allows automated rollback on errors."
  default     = []
  type        = list(string)
}


# TARGET GROUP
variable "target_group_load_balancing_algorithm_type" {
  description = "Determines how the load balancer selects targets when routing requests."
  default     = "round_robin"
  type        = string

  validation {
    condition = contains([
      "round_robin", "least_outstanding_requests"
    ], var.target_group_load_balancing_algorithm_type)
    error_message = "Value must be `round_robin` or `least_outstanding_requests`."
  }
}

variable "target_group_deregistration_delay" {
  description = "Amount time in seconds for Elastic Load Balancing to wait before changing the state of a deregistering target from draining to unused."
  default     = 300
  type        = number

  validation {
    condition     = var.target_group_deregistration_delay >= 0 && var.target_group_deregistration_delay <= 3600
    error_message = "Value must be between 0 and 3600."
  }
}

variable "target_group_connection_termination" {
  description = "Whether to terminate connections at the end of the deregistration timeout on Network Load Balancers."
  default     = false
  type        = bool
}

variable "target_group_protocol" {
  description = "Protocol on the container to associate with the target group."
  default     = "HTTP"
  type        = string

  validation {
    condition     = contains(["GENEVE", "HTTP", "HTTPS", "TCP", "TCP_UDP", "TLS", "UDP"], var.target_group_protocol)
    error_message = "Value must be `GENEVE`, `HTTP`, `HTTPS`, `TCP`, `TCP_UDP`, `TLS` or `UDP`."
  }
}

variable "target_group_protocol_version" {
  description = "The protocol version."
  default     = "HTTP1"
  type        = string

  validation {
    condition     = contains(["HTTP1", "HTTP2", "GRPC"], var.target_group_protocol_version)
    error_message = "Value must be `HTTP1`, `HTTP2` or `GRPC`."
  }
}

variable "target_group_slow_start" {
  description = "Amount time for targets to warm up before the load balancer sends them a full share of requests."
  default     = 0
  type        = number

  validation {
    condition     = var.target_group_slow_start == 0 || (var.target_group_slow_start >= 30 && var.target_group_slow_start <= 900)
    error_message = "Value must be 0 to disable or between 30 and 900."
  }
}

variable "target_group_proxy_protocol_v2" {
  description = "Whether to enable support for proxy protocol v2 on Network Load Balancers."
  default     = false
  type        = bool
}

# TARGET GROUP HEALTH CHECK
variable "target_group_health_check_timeout" {
  description = "Amount of time, in seconds, during which no response means a failed health check."
  default     = 5
  type        = number
}

variable "target_group_health_check_interval" {
  description = "Approximate amount of time, in seconds, between health checks of an individual target."
  default     = 30
  type        = number

  validation {
    condition     = var.target_group_health_check_interval >= 5 && var.target_group_health_check_interval <= 300
    error_message = "Value must be between 5 and 300."
  }
}

variable "target_group_health_check_unhealthy_threshold" {
  description = "Number of consecutive health check failures required before considering the target unhealthy."
  default     = 3
  type        = number
}

variable "target_group_health_check_healthy_threshold" {
  description = "Number of consecutive health checks successes required before considering an unhealthy target healthy."
  default     = 3
  type        = number
}

variable "target_group_health_check_matcher" {
  description = "Response codes to use when checking for a healthy responses from a target. You can specify multiple values (for example, `200,202` for HTTP(s) or `0,12` for GRPC) or a range of values (for example, `200-299` or `0-99`)."
  default     = "200-299"
  type        = string
}

variable "target_group_health_check_path" {
  description = "Destination for the health check request."
  default     = "/health"
  type        = string
}

variable "target_group_health_check_port" {
  description = "Port to use to connect with the target."
  default     = "traffic-port"
  type        = any
}

variable "target_group_health_check_protocol" {
  description = "Protocol to use to connect with the target. Default: `target_group_protocol`."
  default     = null
  type        = string
}

# LOAD BALANCER LISTENER
variable "lb_arn" {
  description = "The ARN of the load balancer to attach to the service."
  type        = string
}

variable "lb_listener" {
  description = "Use an existing LB listener to attach to the service. If used, the other lb_* arguments are ignored."
  default     = null
  type        = string
}

variable "lb_listener_port" {
  description = "The port on the load balancer listener."
  default     = 80
  type        = number
}

variable "lb_listener_protocol" {
  description = "The protocol on the load balancer listener."
  default     = "HTTP"
  type        = string
}

variable "lb_listener_ssl_policy" {
  description = "The SSL policy to use for HTTPS listener."
  default     = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  type        = string
}

variable "lb_listener_alpn_policy" {
  description = "The ALPN policy to use for HTTPS listener."
  default     = null
  type        = string
}

variable "lb_listener_certificate_arn" {
  description = "The ARN of the certificate to use for HTTPS listener."
  default     = null
  type        = string
}

variable "enable_lb_test_listener" {
  description = "Enable a test listener on the load balancer. This is useful for testing the deployment process."
  default     = false
  type        = bool
}

variable "lb_test_listener" {
  description = "Use an existing LB test listener to attach to the service. If used, the other lb_test_* arguments are ignored."
  default     = null
  type        = string
}

variable "lb_test_listener_port" {
  description = "The port on the load balancer test listener."
  default     = 80
  type        = number
}

variable "lb_test_listener_protocol" {
  description = "The protocol on the load balancer test listener."
  default     = "HTTP"
  type        = string
}

variable "lb_test_listener_ssl_policy" {
  description = "The SSL policy to use for the test HTTPS listener."
  default     = "ELBSecurityPolicy-2016-08"
  type        = string
}

variable "lb_test_listener_alpn_policy" {
  description = "The ALPN policy to use for the test HTTPS listener."
  default     = "HTTP2Preferred"
  type        = string
}

variable "lb_test_listener_certificate_arn" {
  description = "The ARN of the certificate to use for the test HTTPS listener."
  default     = null
  type        = string
}

#
# Cloudwatch
#
variable "create_cloudwatch_log_group" {
  description = "Whether to create a CloudWatch log group for the service."
  default     = true
  type        = bool
}

variable "cloudwatch_log_group_name" {
  description = "The name of the CloudWatch log group."
  default     = null
  type        = string
}
