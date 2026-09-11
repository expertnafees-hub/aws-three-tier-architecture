# 🚀 Production AWS Multi-AZ Three-Tier Architecture

[![Terraform CI Validation](https://github.com/expertnafees-hub/aws-three-tier-architecture/actions/workflows/terraform-ci.yml/badge.svg)](https://github.com/expertnafees-hub/aws-three-tier-architecture/actions)
[![Terraform](https://img.shields.io/badge/Terraform-v1.16+-844FBA?logo=terraform&logoColor=white)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/AWS-Cloud-FF9900?logo=amazon-aws&logoColor=white)](https://aws.amazon.com/)
[![Architecture](https://img.shields.io/badge/Architecture-3--Tier-22D3EE)](https://aws.amazon.com/architecture/)
[![Security](https://img.shields.io/badge/DevSecOps-IMDSv2%20%26%20Secrets%20Manager-3FB950)](https://aws.amazon.com/secrets-manager/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

An enterprise-grade, highly available, and fault-tolerant **Three-Tier Web Application Architecture** deployed across 2 Availability Zones (`us-east-1a` and `us-east-1b`) in AWS, fully codified using **Terraform (HCL)** strictly following the **AWS Well-Architected Framework**.

---

## 🏛️ High-Level System Architecture

```
                                  [ INTERNET ]
                                        │
                                  (HTTPS / HTTP)
                                        │
                                        ▼
               ┌──────────────────────────────────────────────────┐
               │         AWS VPC: 10.0.0.0/16 (us-east-1)         │
               │                                                  │
               │  [ TIER 1: PUBLIC WEB TIER ]                     │
               │  ┌──────────────────────┐┌────────────────────┐  │
               │  │ Public Subnet 1 (AZ-A)││Public Subnet 2 (B) │  │
               │  │     10.0.1.0/24      ││    10.0.2.0/24     │  │
               │  │  ┌───────────────────┴┴─────────────────┐  │  │
               │  │  │   Application Load Balancer (ALB)   │  │  │
               │  │  └───────────────────┬──────────────────┘  │  │
               │  └──────────────────────┼─────────────────────┘  │
               │                         │ (Chained SG: Port 80)  │
               │                         ▼                        │
               │  [ TIER 2: PRIVATE APPLICATION TIER ]            │
               │  ┌──────────────────────┐┌────────────────────┐  │
               │  │ Private Subnet 1 (A) ││Private Subnet 2 (B)│  │
               │  │    10.0.10.0/24      ││   10.0.11.0/24     │  │
               │  │  ┌─────────────────┐ ││ ┌────────────────┐ │  │
               │  │  │ EC2 (t3.micro)  │ ││ │ EC2 (t3.micro) │ │  │
               │  │  │ Nginx + IMDSv2  │ ││ │ Nginx + IMDSv2 │ │  │
               │  │  └────────┬────────┘ ││ └───────┬────────┘ │  │
               │  │           └──────────┬──────────┘          │  │
               │  │            Auto Scaling Group (2-4 nodes)  │  │
               │  └──────────────────────┼─────────────────────┘  │
               │                         │ (Chained SG: Port 3306)│
               │                         ▼                        │
               │  [ TIER 3: ISOLATED DATABASE TIER ]              │
               │  ┌──────────────────────┐┌────────────────────┐  │
               │  │ Database Subnet 1 (A)││Database Subnet 2 (B)│ │
               │  │    10.0.20.0/24      ││   10.0.21.0/24     │  │
               │  │  ┌───────────────────┴┴─────────────────┐  │  │
               │  │  │ Multi-AZ Amazon RDS MySQL (Encrypted)│  │  │
               │  │  └───────────────────┬──────────────────┘  │  │
               │  └──────────────────────┼─────────────────────┘  │
               │                         │                        │
               │                         ▼                        │
               │             [ AWS Secrets Manager ]              │
               │      (AES-256 KMS Vault for DB Credentials)      │
               └──────────────────────────────────────────────────┘
```

---

## 🛡️ Enterprise Engineering Highlights

1. **Zero Hardcoded Secrets (CWE-798 Elimination)**:
   - Database credentials are generated dynamically via Terraform's `random_password` provider.
   - Automatically injected into **AWS Secrets Manager** with AES-256 KMS encryption.
   - Zero passwords exist in Git, `.tf` files, or version control.

2. **Defense-in-Depth (Chained Security Groups)**:
   - **Tier 1 (ALB)**: Accepts HTTP/HTTPS traffic from `0.0.0.0/0`.
   - **Tier 2 (App)**: Ingress Port 80 restricted **strictly to `aws_security_group.alb.id`**. Direct public access is blocked.
   - **Tier 3 (Database)**: Ingress Port 3306 restricted **strictly to `aws_security_group.app.id`**. Neither public internet nor the load balancer can directly access the database.

3. **Zero-SSH Secure Management (AWS Systems Manager Session Manager)**:
   - Port 22 is completely omitted from all Security Groups — zero public management attack surface.
   - Instances assume an IAM role with `AmazonSSMManagedInstanceCore` and strictly scoped Secrets Manager read access.
   - Administrators connect directly via AWS Systems Manager Session Manager without managing SSH `.pem` keys or opening ingress ports.

4. **EC2 IMDSv2 Hardening**:
   - Instance Launch Templates strictly enforce `http_tokens = "required"` and hop limit `1`.
   - Blocks Server-Side Request Forgery (SSRF) metadata credential theft vulnerabilities.

5. **Self-Healing Multi-AZ Fleet**:
   - Auto Scaling Group automatically monitors instance health using **ELB health checks**.
   - Unhealthy instances are automatically terminated and re-provisioned in parallel availability zones.
   - Rolling updates configured with `instance_refresh` strategy.

6. **FinOps Cost Awareness**:
   - Eligible for AWS Free Tier (750h `t3.micro`, 750h `db.t3.micro`).
   - Parameterized switches for NAT Gateway and Multi-AZ RDS to avoid unnecessary cloud spend during staging.

7. **End-to-End TLS & Domain Automation (Route 53 + ACM HTTPS)**:
   - Modern TLS 1.3/1.2 termination on ALB Port 443 with automated ACM SSL/TLS certificates.
   - Permanent HTTP 301 redirection from Port 80 to Port 443, eliminating plaintext internet traffic.
   - Automated Route 53 DNS Alias records and validation handshakes.

8. **Chaos Engineering & Self-Healing Verification**:
   - Tested zero-downtime resilience under catastrophic EC2 failure.
   - Continuous HTTP probe shifts 100% of traffic to the surviving AZ with zero dropped requests (100% 200 OK).
   - Auto Scaling Group automatically detects the deficit and provisions replacement capacity within 90 seconds.
   - Complete verification runbook documented in [`docs/CHAOS_RECOVERY_TEST.md`](docs/CHAOS_RECOVERY_TEST.md).

9. **Full-Stack Observability & Automated Alerting (CloudWatch & SNS)**:
   - **ALB 5XX Target Errors**: Instant alarm upon receiving HTTP 5XX server errors from application instances.
   - **p95 Latency SLA Guard**: Evaluates target response times and alarms if p95 exceeds 1000ms.
   - **Fleet Health Monitoring**: Detects unhealthy instances failing ELB health checks.
   - **Compute Thresholds**: Monitors Auto Scaling Group CPU utilization with an 80% threshold.
   - **Codified Operational Dashboard**: CloudWatch dashboard displaying live ingress request volume, error splits, latency percentiles, and host health.

---

## 📁 Repository Structure

```tree
aws-three-tier-architecture/
├── providers.tf        # AWS & Random providers with strict semantic version constraints
├── variables.tf        # Clean input variable schemas with zero hardcoded defaults
├── vpc.tf              # VPC, 6 Subnets, Internet Gateway, DB Subnet Group, Route Tables
├── security_groups.tf  # 3 Chained security groups enforcing least-privilege (Zero Port 22)
├── iam.tf              # IAM Role & Instance Profile for AWS Systems Manager (SSM) Session Manager
├── dns_acm.tf          # Route 53 DNS Alias, ACM Certificate & Validation handshakes
├── alb.tf              # ALB, Target Group, HTTPS :443 Listener & HTTP :80 Redirect
├── compute.tf          # Launch Template (IMDSv2, Pinned AMI, Nginx), Auto Scaling Group
├── database.tf         # Multi-AZ RDS MySQL instance & AWS Secrets Manager vault
├── cloudwatch.tf       # CloudWatch Alarms (5XX, Latency, ASG CPU, Health) & Dashboard
├── outputs.tf          # Public ALB DNS URL, Application URL, VPC ID, and Secrets ARN
├── docs/
│   └── CHAOS_RECOVERY_TEST.md  # Step-by-step failure recovery drill & interview runbook
├── scripts/
│   └── chaos_test.sh           # Automated continuous HTTP availability & failover monitor
└── .gitignore          # Strict exclusion of .tfstate and sensitive variables
```

---

## 🧪 Chaos Engineering Drill: Proving Zero Downtime

Rather than merely assuming high availability works, this repository includes an empirical failure-injection runbook and probe script:

```bash
# 1. Run continuous traffic probe against the ALB
./scripts/chaos_test.sh

# 2. In another terminal, terminate an EC2 instance in us-east-1a
TARGET_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=three-tier-prod-asg-instance" "Name=instance-state-name,Values=running" \
  --query "Reservations[0].Instances[0].InstanceId" --output text)

aws ec2 terminate-instances --instance-ids "$TARGET_ID"

# 3. Observe: Zero dropped requests (100% 200 OK) as ALB drains and ASG replaces the node.
```
> For complete sequence diagrams and senior interview talking points, see [**docs/CHAOS_RECOVERY_TEST.md**](docs/CHAOS_RECOVERY_TEST.md).

---

## 📊 Observability & Operational Telemetry

This architecture codifies production-grade observability via **Amazon CloudWatch** and **Amazon SNS**:

| Metric Alarm | Threshold | Evaluation Window | Target Component |
| :--- | :--- | :--- | :--- |
| **`alb-high-5xx-errors`** | `HTTPCode_Target_5XX_Count > 0` | 1 period of 60s | Tier 1 Gateway / App Health |
| **`alb-high-target-latency`** | `TargetResponseTime (p95) > 1.0s` | 2 periods of 60s | Client User Experience (SLA) |
| **`tg-unhealthy-hosts`** | `UnHealthyHostCount > 0` | 1 period of 60s | Target Group Health State |
| **`asg-high-cpu-utilization`** | `CPUUtilization >= 80%` | 2 periods of 120s | Tier 2 Compute Fleet Sizing |

### Codified CloudWatch Dashboard
An automated operational dashboard (`three-tier-prod-telemetry`) aggregates:
- **ALB Ingress Traffic**: Request count alongside 4XX and 5XX error rates.
- **Latency Percentiles**: Real-time p95 and average target response times.
- **Fleet Availability**: Active healthy targets vs failing hosts across both AZs.
- **Compute Saturation**: Cluster-wide ASG CPU utilization.

---

## 🚀 Quickstart Deployment Guide

### Prerequisites
- [Terraform v1.5+](https://www.terraform.io/)
- [AWS CLI v2](https://aws.amazon.com/cli/) configured with proper IAM permissions

### Commands

```bash
# 1. Clone repository
git clone https://github.com/expertnafees-hub/aws-three-tier-architecture.git
cd aws-three-tier-architecture

# 2. Initialize provider plugins
terraform init

# 3. Format and validate HCL
terraform fmt
terraform validate

# 4. Perform dry-run plan
terraform plan

# 5. Provision architecture to AWS
terraform apply -auto-approve

# 6. Tear down resources (FinOps cleanup)
terraform destroy -auto-approve
```

---

## 👤 Author

**Nafees Ur Rehman**  
*AWS DevOps & Cloud Infrastructure Engineer*  
- **Portfolio**: [https://drqzr31lhv59g.cloudfront.net](https://drqzr31lhv59g.cloudfront.net)  
- **GitHub**: [@expertnafees-hub](https://github.com/expertnafees-hub)  
- **LinkedIn**: [Nafees Ur Rehman](https://www.linkedin.com/in/nafees-ur-rehman556/)
