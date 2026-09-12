# AGENTS.md — assocSSM

Context for AI coding agents (Claude Code, Codex, opencode, Cursor, …) working in this repo.
Read this first; keep it current.

## What this is
Terraform that stands up a small Ansible-managed EC2 fleet and wires it to AWS Systems Manager.
It looks up the shared AFT VPC (never creates one), launches Amazon Linux 2 instances in the
private subnets with an SSM instance profile, and creates an `AWS-RunAnsiblePlaybook` SSM
association that runs `ansible/site.yml` against anything tagged `AnsibleManaged=true` every
30 minutes. The README calls it "ec2ansible".

## Layout
- `main.tf` — VPC/subnet lookups (SSM parameter + subnet tags), security group, IAM role/profile,
  EC2 instance module.
- `ssm.tf` — `aws_ssm_association` targeting tag `AnsibleManaged=true`.
- `iam/trust-policy.json` — assume-role policy, loaded with `file()` (no inline JSON in HCL).
- `ansible/site.yml` — the playbook shipped to targets by the association.
- `backend.tf` — S3 backend. `variables.tf` / `outputs.tf`.
- `.github/workflows/deploy_and_run.yml` (deploy) and `destroy.yml` (teardown).

## Commands
There is **no local Terraform on this host** — do not run `terraform` locally.
- Deploy: push to `master`, or run the "Deploy and Run Ansible" workflow manually.
- Destroy: run the "Destroy Infrastructure" workflow and type `destroy` to confirm.
- Always check the run afterwards: `gh run list -R khoffska/assocSSM`.

## Conventions (house rules — shared across the khoffska AWS repos)
- **Terraform is applied only through GitHub Actions**, never from a laptop. This repo assumes the
  OIDC role `github-actions-oidc-role` via `secrets.AWS_ACCOUNT_ID` — no long-lived keys.
- **Never push straight to `master`/`main`** — feature branch → PR → merge. Note: the deploy
  workflow currently fires `apply` on **push** to `master` with no plan-only PR job yet; add a
  PR plan job if you touch the workflow.
- **No inline JSON in HCL** — keep policies/trust documents in separate `.json` files and load
  them with `file()`/`templatefile()` (this is why `iam/trust-policy.json` exists).
- **The VPC is AFT's** — look it up (`/network/vpc_id` SSM parameter, subnet tags), never recreate
  it. NAT gateways are per-project and should be destroyed when idle.
- **State:** S3 `emr-demo-state-zxcvzxcv23`, key `ec2ansible/terraform.tfstate`, region `us-east-2`,
  `encrypt = true`.
- Never commit secrets; `.env`, `*.tfvars`, and state files are gitignored — keep it that way.

## Gotchas
- The playbook is inlined with `file(...)`, so editing `ansible/site.yml` only takes effect after
  an apply.
- `installDependencies = "True"` is required on the association; without it the run fails because
  Ansible isn't present on the target.
- Don't "fix" the VPC data sources into resources — everything VPC-related here is intentional
  lookup.
- "Destroy Infrastructure" removes the instances and the association; the shared VPC is untouched.
