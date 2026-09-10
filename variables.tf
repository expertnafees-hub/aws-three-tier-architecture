variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name tag and naming prefix"
  type        = string
  default     = "three-tier-prod"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "production"
}

variable "vpc_cidr" {
  description = "CIDR block for the main VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private application subnets"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "database_subnet_cidrs" {
  description = "CIDR blocks for isolated database subnets"
  type        = list(string)
  default     = ["10.0.20.0/24", "10.0.21.0/24"]
}

variable "enable_nat_gateway" {
  description = "Toggle NAT Gateway creation (Set to false for zero-cost dev)"
  type        = bool
  default     = false
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "threetierdb"
}

variable "db_username" {
  description = "Master database administrator username"
  type        = string
  default     = "dbadmin"
}

variable "db_multi_az" {
  description = "Toggle Multi-AZ for RDS (Set to false for zero-cost free tier)"
  type        = bool
  default     = false
}
