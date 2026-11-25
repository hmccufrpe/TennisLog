#!/bin/bash
# Boot script (rendered by Terraform): installs Docker and writes a deploy script.
# The same script is what the CI/CD pipeline will call through SSM in Phase 4.
set -euo pipefail
exec > >(tee -a /var/log/tennislog-userdata.log) 2>&1

dnf install -y docker
systemctl enable --now docker

# Alloy config (observability/alloy/config.alloy): ships the container logs to Loki.
mkdir -p /opt/tennislog
cat > /opt/tennislog/config.alloy <<'ALLOY'
${alloy_config}
ALLOY

cat > /opt/tennislog-deploy.sh <<'DEPLOY'
#!/bin/bash
# Idempotent deploy: pulls the images from ECR and (re)starts both containers.
# Usage: /opt/tennislog-deploy.sh [image-tag]   (default tag: latest)
set -euo pipefail

TAG=latest
if [ $# -ge 1 ]; then TAG=$1; fi

REGION="${region}"
BACKEND_IMAGE="${backend_image}:$TAG"
FRONTEND_IMAGE="${frontend_image}:$TAG"

# The DB password lives in SSM Parameter Store; the instance role may read only that parameter.
DB_PASSWORD=$(aws ssm get-parameter --region "$REGION" --name "${db_password_param}" \
  --with-decryption --query Parameter.Value --output text)

aws ecr get-login-password --region "$REGION" \
  | docker login --username AWS --password-stdin "${registry}"
docker pull "$BACKEND_IMAGE"
docker pull "$FRONTEND_IMAGE"

# User-defined network: nginx reaches the API by the container name "backend".
docker network inspect tennislog >/dev/null 2>&1 || docker network create tennislog
docker rm -f frontend backend >/dev/null 2>&1 || true

# RDS (PostgreSQL 16) enforces TLS by default, hence SSL Mode=Require.
# Port 8080 is published for Prometheus; the security group opens it only to the monitoring host.
docker run -d --name backend --network tennislog --restart unless-stopped -p 8080:8080 \
  -e "ConnectionStrings__Default=Host=${db_host};Port=5432;Database=${db_name};Username=${db_user};Password=$DB_PASSWORD;SSL Mode=Require;Trust Server Certificate=true" \
  "$BACKEND_IMAGE"
docker run -d --name frontend --network tennislog --restart unless-stopped \
  -p 80:80 "$FRONTEND_IMAGE"

# Log shipping, only once the monitoring instance exists (its Loki URL is in SSM).
LOKI_URL=$(aws ssm get-parameter --region "$REGION" --name "${loki_url_param}" \
  --query Parameter.Value --output text 2>/dev/null || true)
if [ -n "$LOKI_URL" ]; then
  docker rm -f alloy >/dev/null 2>&1 || true
  docker run -d --name alloy --restart unless-stopped \
    -e "LOKI_URL=$LOKI_URL" -e "HOST=$(hostname)" \
    -v /var/run/docker.sock:/var/run/docker.sock:ro \
    -v /opt/tennislog/config.alloy:/etc/alloy/config.alloy:ro \
    grafana/alloy:v1.22.0 run /etc/alloy/config.alloy
else
  echo "Loki URL not found in SSM; skipping Alloy."
fi

# Succeed only when this host answers (nginx -> API -> database); the pipeline relies on it.
for i in $(seq 1 30); do
  if curl -sf http://localhost/api/health; then echo " ($TAG)"; exit 0; fi
  sleep 2
done
echo "Health check failed for $TAG" >&2
docker logs --tail 50 backend >&2
exit 1
DEPLOY
chmod +x /opt/tennislog-deploy.sh

# First attempt; fails harmlessly until the images exist in ECR.
/opt/tennislog-deploy.sh || echo "Initial deploy skipped: push the images, then rerun /opt/tennislog-deploy.sh"
