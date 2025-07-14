# 🌩️ Terraform AWS Infrastructure - Cloudlake

This repository defines and provisions modular AWS infrastructure using Terraform, tailored for the Cloudlake platform. It includes core and data-related AWS services, network components, monitoring, and environment-specific configurations.

---

## 📁 Project Structure

```bash
.terraform/ # Cached modules/plugins
scripts/ # Helper scripts
├── backend-env.sh # Detects environment from branch
└── download-tfvars.sh # Downloads tfvars from S3
.gitlab-ci.yml # GitLab CI/CD pipeline
terraform.tfvars # Default tfvars (overridden by downloaded one)
backend-.hcl # Backend config per environment
aws-resources-core-.tf # Core AWS infrastructure
aws-resources-data-*.tf # Data and analytics infrastructure
aws-resources-lake-formation.tf # Lake Formation setup
outputs.tf # Output values
provider_only_local.tf # Local provider config for non-remote ops
main.tf # Root Terraform module
variables.tf # Input variables definition
README.md # You are here 🚀
```
---

## 🔁 CI/CD Pipeline

This project uses GitLab CI/CD with the following stages:

- `init`: Initializes Terraform with backend config.
- `validate`: Ensures configuration is syntactically valid.
- `plan`: Produces a detailed execution plan.
- `apply`: Manually triggered on `dev`, `stage`, or `prod` to apply infrastructure changes.

See `.gitlab-ci.yml` for full implementation.

### 🔐 Environments and State Backends

Each environment (`dev`, `stage`, `prod`) uses its own remote backend defined in:
- `backend-dev.hcl`
- `backend-stage.hcl`
- `backend-prod.hcl`

The backend environment is selected dynamically by `scripts/backend-env.sh`.

---

## 🗂️ tfvars Management

`terraform.tfvars` is downloaded dynamically by the pipeline from an S3 bucket using:

```bash
scripts/download-tfvars.sh

S3 structure:

s3://cloudlake-directory-tf-vars/envs/dev/terraform.tfvars
s3://cloudlake-directory-tf-vars/envs/stage/terraform.tfvars
s3://cloudlake-directory-tf-vars/envs/prod/terraform.tfvars

```

## 🌿 Branching Strategy & Workflow

Branch Name	Purpose	Auto Apply	Environment
feature/*	New infrastructure	❌	dev (default)
dev	Development	✅ (manual)	dev
stage	Pre-production	✅ (manual)	stage
prod	Production	✅ (manual)	prod

All new infrastructure must be developed in a feature/* branch. MRs should target dev, stage, or prod depending on deployment scope.

## 🛠️ Requesting Infrastructure
To request infrastructure:

1. Open a ticket with:

    - Purpose and resource description

    - Environment: dev, stage, or prod

    - Cost center tag (if required)

2. Assign to a DevOps engineer.

3. DevOps will:

    - Create a feature/* branch

    - Implement changes

    - Open an PR

    - Share terraform plan output

    - Merge and apply infrastructure upon approval

## 🔍 How to Run Locally

```bash

# Install Terraform (v1.4+ recommended)

- terraform init -reconfigure -backend-config=backend-dev.hcl
- terraform plan -var-file=terraform.tfvars
- terraform apply -var-file=terraform.tfvars
```

🔒 Avoid using terraform apply on stage or prod locally. Use the CI pipeline instead.

## 📦 Modules and Services

- Networking: VPCs, subnets, route tables

- Data Platform: EMR, Redshift, S3, MSK

- Security: IAM roles, KMS encryption

- Observability: CloudWatch, Cost Monitoring

- Governance: AWS Lake Formation

## 📜 Outputs
Outputs from deployed infrastructure are defined in outputs.tf.

## 🧪 Testing & Validation

Every push triggers:

- terraform validate

- terraform plan with preview output

Use Merge Requests to review plan output before approval.

## 📸 Diagram (CI/CD Flow)

```bash
gitlab      feature     branch     master
  |           |           |          |
  |---------->init        |          |
  |---------->validate    |          |
  |--------------------->plan        |
  |<---------Infra is created upon merge
  |----------------------------->merge
```

📬 Support
For issues or help, contact the DevOps team via JIRA or Teams.


# ⚙️ Terraform CI/CD Pipeline
This project uses GitLab CI/CD to automate Terraform workflows in a consistent and secure manner. The pipeline supports multiple environments (dev, stage, prod) and uses an S3 bucket for remote state management.

## 📋 Pipeline Stages
- init – Initializes the Terraform working directory with the correct backend configuration.

- validate – Validates the Terraform configuration files.

- plan – Generates an execution plan and outputs it for review.

- apply – Applies the Terraform plan manually from protected branches (dev, stage, prod).

## 🔄 Branch-Based Behavior
- Feature branches trigger init, validate, and plan stages.

- dev, stage, prod branches allow manual apply for controlled infrastructure changes.

## 🧠 Scripts
- scripts/backend-env.sh – Determines the backend config based on the branch.

- scripts/download-tfvars.sh – Downloads the correct terraform.tfvars file from S3 using AWS CLI.

## 🔐 Security

- Terraform runs in isolated Docker containers using hashicorp/terraform:latest.

- AWS credentials must be configured securely via GitLab CI/CD variables