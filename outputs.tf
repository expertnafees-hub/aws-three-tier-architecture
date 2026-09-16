output "application_url" {
  description = "Primary entrypoint URL for the application (HTTPS when custom domain is enabled)"
  value       = var.enable_custom_domain ? "https://${var.domain_name}" : "http://${aws_lb.main.dns_name}"
}

output "alb_public_dns" {
  description = "Public DNS URL of the Application Load Balancer"
  value       = "http://${aws_lb.main.dns_name}"
}

output "vpc_id" {
  description = "VPC ID of the three-tier network"
  value       = aws_vpc.main.id
}

output "database_endpoint" {
  description = "Private endpoint of the RDS MySQL database"
  value       = aws_db_instance.rds.address
  sensitive   = true
}

output "rds_master_secret_arn" {
  description = "ARN of the RDS-managed Secrets Manager secret for the database master user"
  value       = aws_db_instance.rds.master_user_secret[0].secret_arn
}

output "cloudwatch_dashboard_name" {
  description = "Name of the CloudWatch observability dashboard"
  value       = aws_cloudwatch_dashboard.main.dashboard_name
}

output "sns_alerts_topic_arn" {
  description = "ARN of the SNS topic receiving CloudWatch metric alarm notifications"
  value       = aws_sns_topic.alerts.arn
}
