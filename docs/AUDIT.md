# Source audit — 2026-09-16

## Scope and verdict

Audited all 18 tracked files at main commit [`1c68c55f5c4308cdd2837ebde8528c28355f28e4`](https://github.com/expertnafees-hub/aws-three-tier-architecture/tree/1c68c55f5c4308cdd2837ebde8528c28355f28e4): all 11 Terraform files, README, runbook, shell probe, workflow, metadata, ignore rules and license. There was no AGENTS.md in the tracked tree.

**Verdict:** a credible junior infrastructure portfolio base, but not a demonstrated three-tier application or production system. The key credibility risk is mistaking declared resources and green static CI for a deployed, integrated and tested system. No AWS Console, AWS API calls, plan, apply or failure drill was used during this review.

## Evidence available

- [Main CI run 35141561165](https://github.com/expertnafees-hub/aws-three-tier-architecture/actions/runs/35141561165): push event at the exact audited SHA; format, init and validate succeeded.
- [Validation job](https://github.com/expertnafees-hub/aws-three-tier-architecture/actions/runs/35141561165/job/104947057931): Terraform 1.8.5, AWS provider 5.100.0 installed successfully.
- [Security job](https://github.com/expertnafees-hub/aws-three-tier-architecture/actions/runs/35141561165/job/104947058204): tfsec 1.28.14 reported 25 passed and **15 potential problems: 5 critical, 5 high, 4 medium, 1 low**. `soft_fail: true` meant these did not fail CI. Scanner severity is not the reviewer's risk assessment; an intentionally public ALB is not itself a design error.
- No tracked apply output, target-health captures, database integration tests, restore results or completed failure-drill logs. Runbook examples are not evidence.

## Findings and branch disposition

| Priority | Main finding and source | Why it matters | Proposed branch disposition |
| --- | --- | --- | --- |
| High | `compute.tf` serves static HTML; no database client or secret retrieval; README traffic diagram implied a complete app path | RDS existence is not app/DB integration | README, diagram and page explicitly say no DB queries; DB edges are permitted-only |
| High | `compute.tf` ASG uses literal `$Latest` with instance refresh | Template edits do not trigger the promised refresh through that unchanged string | Uses numeric `latest_version`; runtime refresh remains untested |
| High | `iam.tf` gives every static web instance master-secret read permission | A compromised web instance could obtain DB administrator credentials it does not need | Policy/attachment disabled by default; explicit demo-only opt-in; real restricted DB user remains future work |
| High | `compute.tf` depends on subnet IDs, not completed routes/associations | Instances can boot before NAT egress is ready and fail package installation | ASG waits for public/private route associations and SSM policy attachment; not a guarantee against repository/network failure |
| Medium | Root EBS encryption omitted in `compute.tf` | Encryption depended on external account/AMI settings | Explicit encrypted gp3 root mapping; supplied AMI must use `/dev/xvda` |
| Medium | `cloudwatch.tf` uses ASG CPU dimension and short periods; launch template omitted detailed monitoring | ASG CPU metric availability/cadence did not match alarm intent | Enable detailed monitoring; document additional cost |
| Medium | `compute.tf` ignores target-group attachment drift | Terraform could silently stop managing an important traffic relationship | Remove `ignore_changes` for target groups/load balancers |
| Medium | `security_groups.tf` ALB allows all outbound protocols/destinations | Unnecessary scope | Restrict inline egress to TCP 80 in private app subnet CIDRs; app ingress still requires ALB SG; app egress remains broad and documented |
| Medium | `alb.tf` omitted invalid-header dropping | Avoidable request hardening gap | Enable `drop_invalid_header_fields` |
| Medium | `database.tf` omitted backup retention | No explicit retained-backup policy | Set seven days; restore not tested; deletion protection/final snapshot remain lab limitations |
| Medium | `vpc.tf` NAT modulo indexing with arbitrarily different subnet-list lengths | Could silently route across AZs and contradict per-AZ claims | Require equal counts of at least two within available AZ count; direct same-index NAT; review CIDR overlap/containment separately |
| Medium | Fixed default AMI with configurable region in `variables.tf` | ID availability, owner and compatibility were unverified | Require explicit reviewed AL2023 x86_64 ID; syntax validation only |
| Medium | `dns_acm.tf` allowed empty domain in enabled mode | Invalid configuration failed later during lookup/certificate operations | Add enabled-mode precondition; document hosted zone/apex and delegation requirement |
| Medium | Broad “enterprise”, “Tier 3 monitoring”, instant/SLA comments in `cloudwatch.tf` | Only four ALB/EC2 alarms and dashboard exist | Remove unsupported claims; explicitly state no DB/log monitoring |
| Medium | CI security is soft-fail but indistinguishable from a hard gate to a casual reviewer | Green badge conceals findings | Name and summary explicitly advisory; keep unsuppressed scan visible; document residual findings |
| Medium | `.gitignore` omitted README's `tfplan` and `destroy.tfplan` | Saved plans may accidentally be committed with sensitive data | Ignore those plan patterns and probe logs; still review files manually |
| Low | Public subnets auto-assign IPv4 despite only hosting ALB/NAT | Future EC2 placements could acquire public addresses unnecessarily | Disable auto-assignment; IGW routes still make them public and NAT uses EIPs |
| Low | Nginx starts before content is complete; IMDS curl lacks bounded/error handling | Default page can satisfy health checks; metadata failures can be silent | Write page and run nginx config check first; bounded, failure-aware metadata calls |
| Low | Page exposes private IP and implies RDS-backed service | Unnecessary metadata exposure / credibility risk | Remove private IP and correct DB label; instance ID/AZ remain deliberate public lab diagnostics |
| Low | Probe returns `000000` on some curl failures, hardcodes us-east-1, claims exactly one request per second | Misleading test records | Normalize transport failure to `000`, general AZ regex, UTC dates, accurate serial cadence and TERM summary |
| Low | Workflow metadata file tracked despite ignore rule | Tool debris in portfolio | Remove tracked metadata |
| Low | Mutable CI action tags / provider range | CI behavior can change without a source change | Pin action SHAs observed in successful main CI, tfsec version and AWS provider 5.100.0; checksum lock file remains outstanding |
| Low | `production` environment label | Oversells a disposable lab | Default label becomes `lab`; preserve legacy project-name default to avoid broad resource renaming |

## README-to-code verification matrix

| Requested area | Main implementation and exact qualifications |
| --- | --- |
| VPC/subnets | DNS-enabled VPC; two public, two app and two DB subnets by default, indexed into available AZs |
| NAT | Two NAT/EIPs default; IGW public route; private default routes; default same-AZ topology is correct |
| ALB | Public, two subnets; port 80 forwarding by default; `/` health check; optional 443 plus 80 redirect |
| ASG | Desired/min 2, max 4, ELB checks and 300-second grace; no scaling policy; refresh originally used `$Latest` |
| Private EC2 | Public IP disabled both in subnet and template; Nginx static page; no SSH; no DB integration |
| RDS | Private encrypted MySQL 8.0 family; Single-AZ default; two-subnet group is not two running DB instances; no deletion protection/final snapshot |
| IAM | EC2 trust + SSM core + exact RDS secret read; “least privilege” was too broad a description because master access was unnecessary |
| Secrets Manager | RDS creates/manages master secret; no plaintext password input; no demo read/query code |
| CloudWatch | Four ALB/EC2 alarms; dashboard; SNS; no DB metrics, log collection, synthetic checks or delivery proof |
| Route 53/ACM | Optional existing-zone lookup, certificate validation, apex A alias and HTTPS listener; disabled default; no new hosted zone |
| Security groups | ALB public 80/443, app 80 from ALB SG, DB 3306 from app SG; no SSH; ALB/app egress broad on main |
| IMDSv2 | Tokens required; endpoint enabled; hop limit 1; user data requests a token |
| CI | Format/init/validate, advisory tfsec; no AWS credentials/OIDC, plan, apply, integration tests or deployment pipeline |
| Encryption/KMS | RDS storage encryption requested; no customer-managed key resources or KMS key policies; EC2 encryption absent on main |
| References | Existing local README/runbook links and Terraform output names resolve; updated docs remove ambiguous claim wording; not every third-party URL was availability-tested |

## Remaining scanner findings / accepted lab constraints

Main scanner findings included HTTP, public ALB and ingress, broad egress, invalid headers, unencrypted SNS, public subnet auto-IP assignment, RDS deletion protection/retention/IAM auth, missing VPC flow logs and missing Performance Insights. This PR fixes invalid headers, ALB egress, public subnet auto-IP assignment and retention. It does not conceal or globally suppress residual warnings.

Public ALB and web ingress are intentional. HTTP default is only for a non-sensitive lab. App egress remains broad. SNS encryption, VPC flow logs, DB IAM authentication and performance telemetry are not implemented. Enabling encryption correctly for CloudWatch-to-SNS publishing would require deliberate KMS permission design; adding a key merely to silence the scanner is not the scope of this junior audit. Security CI remains advisory and must not be advertised as passing a security gate.

## Change impact to review before any future apply

- A new launch-template version now triggers refresh; changed bootstrap, encryption and monitoring require replacement instances to take effect.
- Existing app master-secret permission is removed by default; enable the explicit demo option only for an intentional learning exercise.
- Backup retention and detailed monitoring may add charges. Enabling backups on an existing instance may have operational impact; plan and schedule deliberately.
- Required AMI input is a deliberate interface change; supply the verified regional image before planning.
- Public subnet auto-IP behavior changes for future instance launches there; existing public ALB/NAT topology is retained.
- No plan was run against state, so exact changes/replacements and costs remain unverified. Review a real plan before applying; do not assume a documentation PR is infrastructure-neutral.

## Validation record

Local and PR validation results are recorded in [VALIDATION.md](VALIDATION.md). All tests in that record are explicitly distinguished from AWS runtime evidence.

## Technical references

- [AWS provider 5.100.0 ASG documentation](https://github.com/hashicorp/terraform-provider-aws/blob/v5.100.0/website/docs/r/autoscaling_group.html.markdown): `$Latest` refresh limitation and numeric version guidance.
- [AWS EC2 CloudWatch metrics and dimensions](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/viewing_metrics_with_cloudwatch.html): detailed monitoring and ASG metric dimension requirements.

## Next evidence to collect with the instructor

Use a separately authorized sandbox deployment: capture reviewed plan and commit SHA; successful apply output; actual subnet/route and SG state; healthy targets and EC2 private-IP/IMDS settings; SSM session success; a restricted-user DB query only after implementing it; HTTPS verification if enabled; SNS confirmation/delivery; timed instance replacement; backup restore; and cleanup checks. Redact account IDs, hostnames and secrets as needed. Do not turn expected outcomes into recorded results.
