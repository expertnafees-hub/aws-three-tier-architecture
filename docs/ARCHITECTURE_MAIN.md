# Current main architecture — audited snapshot

Source: commit [`1c68c55f5c4308cdd2837ebde8528c28355f28e4`](https://github.com/expertnafees-hub/aws-three-tier-architecture/tree/1c68c55f5c4308cdd2837ebde8528c28355f28e4), reviewed 2026-09-16. This diagram is a code-derived design, **not a deployment diagram or test result**.

```mermaid
flowchart TB
  User["Internet client"] -->|"HTTP 80 by default"| ALB
  DNS["Optional Route 53 alias"] -.->|"DNS resolution, not a proxy"| ALB
  ACM["Optional ACM certificate"] -.->|"HTTPS 443; HTTP redirects"| ALB
  subgraph VPC["VPC 10.0.0.0/16 — two AZs by default"]
    subgraph Public["Public tier — routes to Internet Gateway"]
      ALB["Internet-facing ALB across both public subnets"]
      NAT_A["NAT A + EIP / 10.0.1.0/24"]
      NAT_B["NAT B + EIP / 10.0.2.0/24"]
    end
    subgraph App["Private app tier — ASG min 2 / desired 2 / max 4"]
      EC2_A["AZ A: 10.0.10.0/24 / Nginx EC2"]
      EC2_B["AZ B: 10.0.11.0/24 / Nginx EC2"]
    end
    subgraph Data["Isolated DB tier — local routes only"]
      DB["One RDS MySQL instance / encrypted storage"]
      DBNet["Subnet group: 10.0.20.0/24 + 10.0.21.0/24"]
      DBNet --- DB
    end
    ALB -->|"HTTP 80 + health checks"| EC2_A
    ALB -->|"HTTP 80 + health checks"| EC2_B
    EC2_A -->|"Outbound default route"| NAT_A
    EC2_B -->|"Outbound default route"| NAT_B
    EC2_A -.->|"TCP 3306 permitted; no demo queries"| DB
    EC2_B -.->|"TCP 3306 permitted; no demo queries"| DB
  end
  NAT_A --> IGW["Internet Gateway"]
  NAT_B --> IGW
  IGW --> APIs["Package repositories and public AWS API endpoints"]
  DB -.->|"Managed master credentials"| Secret["Secrets Manager"]
```

The ASG selects subnets across two AZs; the nodes illustrate intended distribution, not evidence of live instances. RDS uses a two-AZ subnet group but is **Single-AZ by default**; `db_multi_az = true` requests a standby. The code does not select a fixed primary DB AZ. There is no separate web-server fleet: the public tier is the ALB, and Nginx is the application-tier demo.

Solid arrows show configured request/egress paths, not observed traffic. Dashed arrows show optional configuration, credentials management, or permitted-but-unused DB connectivity. Route 53 resolves names and ACM supplies the certificate; neither is an inline network hop. ALB-to-EC2 traffic remains HTTP even with external HTTPS.

SSM administration uses the instance role, SSM agent and outbound NAT access; there are no SSH rules or VPC endpoints. Four CloudWatch alarms cover target 5xx, target p95 latency, unhealthy target count and ASG CPU. They publish to SNS; email needs an address and subscription confirmation. The dashboard covers ALB and EC2, not RDS or application logs.

## Main-specific caveats

- EC2 can read the RDS master secret by default, but the demo never reads it.
- Launch template uses `$Latest`; edits do not reliably trigger the declared refresh.
- Root EBS encryption and EC2 detailed monitoring are not explicitly configured.
- ALB and app egress are unrestricted; public subnets auto-assign IPv4 to instances launched there (the app template separately disables it).
- RDS backup retention is omitted; no configured backup/restore evidence exists.
- The checked-in CI validation passed, while its advisory tfsec scan reported 15 potential problems.
- Same-AZ NAT routing holds for default equal subnet lists; arbitrary unequal lists can select a NAT in another AZ.

See [audit](AUDIT.md) for evidence and proposed fixes. See [review pack](INSTRUCTOR_REVIEW_PACK.md) for the proposed branch state.
