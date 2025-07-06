#!/bin/sh

# install AWS CLI (if not already in image)
apk add --no-cache curl unzip python3 py3-pip
pip install awscli

# download tfvars file from S3
aws s3 cp s3://cloudlake-directory-tf-vars/envs/dev/terraform.tfvars terraform.tfvars
