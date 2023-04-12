module "basic-example" {
  source = "../../"

  name                       = "basic-example"
  ecs_cluster_name           = "example-cluster"
  lb_arn                     = "lb.aws.amazon.com"
  subnet_ids                 = ["subnet-123", "subnet-456", "subnet-789"]
  task_container_definitions = "nginx"
}
