# bootstrap

One-time, low-churn stack that creates the resources the `environments/study`
workload stack depends on, but which cannot depend on the workload stack
itself:

- Enables required Google Cloud APIs (shared, `disable_on_destroy = false`).
- Creates the Artifact Registry Docker repository for the FastAPI image.
- Creates the GCS bucket used as Terraform remote state backend for
  `environments/study`.

## Why a separate stack?

This is the classic Terraform "bootstrap" problem:

1. The GCS bucket that will hold remote state for `environments/study`
   **does not exist yet** the first time you run Terraform.
2. You cannot configure `environments/study` to use a GCS backend that
   doesn't exist.
3. So: this `bootstrap` stack runs first, using **local state** (a
   `terraform.tfstate` file on your machine, gitignored), and creates the
   bucket.
4. Once the bucket exists, `environments/study` is configured from the
   start to use it as a remote backend (see
   `environments/study/backend.tf` and `backend.hcl.example`).
5. Optionally, once you're comfortable, you can migrate this bootstrap
   stack's own state into the very bucket it created
   (`terraform init -migrate-state` with a backend block added
   afterwards). This is **not required** for the study workload to work
   and is not automated here, to avoid destructive `terraform state`
   operations being scripted.

No `null_resource`, no `local-exec`, no destructive migration scripting is
used to work around this — it is handled by simply running two `terraform
init` steps at different points in time, as documented above.

## Usage (local, non-destructive validation only)

```bash
cd bootstrap
terraform fmt -check -recursive
terraform init -backend=false
terraform validate
```

Applying this stack for real requires:

```bash
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars with a real project_id
terraform init
terraform plan
terraform apply
```

This was **not** run as part of building this repository (no real GCP
project was used, no resources were created).
