# -----------------------------------------------------------------------------
# 1. TIER 1: ALB SECURITY GROUP (Internet Facing)
# -----------------------------------------------------------------------------
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Controls public ingress to Application Load Balancer"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from Internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # ALB egress remains broad here so health checks and application forwarding work
  # without coupling both security groups through inline bidirectional references.
  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-alb-sg"
    Tier = "Tier1-Web"
  }
}

# -----------------------------------------------------------------------------
# 2. TIER 2: EC2 APP SECURITY GROUP (Private Compute Tier)
# -----------------------------------------------------------------------------
resource "aws_security_group" "app" {
  name        = "${var.project_name}-app-sg"
  description = "Allows application ingress only from the ALB security group"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "HTTP from ALB only"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # Application instances need outbound access to RDS, package repositories,
  # Systems Manager and AWS APIs through the NAT path.
  egress {
    description = "Allow outbound traffic from private application instances"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-app-sg"
    Tier = "Tier2-App"
  }
}

# -----------------------------------------------------------------------------
# 3. TIER 3: DATABASE SECURITY GROUP (Isolated Data Tier)
# -----------------------------------------------------------------------------
resource "aws_security_group" "database" {
  name        = "${var.project_name}-database-sg"
  description = "Allows MySQL ingress only from the application security group"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "MySQL from application tier only"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  # No explicit egress rule: response traffic for established connections is
  # permitted because security groups are stateful.

  tags = {
    Name = "${var.project_name}-database-sg"
    Tier = "Tier3-Database"
  }
}
