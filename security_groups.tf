# -----------------------------------------------------------------------------
# 1. TIER 1: ALB SECURITY GROUP (Internet Facing)
# -----------------------------------------------------------------------------
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Controls public ingress to Application Load Balancer"
  vpc_id      = aws_vpc.main.id

  # Ingress: Allow HTTP from everywhere
  ingress {
    description = "HTTP from Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Ingress: Allow HTTPS from everywhere
  ingress {
    description = "HTTPS from Internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Egress: Forward traffic to backend app servers
  egress {
    description = "Allow all outbound traffic"
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
# 2. TIER 2: EC2 APP SECURITY GROUP (Compute Tier)
# -----------------------------------------------------------------------------
resource "aws_security_group" "app" {
  name        = "${var.project_name}-app-sg"
  description = "Allows ingress ONLY from ALB"
  vpc_id      = aws_vpc.main.id

  # Ingress: Port 80 ONLY from ALB Security Group!
  ingress {
    description     = "HTTP from ALB Only"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # Egress: Allow outbound (e.g. to talk to Database or AWS services)
  egress {
    description = "Allow all outbound traffic"
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
# 3. TIER 3: DATABASE SECURITY GROUP (Data Tier)
# -----------------------------------------------------------------------------
resource "aws_security_group" "database" {
  name        = "${var.project_name}-database-sg"
  description = "Allows MySQL/Aurora ingress ONLY from App instances"
  vpc_id      = aws_vpc.main.id

  # Ingress: MySQL (3306) ONLY from EC2 App Security Group!
  ingress {
    description     = "MySQL from App tier only"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  # Egress: Strictly none (or restricted)
  egress {
    description = "Outbound rule"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-database-sg"
    Tier = "Tier3-Database"
  }
}
