# -----------------------------------------------------------------------------
# 1. EC2 INSTANCE IAM ROLE FOR AWS SYSTEMS MANAGER (SSM) & SECRETS ACCESS
# -----------------------------------------------------------------------------
resource "aws_iam_role" "ec2_ssm" {
  name_prefix = "${var.project_name}-ec2-ssm-role-"
  description = "IAM role allowing EC2 instances to communicate with AWS Systems Manager without open SSH ports"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name    = "${var.project_name}-ec2-ssm-role"
    Managed = "Terraform"
  }
}

# -----------------------------------------------------------------------------
# 2. AWS MANAGED SSM CORE POLICY
# -----------------------------------------------------------------------------
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2_ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# -----------------------------------------------------------------------------
# 3. LEAST-PRIVILEGE POLICY: READ ONLY THIS RDS-MANAGED SECRET
# -----------------------------------------------------------------------------
# Optional learning exercise only: the static demo has no database client.
# A real application should use its own restricted DB user, not the master user.
resource "aws_iam_policy" "secrets_read" {
  count = var.enable_demo_master_secret_access ? 1 : 0

  name_prefix = "${var.project_name}-secrets-read-"
  description = "Allows application instances to retrieve only the RDS-managed master credential secret"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = aws_db_instance.rds.master_user_secret[0].secret_arn
      }
    ]
  })

  tags = {
    Name    = "${var.project_name}-secrets-read-policy"
    Managed = "Terraform"
  }
}

resource "aws_iam_role_policy_attachment" "secrets_read" {
  count = var.enable_demo_master_secret_access ? 1 : 0

  role       = aws_iam_role.ec2_ssm.name
  policy_arn = aws_iam_policy.secrets_read[0].arn
}

# -----------------------------------------------------------------------------
# 4. EC2 INSTANCE PROFILE (Attached to Launch Template)
# -----------------------------------------------------------------------------
resource "aws_iam_instance_profile" "ec2_profile" {
  name_prefix = "${var.project_name}-ec2-profile-"
  role        = aws_iam_role.ec2_ssm.name

  tags = {
    Name    = "${var.project_name}-ec2-instance-profile"
    Managed = "Terraform"
  }
}
