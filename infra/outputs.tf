output "app_url" {
  description = "Public URL of the application (ALB)."
  value       = "http://${aws_lb.main.dns_name}"
}

output "ecr_registry" {
  description = "ECR registry host, used for docker login."
  value       = split("/", aws_ecr_repository.app["backend"].repository_url)[0]
}

output "ecr_backend_url" {
  value = aws_ecr_repository.app["backend"].repository_url
}

output "ecr_frontend_url" {
  value = aws_ecr_repository.app["frontend"].repository_url
}

output "rds_endpoint" {
  value = aws_db_instance.main.address
}

output "instance_ids" {
  value = aws_instance.app[*].id
}

output "deploy_command" {
  description = "Reruns the deploy script on every app instance through SSM Run Command."
  value       = "aws ssm send-command --region ${var.aws_region} --document-name AWS-RunShellScript --targets Key=tag:Project,Values=${var.project} Key=tag:Role,Values=app --parameters commands=/opt/tennislog-deploy.sh --query Command.CommandId --output text"
}
