# -----------------------------------------------------------------------------
# TIER 3: RDS MYSQL INSTANCE WITH AWS-MANAGED MASTER CREDENTIALS
# -----------------------------------------------------------------------------
resource "aws_db_instance" "rds" {
  identifier        = "${var.project_name}-mysql"
  engine            = "mysql"
  engine_version    = "8.0"
  instance_class    = "db.t3.micro"
  allocated_storage = 20

  db_name  = var.db_name
  username = var.db_username

  # Let RDS generate, store and rotate the master password through Secrets Manager.
  # Terraform never receives a configured plaintext password value.
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.database.id]
  publicly_accessible    = false

  # Optional because Multi-AZ roughly doubles database cost for this lab.
  multi_az = var.db_multi_az

  storage_encrypted       = true
  backup_retention_period = 7

  # Portfolio/lab cleanup settings. A production data store would normally use
  # deletion protection, backups and a final-snapshot policy appropriate to its RPO/RTO.
  skip_final_snapshot = true
  deletion_protection = false

  tags = {
    Name = "${var.project_name}-rds-mysql"
    Tier = "Tier3-Database"
  }
}
