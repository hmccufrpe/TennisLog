#!/bin/bash
# Creates (or destroys) the S3 bucket that stores the Terraform remote state,
# and writes ../backend.hcl with its name.
#
# Done with the AWS CLI instead of Terraform because the AWS Academy Learner Lab
# SCP denies s3:GetBucketObjectLockConfiguration, which the Terraform AWS provider
# calls every time it manages an aws_s3_bucket resource.
#
# Usage: bash bootstrap.sh [create|destroy]   (default: create; both are idempotent)
set -euo pipefail

# Never open the CLI pager (less), which would block the script waiting for "q".
export AWS_PAGER=""

REGION="us-east-1"
PROJECT="tennislog"
ACTION="${1:-create}"

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET="$PROJECT-tfstate-$ACCOUNT_ID"
BACKEND_HCL="$(cd "$(dirname "$0")" && pwd)/../backend.hcl"

case "$ACTION" in
  create)
    if aws s3api head-bucket --bucket "$BUCKET" >/dev/null 2>&1; then
      echo "Bucket $BUCKET already exists."
    else
      # us-east-1 must NOT receive a LocationConstraint.
      aws s3api create-bucket --bucket "$BUCKET" --region "$REGION" >/dev/null
      echo "Bucket $BUCKET created."
    fi

    # Versioning lets you recover a previous state; public access stays fully blocked.
    aws s3api put-bucket-versioning --bucket "$BUCKET" \
      --versioning-configuration Status=Enabled
    aws s3api put-public-access-block --bucket "$BUCKET" \
      --public-access-block-configuration \
      BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

    printf 'bucket = "%s"\nregion = "%s"\n' "$BUCKET" "$REGION" > "$BACKEND_HCL"
    echo "Wrote $BACKEND_HCL"
    ;;

  destroy)
    # A versioned bucket must be emptied of every version and delete marker first.
    aws s3api list-object-versions --bucket "$BUCKET" --output text \
      --query '[Versions,DeleteMarkers][][].[Key,VersionId]' \
      | while read -r key version; do
          if [ -z "$key" ] || [ "$key" = "None" ]; then continue; fi
          aws s3api delete-object --bucket "$BUCKET" --key "$key" --version-id "$version" >/dev/null
        done
    aws s3api delete-bucket --bucket "$BUCKET" --region "$REGION"
    rm -f "$BACKEND_HCL"
    echo "Bucket $BUCKET deleted."
    ;;

  *)
    echo "Usage: bash bootstrap.sh [create|destroy]" >&2
    exit 1
    ;;
esac
