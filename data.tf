data "aws_subnet" "main" {
  id = element(var.subnet_ids, 0)
}
