# PostgreSQL on RDS, private subnets only. The password is read from Infisical
# (see secrets.tf) and copied to SSM Parameter Store (SecureString); hosts read it
# at deploy time, so it never appears in user_data.

resource "aws_ssm_parameter" "db_password" {
  name  = "/${var.project}/db/password"
  type  = "SecureString"
  value = local.db_password
}

resource "aws_db_subnet_group" "main" {
  name       = "${var.project}-db"
  subnet_ids = aws_subnet.private[*].id
}

resource "aws_db_instance" "main" {
  identifier        = "${var.project}-db"
  engine            = "postgres"
  engine_version    = "16"
  instance_class    = var.db_instance_class
  allocated_storage = 20
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = var.db_name
  username = var.db_username
  password = local.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.db.id]
  publicly_accessible    = false
  multi_az               = false # single AZ to save cost; enable for real availability

  # Course setup: no backups or final snapshot so `terraform destroy` leaves nothing behind.
  backup_retention_period = 0
  skip_final_snapshot     = true
  deletion_protection     = false
  apply_immediately       = true
}
