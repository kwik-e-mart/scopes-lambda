# scopes-lambda Setup Guide

Step-by-step guide to configure and deploy the AWS Lambda scope provider.

---

## Prerequisites

- `np` CLI authenticated
- `aws` CLI configured with the appropriate profile
- `gomplate` installed
- Access to a running `np-agent` in the target environment

---

## Environment Variables

| Variable       | Description                                              | Example                                                        |
|----------------|----------------------------------------------------------|----------------------------------------------------------------|
| `NRN`          | Nullplatform resource NRN                                | `organization=1255165411:account=1332936918:namespace=848236203` |
| `REPO_PATH`    | Absolute path to the root of this repository            | `/root/.np/nullplatform/scopes-lambda`                         |
| `SERVICE_PATH` | Subdirectory containing the Lambda implementation        | `lambda` *(default)*                                           |
| `ENVIRONMENT`  | Target environment tag used to select the agent          | `javi-k8s`                                                     |
| `NP_API_KEY`   | Nullplatform API key                                     | `np_...`                                                       |
| `AWS_PROFILE`  | AWS CLI named profile                                    | `kwik`                                                         |

---

## Step 1 — Create the Lambda execution IAM role

Create a base IAM role that Lambda functions will assume. This role starts empty and policies are added per-scope as needed.

```bash
export AWS_PROFILE="kwik"

aws iam create-role \
  --role-name "kwik-nullplatform-lambda-execution-role" \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": { "Service": "lambda.amazonaws.com" },
        "Action": "sts:AssumeRole"
      }
    ]
  }' \
  --description "Lambda execution role for nullplatform scopes"
```

Expected output — note the `Arn`:
```json
{
  "Role": {
    "RoleName": "kwik-nullplatform-lambda-execution-role",
    "Arn": "arn:aws:iam::<account-id>:role/kwik-nullplatform-lambda-execution-role"
  }
}
```

---

## Step 2 — Patch the NRN with the role ARN

Patch the NRN so that `create_iam_role` picks up `aws_dedicated_role_arn` when creating scopes.

```bash
ROLE_ARN="arn:aws:iam::688720756067:role/kwik-nullplatform-lambda-execution-role"
ROLE_NAME="kwik-nullplatform-lambda-execution-role"
NRN="organization=1255165411:account=1332936918:namespace=848236203"

np nrn patch \
  --nrn "$NRN" \
  --body "{\"lambda.aws_dedicated_role_arn\": \"$ROLE_ARN\", \"lambda.aws_dedicated_role_name\": \"$ROLE_NAME\"}"
```

> **Note:** Patching at namespace level means all Lambda scopes under this namespace inherit the role.

---

## Step 3 — Register the scope provider

Run the `configure` script to register the service specification, action specs, scope type, and notification channel in nullplatform.

```bash
export NRN="organization=1255165411:account=1332936918:namespace=848236203"
export REPO_PATH="/root/.np/nullplatform/scopes-lambda"
export ENVIRONMENT="javi-k8s"
export NP_API_KEY="<your-api-key>"

./configure
```

---

## Step 4 — Configure the agent secret

The agent pod requires two additional environment variables for OpenTofu state management. Add them to the agent's Kubernetes Secret:

| Variable           | Description                                      | Example                                              |
|--------------------|--------------------------------------------------|------------------------------------------------------|
| `TOFU_STATE_BUCKET` | S3 bucket where Terraform state files are stored | `null-service-provisioning-kwik-e-mart-main`         |
| `TOFU_LOCK_TABLE`   | DynamoDB table used for state locking            | `service-provisioning-terraform-state-lock`          |

The table must have a partition key named `LockID` (String). A single table can be shared across multiple workspaces — each lock is identified by the full state path (`bucket/lambda/{scope_id}/terraform.tfstate`), so there is no collision between scopes.

To add the values, base64-encode them and patch the Secret:

```bash
kubectl patch secret nullplatform-agent-secret-javi \
  -n nullplatform-tools \
  --type merge \
  -p "{\"data\":{
    \"TOFU_STATE_BUCKET\": \"$(echo -n 'null-service-provisioning-kwik-e-mart-main' | base64)\",
    \"TOFU_LOCK_TABLE\": \"$(echo -n 'service-provisioning-terraform-state-lock' | base64)\"
  }}"
```

---

## Step 5 — Add the repo to the agent

Add this repo to the agent's list of command executor repos:

```
https://github.com/kwik-e-mart/scopes-lambda#main
```

---

---

## Teardown

To remove all resources created by `configure`:

1. Delete the notification channel: `np notification channel delete --id <NOTIFICATION_CHANNEL_ID>`
2. Delete the scope type: `np scope type delete --id <SCOPE_TYPE_ID>`
3. Delete the service specification: `np service specification delete --id <SERVICE_SPECIFICATION_ID>`
4. Remove the IAM role: `aws iam delete-role --role-name kwik-nullplatform-lambda-execution-role`
