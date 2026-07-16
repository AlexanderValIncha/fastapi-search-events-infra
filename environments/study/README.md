# environments/study

Single-environment Terraform workload stack that deploys the
`fastapi-search-events` application and its supporting data-plane
infrastructure: Pub/Sub topic (+ DLQ), BigQuery Raw dataset/table, GCS
archive bucket, Secret Manager container, a dedicated runtime service
account, and the Cloud Run service itself.

Requires the `bootstrap` stack to have been applied first (Artifact
Registry repository + Terraform remote state bucket + enabled APIs).

## Prerequisites

1. `bootstrap` applied (see `../../bootstrap/README.md`).
2. A container image already pushed to the Artifact Registry repository
   created by `bootstrap`, referenced **by digest**.
3. The `hotel-search-api-bearer-token` secret's actual value added
   **outside Terraform** (see `docs/deployment.md` at the repo root).

## Usage (local, non-destructive validation only)

```bash
cd environments/study
terraform fmt -check -recursive
terraform init -backend=false
terraform validate
```

## Usage (real deployment, requires GCP credentials + bootstrap already applied)

```bash
cp backend.hcl.example backend.hcl
# edit backend.hcl with the real state bucket name from bootstrap outputs
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars with real project_id, container_image (by digest)

terraform init -backend-config=backend.hcl
terraform plan
terraform apply
```

Safety rules for local copies:

- Keep real values only in local `backend.hcl` / `terraform.tfvars` (both gitignored).
- Do not commit absolute machine paths (`C:\Users\...`, `/home/...`, etc.) in docs or config.
- Keep `*.example` files placeholder-only and provider-neutral.

Applying this stack for real was **not** performed while building this
repository.

## What this stack intentionally does NOT do

- Build or push the container image (that's the application repository's
  CI, see `docs/deployment.md`).
- Manage the secret's actual value (see `secret_manager.tf` and
  `docs/deployment.md`).
- Implement production-grade authentication beyond the application's own
  Bearer token check (see root `docs/decisions.md`).
