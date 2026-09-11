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
# 2. ATTACH AWS MANAGED SSM CORE POLICY (Enables Session Manager Shell)
# -----------------------------------------------------------------------------
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2_ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# -----------------------------------------------------------------------------
# 3. LEAST-PRIVILEGE POLICY: SECRETS MANAGER READ (Explicitly Scoped)
# -----------------------------------------------------------------------------
resource "aws_iam_policy" "secrets_read" {
  name_prefix = "${var.project_name}-secrets-read-"
  description = "Allows EC2 instances to retrieve database credentials from AWS Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = aws_secretsmanager_secret.db_credentials.arn
      }
    ]
  })

  tags = {
    Name    = "${var.project_name}-secrets-read-policy"
    Managed = "Terraform"
  }
}

resource "aws_iam_role_policy_attachment" "secrets_read" {
  role       = aws_iam_role.ec2_ssm.name
  policy_arn = aws_iam_policy.secrets_read.arn
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
