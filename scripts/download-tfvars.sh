#!/bin/sh
set -e

echo "Installing dependencies..."
apk add --no-cache curl unzip python3 py3-pip

echo "Creating Python virtual environment..."
python3 -m venv /tmp/venv
. /tmp/venv/bin/activate

echo "Installing AWS CLI in virtual environment..."
pip install awscli

echo "Verifying AWS CLI..."
aws --version

echo "Downloading terraform.tfvars from S3..."
aws s3 cp s3://cloudlake-directory-tf-vars/envs/dev/terraform.tfvars terraform.tfvars

echo "Deactivating venv..."
deactivate
