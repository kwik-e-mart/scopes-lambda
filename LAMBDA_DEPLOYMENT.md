# AWS Lambda Scope Deployment Setup Guide

This guide covers the setup steps required to deploy AWS Lambda scopes with dedicated IAM roles. It details the external variables needed, their sources, and required prerequisites.

## Overview

Lambda scope deployment consists of **two main components**:

1. **IAM Role** – Dedicated AWS IAM role for the Lambda function (created during scope creation)
2. **Lambda Function** – AWS Lambda compute unit provisioned during deployment

All Lambda scopes **require a dedicated IAM role** created at scope creation time. This role is looked up and used during deployment to ensure proper permission boundaries and auditability.

---

## Prerequisites: Dedicated IAM Role

Before deploying a Lambda scope, a **dedicated IAM role must be created** during the scope creation workflow.

### How It Works

1. **Scope is created** via Nullplatform create workflow
2. **IAM role is provisioned** with the pattern: `{lambda-function-name}-role`
3. **Role ARN is exported** and passed to deployment steps
4. **Deployment uses the role** to configure Lambda execution permissions

### Role Requirements

- **Entity**: Per-scope (each scope gets its own role)
- **Permissions**: Configured based on scope capabilities and service integrations
- **Naming**: `{lambda-function-name}-role` (max 64 chars)

### If Role is Missing

If the IAM role is not found during deployment:

```
❌ IAM role 'function-name-role' not found

💡 Possible causes:
  • Scope was not created via the standard create workflow
  • create_iam_role script failed during scope creation

🔧 How to fix:
  • Re-run the scope create workflow to provision the IAM role
```

---

## Setup Step: Lambda Function Provisioning (Compute)

Lambda function provisioning is the core of deployment. All scope types require a Lambda function.

#### Required Variables

| Variable | Source | Purpose |
|----------|--------|---------|
| `AWS_REGION` | Helm values | AWS region for Lambda deployment |
| `TOFU_STATE_BUCKET` | Helm values | S3 bucket for Terraform state |
| `TOFU_STATE_REGION` | Helm values | Region for Terraform state bucket |
| `LAMBDA_ROLE_ARN` | IAM setup | ARN of dedicated Lambda execution role |

#### Helm Configuration

```yaml
configuration:
  TOFU_PATH: "$SERVICE_PATH/deployment"
  AWS_REGION: "us-east-1"
  TOFU_STATE_BUCKET: "terraform-state-bucket"
  TOFU_STATE_REGION: "us-east-1"
```

#### Lambda Configuration Parameters

| Variable | Default | Purpose |
|----------|---------|---------|
| `DEFAULT_MEMORY` | `256` | Memory allocation in MB |
| `DEFAULT_TIMEOUT` | `30` | Timeout in seconds |
| `DEFAULT_ARCHITECTURE` | `arm64` | CPU architecture (arm64 or x86_64) |
| `DEFAULT_EPHEMERAL_STORAGE` | `512` | Ephemeral storage in MB |
| `DEFAULT_RESERVED_CONCURRENCY_TYPE` | `unreserved` | Reserved or unreserved concurrency |
| `DEFAULT_PROVISIONED_CONCURRENCY_TYPE` | `unprovisioned` | Provisioned or unprovisioned concurrency |

#### Optional Variables

| Variable | Source | Purpose |
|----------|--------|---------|
| `NULL_AGENT_LAYER_ARN` | Helm values | ARN of Nullplatform observability Lambda layer |
| `USE_NULL_AGENT` | Helm values | Enable/disable agent layer injection |
| `PLACEHOLDER_IMAGE_URI` | Helm values | Placeholder container image (for initial deployments) |

---

## Deployment Checklist

Use this checklist to ensure all required variables are configured before deploying:

### Prerequisites

- [ ] **Scope created** via Nullplatform create workflow (provisions dedicated IAM role)
- [ ] **IAM role exists** with pattern `{lambda-function-name}-role`

### Required for All Scopes

- [ ] AWS Region configured (`AWS_REGION` in Helm values)
- [ ] Terraform state bucket configured (`TOFU_STATE_BUCKET` in Helm values)
- [ ] Terraform state region configured (`TOFU_STATE_REGION` in Helm values)
- [ ] Lambda function memory configured (`DEFAULT_MEMORY` in Helm values)
- [ ] Lambda function timeout configured (`DEFAULT_TIMEOUT` in Helm values)

### Optional Configuration

- [ ] Lambda architecture preference (`DEFAULT_ARCHITECTURE` - default: arm64)
- [ ] Ephemeral storage (`DEFAULT_EPHEMERAL_STORAGE` - default: 512 MB)
- [ ] Concurrency settings (`DEFAULT_RESERVED_CONCURRENCY_TYPE`, `DEFAULT_PROVISIONED_CONCURRENCY_TYPE`)
- [ ] Nullplatform agent layer (`USE_NULL_AGENT`, `NULL_AGENT_LAYER_ARN`)

---

## Troubleshooting

### "IAM role 'function-name-role' not found"

**Cause**: The dedicated IAM role was not created during scope creation.

