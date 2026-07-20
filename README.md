# Claude Apps Gateway - Starter Kit

Drop-in files to build and deploy the Claude Apps Gateway with Microsoft Entra ID.

## Files

```
SETUP-GUIDE.pdf    ← Full step-by-step deployment guide (start here)
.env.example       ← Copy to .env, fill in your 4 Entra values + AWS account
gateway.yaml       ← Config template (@@PLACEHOLDERS@@ stamped at build time)
Dockerfile         ← Builds the gateway container (pins claude v2.1.202)
build-and-push.sh  ← One script: stamps config → docker build → push to ECR
```

## Quick Start

```bash
# 1. Fill in your values
cp .env.example .env
nano .env

# 2. Generate secrets (paste output into .env)
echo "GATEWAY_JWT_SECRET=$(openssl rand -base64 32)"
echo "GATEWAY_ADMIN_WRITE_KEY=$(openssl rand -hex 32)"
echo "GATEWAY_ADMIN_READ_KEY=$(openssl rand -hex 32)"

# 3. Build and push
chmod +x build-and-push.sh
./build-and-push.sh
```

## What's Next After the Image is in ECR

You need AWS infrastructure (VPC, internal ALB, RDS, ECS, DNS, TLS cert).

**Option A (recommended):** Use the official CDK stack:
```bash
git clone https://github.com/aws-samples/anthropic-on-aws.git
cd anthropic-on-aws/claude-apps-gateway/cdk
# Map your .env values into cdk/.env and run ./scripts/deploy.sh
```

**Option B:** Build it yourself with Terraform/CloudFormation. Required resources:
- Internal ALB (IPv4-only!) + ACM cert (enterprise CA, not self-signed)
- ECS Fargate service pointing at your ECR image
- RDS PostgreSQL (db.t4g.micro, sslmode=require)
- Route53 private hosted zone + Resolver inbound endpoints
- IAM task role: bedrock:InvokeModel + bedrock:InvokeModelWithResponseStream
- Secrets Manager: OIDC_CLIENT_SECRET, GATEWAY_JWT_SECRET, admin keys
- VPC Endpoints: bedrock-runtime, secretsmanager, ecr, logs, s3

## Reference

- Full step-by-step guide: `SETUP-GUIDE.pdf` (included in this package)
- Official SA Field Guide: https://github.com/aws-samples/anthropic-on-aws/tree/main/claude-apps-gateway
- Anthropic docs: https://code.claude.com/docs/en/claude-apps-gateway
