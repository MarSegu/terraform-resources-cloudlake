#!/bin/sh
set -euo pipefail

echo "Installing dependencies..."
apk add --no-cache curl unzip python3 py3-pip >/dev/null

echo "Creating Python virtual environment..."
python3 -m venv /tmp/venv
. /tmp/venv/bin/activate

echo "Installing AWS CLI..."
pip install --quiet awscli

echo "Verifying AWS CLI..."
aws --version

# Use feature default if not dev/stage/prod
case "$CI_COMMIT_REF_NAME" in
  dev|stage|prod)
    ENV_PATH="$CI_COMMIT_REF_NAME"
    ;;
  *)
    ENV_PATH="feature"
    ;;
esac

TFVARS_PATH="envs/${ENV_PATH}/terraform.tfvars"
echo "Downloading tfvars from: s3://cloudlake-directory-tf-vars/${TFVARS_PATH}"
aws s3 cp "s3://cloudlake-directory-tf-vars/${TFVARS_PATH}" terraform.tfvars

echo "Deactivating virtual environment..."
deactivate