**Fix**:
1. Verify the scope was created using the standard Nullplatform create workflow
2. Check that `create_iam_role` step executed successfully during scope creation
3. Re-run the scope create workflow if the role is missing
4. Verify the role exists in AWS: `aws iam get-role --role-name {lambda-function-name}-role`

### "Terraform state bucket not accessible"

**Cause**: Invalid `TOFU_STATE_BUCKET` or missing AWS permissions.

**Fix**:
1. Verify bucket exists: `aws s3 ls s3://{bucket-name}`
2. Ensure Helm values have correct bucket name: `TOFU_STATE_BUCKET`
3. Ensure Helm values have correct region: `TOFU_STATE_REGION`
4. Verify IAM policy includes S3 permissions:
   - `s3:GetObject`
   - `s3:PutObject`
   - `s3:DeleteObject`
   - `s3:ListBucket`

### "Lambda function deployment timeout"

**Cause**: Container image pull or initialization taking too long.

**Fix**:
1. Increase timeout: `DEPLOYMENT_MAX_WAIT_IN_SECONDS` in Helm values (default: 600)
2. Verify ECR image URI is correct: `PLACEHOLDER_IMAGE_URI`
3. Check CloudWatch logs for Lambda initialization errors

### "Permission denied: Lambda execution role"

**Cause**: Dedicated role lacks necessary permissions for scope integrations.

**Fix**:
1. Verify the role was created with appropriate policies during scope creation
2. Check role policies: `aws iam list-role-policies --role-name {lambda-function-name}-role`
3. If policies are missing, re-configure scope IAM settings and update role policies

---

## Configuration Examples

### Example 1: Standard Lambda Scope (256 MB, 30s timeout)

```yaml
# Helm values
configuration:
  AWS_REGION: "us-east-1"
  TOFU_STATE_BUCKET: "terraform-state-bucket"
  TOFU_STATE_REGION: "us-east-1"

  DEFAULT_MEMORY: 256
  DEFAULT_TIMEOUT: 30
  DEFAULT_ARCHITECTURE: "arm64"
  DEFAULT_EPHEMERAL_STORAGE: 512
  DEFAULT_RESERVED_CONCURRENCY_TYPE: "unreserved"
  DEFAULT_PROVISIONED_CONCURRENCY_TYPE: "unprovisioned"
```

**Result**: Lambda function provisioned with dedicated IAM role, ready for HTTP or event-driven integration.

### Example 2: High-Performance Lambda (1024 MB, 60s timeout)

```yaml
# Helm values
configuration:
  AWS_REGION: "us-east-1"
  TOFU_STATE_BUCKET: "terraform-state-bucket"
  TOFU_STATE_REGION: "us-east-1"

  DEFAULT_MEMORY: 1024
  DEFAULT_TIMEOUT: 60
  DEFAULT_ARCHITECTURE: "arm64"
  DEFAULT_EPHEMERAL_STORAGE: 10240  # 10 GB for large workloads
```

**Result**: Lambda function with higher memory/CPU and larger ephemeral storage.

### Example 3: Lambda with Provisioned Concurrency

```yaml
# Helm values
configuration:
  AWS_REGION: "us-east-1"
  TOFU_STATE_BUCKET: "terraform-state-bucket"
  TOFU_STATE_REGION: "us-east-1"

  DEFAULT_MEMORY: 512
  DEFAULT_TIMEOUT: 30
  DEFAULT_RESERVED_CONCURRENCY_TYPE: "reserved"
  DEFAULT_PROVISIONED_CONCURRENCY_TYPE: "provisioned"
  PROVISIONED_CONCURRENCY_MAX_WAIT_SECONDS: 600
```

**Result**: Lambda with reserved and provisioned concurrency for low-latency, predictable performance.

---

## Summary: Variables by Source

### From Helm Values (lambda/values.yaml)
- `AWS_REGION` – AWS region
- `TOFU_STATE_BUCKET` – Terraform state S3 bucket
- `TOFU_STATE_REGION` – Terraform state region
- `DEFAULT_MEMORY` – Lambda memory allocation (default: 256 MB)
- `DEFAULT_TIMEOUT` – Lambda timeout (default: 30 seconds)
- `DEFAULT_ARCHITECTURE` – CPU architecture (default: arm64)
- `DEFAULT_EPHEMERAL_STORAGE` – Ephemeral storage (default: 512 MB)
- `DEFAULT_RESERVED_CONCURRENCY_TYPE` – Reserved concurrency setting
- `DEFAULT_PROVISIONED_CONCURRENCY_TYPE` – Provisioned concurrency setting
- `PROVISIONED_CONCURRENCY_MAX_WAIT_SECONDS` – Max wait for provisioned concurrency
- `USE_NULL_AGENT` – Enable Nullplatform agent layer (default: true)
- `NULL_AGENT_LAYER_ARN` – Agent layer ARN
- `PLACEHOLDER_IMAGE_URI` – Placeholder container image

### From IAM Role (created at scope creation)
- `LAMBDA_ROLE_ARN` – Dedicated execution role ARN (auto-discovered from role name)

### From Scope Capabilities
- `memory` – Override default memory
- `timeout` – Override default timeout
