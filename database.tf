# -----------------------------------------------------------------------------
# 1. RANDOM SUFFIX & CRYPTOGRAPHIC PASSWORD GENERATOR
# -----------------------------------------------------------------------------
resource "random_string" "db_suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "random_password" "db_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# -----------------------------------------------------------------------------
# 2. AWS SECRETS MANAGER (Encrypted Vault for DB Credentials)
# -----------------------------------------------------------------------------
resource "aws_secretsmanager_secret" "db_credentials" {
  name                    = "${var.project_name}-db-secret-${random_string.db_suffix.result}"
  description             = "Master database credentials for ${var.project_name} RDS MySQL"
  recovery_window_in_days = 0 # FinOps: Allows instant clean deletion during destroy

  tags = {
    Name = "${var.project_name}-db-secret"
    Tier = "Tier3-Database"
  }
}

resource "aws_secretsmanager_secret_version" "db_credentials_val" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    engine   = "mysql"
    host     = aws_db_instance.rds.address
    port     = 3306
    username = var.db_username
    password = random_password.db_password.result
    database = var.db_name
  })
}

# -----------------------------------------------------------------------------
# 3. TIER 3: RDS MYSQL INSTANCE (Consumes Secret Directly)
# -----------------------------------------------------------------------------
resource "aws_db_instance" "rds" {
  identifier        = "${var.project_name}-mysql"
  engine            = "mysql"
  engine_version    = "8.0"
  instance_class    = "db.t3.micro" # AWS Free Tier eligible
  allocated_storage = 20

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db_password.result # Injected directly from crypt-engine!

  # Subnet & Network Security
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.database.id]
  publicly_accessible    = false # Zero public exposure!

  # High Availability Toggle (Multi-AZ)
  multi_az = var.db_multi_az

  # Storage Encryption
  storage_encrypted = true

  # FinOps & Clean Teardown
  skip_final_snapshot = true
  deletion_protection = false

  tags = {
    Name = "${var.project_name}-rds-mysql"
    Tier = "Tier3-Database"
  }
}
