output "application_url" {
  description = "Primary entrypoint URL for the application (HTTPS when custom domain is enabled)"
  value       = var.enable_custom_domain ? "https://${var.domain_name}" : "http://${aws_lb.main.dns_name}"
}

output "alb_public_dns" {
  description = "Public DNS URL of the Application Load Balancer"
  value       = "http://${aws_lb.main.dns_name}"
}

output "vpc_id" {
  description = "VPC ID of the 3-Tier Network"
  value       = aws_vpc.main.id
}

output "database_endpoint" {
  description = "Private endpoint of the RDS MySQL database (Isolated Tier)"
  value       = aws_db_instance.rds.address
  sensitive   = true
}

output "secrets_manager_secret_arn" {
  description = "ARN of the AWS Secrets Manager secret storing database credentials"
  value       = aws_secretsmanager_secret.db_credentials.arn
}

output "cloudwatch_dashboard_name" {
  description = "Name of the CloudWatch Observability Dashboard"
  value       = aws_cloudwatch_dashboard.main.dashboard_name
}

output "sns_alerts_topic_arn" {
  description = "ARN of the SNS topic receiving CloudWatch metric alarm notifications"
  value       = aws_sns_topic.alerts.arn
}
