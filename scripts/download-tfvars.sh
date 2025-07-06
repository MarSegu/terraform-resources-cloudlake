#!/bin/sh
set -e

if ! command -v aws >/dev/null 2>&1; then
  echo "Installing AWS CLI..."
  apk add --no-cache curl unzip python3 py3-pip
  pip install awscli
fi

python3 -m venv /tmp/venv
. /tmp/venv/bin/activate
pip install awscli
aws --version
echo "Downloading terraform.tfvars from S3..."
aws s3 cp s3://cloudlake-directory-tf-vars/envs/dev/terraform.tfvars terraform.tfvars
deactivate
