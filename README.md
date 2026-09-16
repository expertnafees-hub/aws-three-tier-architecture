Terraform-based AWS three-tier architecture with public ALB, private Auto Scaling EC2, isolated RDS, IAM, Secrets Manager, CloudWatch, and optional Multi-AZ/HTTPS.
[![Terraform CI Validation](https://github.com/expertnafees-hub/aws-three-tier-architecture/actions/workflows/terraform-ci.yml/badge.svg)](https://github.com/expertnafees-hub/aws-three-tier-architecture/actions)
[![Terraform](https://img.shields.io/badge/Terraform-%3E%3D1.5-844FBA?logo=terraform&logoColor=white)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/AWS-Cloud-FF9900?logo=amazon-aws&logoColor=white)](https://aws.amazon.com/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

A production-style portfolio project that demonstrates how to build a three-tier AWS architecture with Terraform. The design applies AWS Well-Architected principles such as network isolation, least-privilege access, multi-AZ application capacity, encrypted data storage, observability, and automated health recovery.

This repository is intentionally honest about what is configurable versus what is enabled by default. Multi-AZ RDS and custom-domain HTTPS are supported but disabled by default to control lab cost.

## Architecture

```text
Internet
   |
   v
Route 53 + ACM (optional custom domain / HTTPS)
   |
   v
Application Load Balancer
Public subnets across two AZs
   |
   v
Auto Scaling Group
Private application subnets across two AZs
No public EC2 IPs
   |
   v
Amazon RDS MySQL
Isolated database subnets
Multi-AZ optional
```

Private application instances use one NAT Gateway per public subnet/AZ for outbound package installation, Systems Manager connectivity, and AWS API access. NAT Gateways incur hourly and data-processing charges.

## What is implemented

- VPC with public, private application, and isolated database subnet tiers
- Two Availability Zones by default
- Internet-facing Application Load Balancer
- EC2 Auto Scaling Group with two-instance baseline and ELB health checks
- EC2 instances in private subnets with no public IPv4 addresses
- NAT Gateway per public subnet/AZ for private-tier egress
- Security-group chaining: Internet -> ALB -> App -> Database
- No SSH ingress; Systems Manager is used for instance administration
- IMDSv2 required in the Launch Template
- RDS MySQL with public access disabled and storage encryption enabled
- RDS-managed master credentials stored in AWS Secrets Manager
- IAM policy scoped to the specific RDS-managed secret
- Optional RDS Multi-AZ deployment through `db_multi_az`
- Optional Route 53 + ACM HTTPS through `enable_custom_domain`
- CloudWatch alarms/dashboard and SNS notification support
- Terraform validation in GitHub Actions
- Controlled instance-failure runbook for testing ALB/ASG behavior

## Security model

### Tier 1: ALB
The ALB is internet-facing and accepts web traffic. When a custom domain is enabled, HTTP redirects to HTTPS and TLS terminates at the ALB.

### Tier 2: Application
Application instances receive traffic on port 80 only from the ALB security group. They run in private subnets and do not receive public IP addresses. Administrative access is designed around AWS Systems Manager rather than SSH.

### Tier 3: Database
RDS is not publicly accessible. MySQL port 3306 is reachable only from the application security group. Database subnets have no default internet route.

### Credentials
RDS generates and manages the master password through AWS Secrets Manager. The application IAM role is allowed to read only that specific secret. Secrets should still be treated carefully in logs, application output, plans, and operational tooling.

## Availability and recovery

The application tier spans two Availability Zones and uses an Auto Scaling Group attached to an ALB target group. ELB health checks allow unhealthy instances to be removed from service and replacement capacity to be launched.

This repository does **not** claim universal zero downtime. The included failure drill is a test procedure for observing behavior during a controlled single-instance termination. Any result should be reported exactly as observed, for example: "no failed requests were observed during this test run." See [`docs/CHAOS_RECOVERY_TEST.md`](docs/CHAOS_RECOVERY_TEST.md).

RDS Multi-AZ is configurable but disabled by default. Set `db_multi_az = true` only when you intentionally want the additional availability and cost.

## HTTPS and DNS

Custom-domain support is optional. With `enable_custom_domain = true` and an existing Route 53 public hosted zone, Terraform creates:

- an ACM certificate
- DNS validation records
- an HTTPS listener on the ALB
- an HTTP-to-HTTPS redirect
- a Route 53 alias to the ALB

With the default `enable_custom_domain = false`, the project exposes the ALB over HTTP for lab validation.

## Repository structure

```text
aws-three-tier-architecture/
├── providers.tf
├── variables.tf
├── vpc.tf
├── security_groups.tf
├── iam.tf
├── dns_acm.tf
├── alb.tf
├── compute.tf
├── database.tf
├── cloudwatch.tf
├── outputs.tf
├── docs/
│   └── CHAOS_RECOVERY_TEST.md
├── scripts/
│   └── chaos_test.sh
└── .github/workflows/
    └── terraform-ci.yml
```

## Prerequisites

- Terraform >= 1.5
- AWS CLI v2
- An authorized AWS sandbox/account
- A reviewed AMI ID for your selected region
- A Route 53 public hosted zone only if custom-domain support is enabled

## Validate

```bash
terraform init
terraform fmt -check -recursive
terraform validate
```

## Plan and deploy

Review cost before applying. This architecture creates NAT Gateways, an ALB, EC2 capacity, RDS, CloudWatch resources, and potentially other billable services.

```bash
aws sts get-caller-identity
terraform init
terraform plan -out=tfplan
terraform show tfplan
terraform apply tfplan
```

For a cost-controlled lab, leave these defaults unchanged unless you explicitly need them:

```hcl
db_multi_az         = false
enable_custom_domain = false
```

For a stronger HA demonstration, enable Multi-AZ RDS deliberately:

```hcl
db_multi_az = true
```

## Terraform state

This repository does not pretend that local state is production state management. Configure an encrypted remote backend with locking before collaborative or long-lived use. Never commit `terraform.tfstate`, saved plan files, or credentials.

## Failure test

The included runbook explains how to send continuous requests through the ALB, terminate one application instance, and observe target health and Auto Scaling recovery.

Use the result as measured evidence, not as a blanket claim. Preserve real timestamps/output if you want to discuss the test in an interview.

## Known limitations

- RDS Multi-AZ is disabled by default
- Custom-domain HTTPS is disabled by default
- No WAF is included in this repository
- No automated backup/restore drill is included
- No cross-region disaster recovery is implemented
- Terraform remote state is not preconfigured
- The Nginx demo is intentionally simple and is not a full application
- NAT Gateways add cost; destroy the lab when it is not needed

## Cleanup

```bash
terraform plan -destroy -out=destroy.tfplan
terraform show destroy.tfplan
terraform apply destroy.tfplan
```

Verify that NAT Gateways, Elastic IPs, ALB resources, EC2 capacity, RDS, snapshots, DNS records, and other retained resources are removed or intentionally preserved.

## Interview scope

This project is designed to demonstrate junior-level AWS DevOps skills in:

- VPC and subnet design
- routing and NAT
- security groups
- ALB and target groups
- Auto Scaling
- EC2 launch templates
- RDS networking and availability options
- IAM and Systems Manager
- Secrets Manager
- Route 53 and ACM
- CloudWatch
- Terraform
- failure testing and operational reasoning

The value of the project is not the number of AWS services used; it is being able to explain why each component exists, how traffic flows, what can fail, and how the system recovers.

## Author

**Nafees Ur Rehman**  
AWS DevOps / Cloud Engineering portfolio
