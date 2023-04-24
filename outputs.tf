## CODEDEPLOY
output "codedeploy_app_name" {
  value = aws_codedeploy_app.main.name
}

output "codedeploy_deployment_group_name" {
  value = aws_codedeploy_deployment_group.main.deployment_group_name
}

## ECS
output "service_name" {
  value = aws_ecs_service.main.name
}

## TARGET GROUPS
output "blue_target_group_arn" {
  value = aws_lb_target_group.main["blue"].arn
}

output "green_target_group_arn" {
  value = aws_lb_target_group.main["green"].arn
}

## TASK DEFINITION
output "task_definition_arn" {
  value = module.task_definition.arn
}

output "task_definition_task_role_name" {
  value = module.task_definition.task_role_name
}

output "task_definition_task_role_arn" {
  value = module.task_definition.task_role_arn
}

output "task_definition_execution_role_name" {
  value = module.task_definition.execution_role_name
}

output "task_definition_execution_role_arn" {
  value = module.task_definition.execution_role_arn
}

## CLOUDWATCH
output "cloudwatch_log_group_arn" {
  value = try(aws_cloudwatch_log_group.main[0].arn, null)
}
