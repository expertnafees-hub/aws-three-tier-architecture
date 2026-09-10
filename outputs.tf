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
