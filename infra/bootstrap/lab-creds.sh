#!/bin/bash
# Run once per Learner Lab session, after pasting the lab's "AWS CLI" credentials
# into ~/.aws/credentials. Copies them to Infisical (env prod, folder /ci), where the
# GitHub Actions pipeline reads them. Needs `infisical login`.
set -euo pipefail
export AWS_PAGER=""
cd "$(dirname "$0")/../.." # repo root: .infisical.yaml selects the project

# Fails fast if the credentials are missing or expired.
aws sts get-caller-identity --query Arn --output text

# Creates the folder on the first run; "already exists" is fine.
infisical secrets folders create --env=prod --path=/ --name=ci --silent >/dev/null 2>&1 || true

# `secrets set` prints the values, so its output is discarded.
infisical secrets set --env=prod --path=/ci --silent \
  "AWS_ACCESS_KEY_ID=$(aws configure get aws_access_key_id)" \
  "AWS_SECRET_ACCESS_KEY=$(aws configure get aws_secret_access_key)" \
  "AWS_SESSION_TOKEN=$(aws configure get aws_session_token)" >/dev/null

echo "AWS credentials updated in Infisical (prod:/ci)."
