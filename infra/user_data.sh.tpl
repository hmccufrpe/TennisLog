#!/bin/bash
# Boot script (rendered by Terraform): installs Docker and writes a deploy script.
# The same script is what the CI/CD pipeline will call through SSM in Phase 4.
set -euo pipefail
exec > >(tee -a /var/log/tennislog-userdata.log) 2>&1

dnf install -y docker
systemctl enable --now docker

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
docker run -d --name backend --network tennislog --restart unless-stopped \
  -e "ConnectionStrings__Default=Host=${db_host};Port=5432;Database=${db_name};Username=${db_user};Password=$DB_PASSWORD;SSL Mode=Require;Trust Server Certificate=true" \
  "$BACKEND_IMAGE"
docker run -d --name frontend --network tennislog --restart unless-stopped \
  -p 80:80 "$FRONTEND_IMAGE"
DEPLOY
chmod +x /opt/tennislog-deploy.sh

# First attempt; fails harmlessly until the images exist in ECR.
/opt/tennislog-deploy.sh || echo "Initial deploy skipped: push the images, then rerun /opt/tennislog-deploy.sh"
