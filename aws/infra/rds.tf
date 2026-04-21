# --- RDS PostgreSQL ---

resource "aws_db_subnet_group" "main" {
  name       = "${local.name_prefix}-db-subnet"
  subnet_ids = aws_subnet.private[*].id

  tags = { Name = "${local.name_prefix}-db-subnet-group" }
}

resource "random_password" "db_password" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"

  # Prevent regeneration on subsequent applies — password is stable once created
  lifecycle {
    ignore_changes = [length, special, override_special]
  }
}

resource "aws_db_instance" "main" {
  identifier = "${local.name_prefix}-postgres"

  engine         = "postgres"
  engine_version = "16.13"
  instance_class = var.db_instance_class

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db_password.result

  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp3"
  storage_encrypted     = true

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  multi_az               = false # set to true for HA later

  # Automated backups
  backup_retention_period = var.db_backup_retention_days
  backup_window           = "03:00-04:00"
  maintenance_window      = "sun:04:00-sun:05:00"

  # Point-in-time recovery is enabled automatically when backup_retention_period > 0

  skip_final_snapshot       = false
  final_snapshot_identifier = "${local.name_prefix}-final-snapshot"

  lifecycle {
    ignore_changes = [final_snapshot_identifier]
  }

  deletion_protection = true

  tags = { Name = "${local.name_prefix}-postgres" }
}

# Store DB password in SSM Parameter Store
resource "aws_ssm_parameter" "db_password" {
  name  = "/${var.app_name}/${var.environment}/database-password"
  type  = "SecureString"
  value = random_password.db_password.result

  tags = { Name = "${local.name_prefix}-db-password" }
}

# Full DATABASE_URL (username:password@host/db) stored as a single secret
resource "aws_ssm_parameter" "database_url" {
  name  = "/${var.app_name}/${var.environment}/database-url"
  type  = "SecureString"
  value = "ecto://${var.db_username}:${random_password.db_password.result}@${aws_db_instance.main.endpoint}/${var.db_name}"

  tags = { Name = "${local.name_prefix}-database-url" }
}
