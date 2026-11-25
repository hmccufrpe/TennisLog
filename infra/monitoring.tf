# Monitoring instance (Fase 5): Prometheus + Loki + Grafana with Docker Compose.
# The files under observability/ are embedded in user_data (gzip, to stay under 16 KB).
# Prometheus scrapes the app hosts on 8080; Alloy on each app host pushes logs to Loki.

variable "monitoring_instance_type" {
  description = "EC2 type of the monitoring instance (Prometheus + Loki + Grafana need ~2 GB RAM)."
  type        = string
  default     = "t3.small"
}

variable "admin_cidr" {
  description = "CIDR allowed to open Grafana (3000) and Prometheus (9090), e.g. your IP: \"203.0.113.10/32\"."
  type        = string

  validation {
    condition     = can(cidrhost(var.admin_cidr, 0)) && var.admin_cidr != "0.0.0.0/0"
    error_message = "Use a valid CIDR for your own IP (e.g. 203.0.113.10/32), not 0.0.0.0/0."
  }
}

locals {
  observability_dir = "${path.module}/../observability"
  # Alloy's config goes to the app hosts; a local .env must never reach user_data.
  observability_files = {
    for f in fileset(local.observability_dir, "**") :
    f => file("${local.observability_dir}/${f}") if !startswith(f, "alloy/") && basename(f) != ".env"
  }
}

resource "aws_security_group" "monitoring" {
  name        = "${var.project}-monitoring"
  description = "Monitoring: Grafana/Prometheus from the admin IP, Loki from the app hosts"
  vpc_id      = aws_vpc.main.id
}

resource "aws_vpc_security_group_ingress_rule" "grafana_from_admin" {
  security_group_id = aws_security_group.monitoring.id
  cidr_ipv4         = var.admin_cidr
  ip_protocol       = "tcp"
  from_port         = 3000
  to_port           = 3000
}

resource "aws_vpc_security_group_ingress_rule" "prometheus_from_admin" {
  security_group_id = aws_security_group.monitoring.id
  cidr_ipv4         = var.admin_cidr
  ip_protocol       = "tcp"
  from_port         = 9090
  to_port           = 9090
}

resource "aws_vpc_security_group_ingress_rule" "loki_from_app" {
  security_group_id            = aws_security_group.monitoring.id
  referenced_security_group_id = aws_security_group.app.id
  ip_protocol                  = "tcp"
  from_port                    = 3100
  to_port                      = 3100
}

# Docker images, compose binary and SSM.
resource "aws_vpc_security_group_egress_rule" "monitoring_all_out" {
  security_group_id = aws_security_group.monitoring.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# /metrics on the app hosts, reachable only from the monitoring instance.
resource "aws_vpc_security_group_ingress_rule" "app_metrics_from_monitoring" {
  security_group_id            = aws_security_group.app.id
  referenced_security_group_id = aws_security_group.monitoring.id
  ip_protocol                  = "tcp"
  from_port                    = 8080
  to_port                      = 8080
}

# Grafana admin password: Infisical -> SSM SecureString -> read at boot (never in user_data).
resource "aws_ssm_parameter" "grafana_password" {
  name  = "/${var.project}/grafana/admin-password"
  type  = "SecureString"
  value = data.infisical_secrets.app.secrets["GF_SECURITY_ADMIN_PASSWORD"].value
}

resource "aws_instance" "monitoring" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.monitoring_instance_type
  subnet_id                   = aws_subnet.public[0].id
  vpc_security_group_ids      = [aws_security_group.monitoring.id]
  iam_instance_profile        = local.instance_profile_name
  associate_public_ip_address = true

  user_data_base64 = base64gzip(templatefile("${path.module}/monitoring_user_data.sh.tpl", {
    region                 = var.aws_region
    files                  = local.observability_files
    targets                = jsonencode([{ targets = [for i in aws_instance.app : "${i.private_ip}:8080"] }])
    grafana_password_param = aws_ssm_parameter.grafana_password.name
  }))
  user_data_replace_on_change = true

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
  }

  lifecycle {
    ignore_changes = [ami]
  }

  tags = { Name = "${var.project}-monitoring", Role = "monitoring" }
}

# The app hosts read this at deploy time to start Alloy. A parameter (and not a
# user_data value) avoids a cycle: monitoring already depends on the app IPs.
resource "aws_ssm_parameter" "loki_url" {
  name  = "/${var.project}/monitoring/loki-url"
  type  = "String"
  value = "http://${aws_instance.monitoring.private_ip}:3100/loki/api/v1/push"
}

output "grafana_url" {
  description = "Grafana (user admin, password GF_SECURITY_ADMIN_PASSWORD from Infisical prod)."
  value       = "http://${aws_instance.monitoring.public_ip}:3000"
}

output "prometheus_url" {
  value = "http://${aws_instance.monitoring.public_ip}:9090"
}
