#!/bin/bash
# Boot script of the monitoring instance (rendered by Terraform, sent gzip-compressed).
set -euo pipefail
exec > >(tee -a /var/log/tennislog-monitoring.log) 2>&1

dnf install -y docker
systemctl enable --now docker

# shortcut: always the latest Compose v2 release; pin a version if a release ever breaks this.
mkdir -p /usr/local/lib/docker/cli-plugins
curl -fsSL -o /usr/local/lib/docker/cli-plugins/docker-compose \
  https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

# Copy of the repository's observability/ folder.
mkdir -p /opt/observability
cd /opt/observability
%{ for path, content in files ~}
mkdir -p "$(dirname "${path}")"
cat > "${path}" <<'TENNISLOG_EOF'
${chomp(content)}
TENNISLOG_EOF
%{ endfor ~}

# Private IPs of the app hosts (port 8080), rendered by Terraform.
echo '${targets}' > prometheus/targets.json

GF_PASSWORD=$(aws ssm get-parameter --region "${region}" --name "${grafana_password_param}" \
  --with-decryption --query Parameter.Value --output text)
umask 077
printf 'GF_SECURITY_ADMIN_PASSWORD=%s\n' "$GF_PASSWORD" > .env

docker compose up -d
