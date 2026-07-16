# Deployment

## Contract between the two repositories

```text
fastapi-search-events (application repo)
  -> unit tests (pytest)
  -> docker build
  -> push to Artifact Registry (created by this infra repo's bootstrap stack)
  -> produces an immutable image digest

fastapi-search-events-infra (this repo)
  -> updates var.container_image to the new digest
  -> terraform plan
  -> terraform apply
  -> new Cloud Run revision
```

**Terraform is the single source of truth for what image is deployed.**
The application repository's own CI never touches Cloud Run directly, and
this repository never builds or pushes images. Exactly one pipeline
(Terraform apply, in this repo) is allowed to change what's running in
Cloud Run.

## Recommended promotion process (manual, for this study exercise)

1. The `fastapi-search-events` repository builds and pushes a new image to
   the Artifact Registry repository created by `bootstrap`.
2. That push produces an immutable digest
   (`...@sha256:<64 hex chars>`).
3. A human updates `container_image` in
   `environments/study/terraform.tfvars` (or the `_VAR_FILE` used by the
   `plan`/`apply` Cloud Build configs) via a pull request in **this**
   repository.
4. The PR triggers `cloudbuild/plan.yaml`, producing a reviewable plan.
5. On merge to `main`, `cloudbuild/apply.yaml` re-plans from the merged
   commit and applies exactly that plan, deploying a new Cloud Run
   revision.

### Optional manual sandbox gate

For stronger confidence before merge/apply, run
`cloudbuild/sandbox-gate.yaml` manually against a sandbox project. This
pipeline performs a real `terraform init/validate/plan` with sandbox
backend/vars files and never applies resources.

The intended order becomes:

1. PR `plan.yaml` (static + plan checks).
2. Manual `sandbox-gate.yaml` (real plan against sandbox).
3. Merge to `main` -> `apply.yaml`.

This repository does **not** automate step 3 (no cross-repository PR
creation) and does **not** create the actual Cloud Build triggers, since
this repository is not connected to any remote/CI system as part of this
exercise (see root README "Restrictions").

## Checkov behavior in `cloudbuild/plan.yaml`

`plan.yaml` now runs Checkov in enforced mode by default
(`_CHECKOV_SOFT_FAIL="false"`).

If a team needs temporary exploratory runs while triaging findings, the
trigger can set `_CHECKOV_SOFT_FAIL="true"` to keep reporting findings
without failing the build.

## Bootstrap sequence (first-time setup)

1. Apply `bootstrap/` (APIs, Artifact Registry repository, Terraform
   remote state bucket). Uses local state (see `bootstrap/README.md` for
   why).
2. Push the first application image to the Artifact Registry repository
   created in step 1; note its digest.
3. Add the real Bearer token value to the Secret Manager secret created by
   `environments/study` -- **outside Terraform**:

   ```bash
   printf '%s' "$API_BEARER_TOKEN" |
     gcloud secrets versions add hotel-search-api-bearer-token \
     --data-file=-
   ```

   Never commit `$API_BEARER_TOKEN`'s value anywhere. `printf '%s'` (no
   trailing newline) avoids accidentally storing an extra newline
   character as part of the secret.

4. Set `container_image` in `environments/study/terraform.tfvars` to the
   digest from step 2.
5. Apply `environments/study/` (Pub/Sub, BigQuery, GCS, Secret Manager
   container, runtime service account, Cloud Run).

None of these steps were executed against a real GCP project as part of
building this repository.

## Local, non-destructive validation performed while building this repo

```bash
terraform fmt -check -recursive
terraform init -backend=false
terraform validate
```

Run independently in both `bootstrap/` and `environments/study/`. See the
root README for the actual recorded results.

`terraform validate` only checks configuration syntax and internal
consistency (types, references, required arguments). It does **not**
verify:

- That the configured APIs are actually enabled in a real project.
- That the acting identity has the IAM permissions to create these
  resources.
- The exact runtime behavior of managed Pub/Sub export subscriptions
  (flagged explicitly in `environments/study/pubsub.tf`).

A `terraform plan` against a real project (with real credentials) is
required to validate those aspects, and was intentionally not run as part
of this exercise.

## Template hygiene before committing

When preparing a PR, keep repository examples anonymized and safe-by-default:

- Commit only `*.example` templates with placeholder values.
- Never commit real secret values, local absolute paths, or filled-in backend/tfvars files.
- Keep machine-specific values only in local gitignored files (`backend.hcl`, `terraform.tfvars`).

Quick check (PowerShell, from repo root):

```powershell
$files = git ls-files
Select-String -Path $files -Pattern 'C:\\Users\\|/home/|BEGIN (RSA|OPENSSH|EC) PRIVATE KEY|ghp_[A-Za-z0-9]{20,}|AIza[0-9A-Za-z\-_]{35}' -CaseSensitive:$false
```

The command should return no matches for tracked repository content.

## Extension plan for RAW -> Silver -> Gold (Dataform)

If this repository is extended for analytics serving, the recommended
provision/apply strategy is:

1. Keep Terraform ownership for infrastructure only:
   BigQuery datasets (`raw`, `silver`, `gold`), Dataform repository,
   Dataform release/workflow configs, service accounts, IAM bindings,
   scheduler/trigger resources.
2. Keep SQL transformation logic in Dataform code (`definitions/*.sqlx`)
   versioned with Git and reviewed via PR.
3. Preserve remote state separation by concern:
   `bootstrap` state and `environments/study` state remain isolated.
4. Use the same CI gating style already used here:
   `fmt/init/validate/tflint/checkov/plan` on PR, `apply` only on merge.
5. Add Dataform checks to CI:
   compile/test assertions on PR, run workflow only after merge.

Suggested module boundaries if the stack grows:

- `modules/ingestion` (Cloud Run + Pub/Sub + DLQ)
- `modules/raw_storage` (BigQuery Raw + GCS archive)
- `modules/analytics_dataform` (Dataform + Silver/Gold datasets + IAM)

For this study repository size, the current flat layout is still valid;
module extraction is recommended only when multiple environments/teams
start reusing the same patterns.
