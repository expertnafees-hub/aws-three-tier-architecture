# Validation record

## Baseline main

Commit `1c68c55f5c4308cdd2837ebde8528c28355f28e4` passed Terraform fmt/init/validate in [GitHub Actions run 35141561165](https://github.com/expertnafees-hub/aws-three-tier-architecture/actions/runs/35141561165). Its advisory security scan found 15 potential problems. These results apply to that commit only.

## Audit branch

Local checks passed on 2026-09-16:

- `bash -n scripts/chaos_test.sh`.
- `bash -n` on the extracted launch-template user-data script; no bootstrap commands executed.
- All relative Markdown file links resolve.
- Local loopback HTTP probe tests: HTTP 200 with `us-west-2b` instance metadata parsing, HTTP 503, and connection refusal normalized to `000`; summary emitted on SIGTERM. These test the probe, not AWS.
- `git diff --check`.

Branch code commit `274c0327fd7196234281470c902059ab7106c623` passed [PR CI run 35144411538](https://github.com/expertnafees-hub/aws-three-tier-architecture/actions/runs/35144411538): Terraform format, backend-disabled init, shell syntax and Terraform validate all succeeded. The following documentation commit records these results without changing the Terraform or shell implementation.

The [advisory scanner job](https://github.com/expertnafees-hub/aws-three-tier-architecture/actions/runs/35144411538/job/104956696136) reported **30 passed, 10 potential problems, zero ignored**: 4 critical, 2 high, 3 medium, 1 low. Findings decreased from 15 to 10 without adding scanner suppressions. Remaining findings: default HTTP; public web ingress (two rules); broad app egress; public ALB; SNS encryption absent; RDS deletion protection off; RDS IAM authentication off; VPC flow logs absent; Performance Insights absent. Review their context in [AUDIT.md](AUDIT.md); a successful advisory job is not a security all-clear.

The local environment has no Terraform binary, and the attempted official binary download timed out. Terraform success above is verified from the new PR CI, not inferred from main. `terraform validate` does not exercise AWS API availability or prove both optional deployment modes can be applied.

No AWS plan, apply, runtime, database, DNS/TLS, notification, recovery or restore test was executed by this audit.
