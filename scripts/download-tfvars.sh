#!/bin/sh
set -euo pipefail

echo "Installing dependencies..."
apk add --no-cache curl unzip python3 py3-pip >/dev/null

echo "Creating Python virtual environment..."
python3 -m venv /tmp/venv
. /tmp/venv/bin/activate

echo "Installing AWS CLI in virtual environment..."
pip install --quiet awscli

echo "Verifying AWS CLI version..."
aws --version

echo "Downloading terraform.tfvars from S3..."
aws s3 cp "s3://cloudlake-directory-tf-vars/envs/${CI_COMMIT_REF_NAME}/terraform.tfvars" terraform.tfvars

echo "Deactivating virtual environment..."
deactivate
