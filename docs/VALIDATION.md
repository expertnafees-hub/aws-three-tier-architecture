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

PR Terraform validation is pending. The local environment has no Terraform binary, and the attempted official binary download timed out. Terraform checks will be verified through the PR's GitHub Actions run, not inferred from the baseline run.

No AWS plan, apply, runtime, database, DNS/TLS, notification, recovery or restore test was executed by this audit.
