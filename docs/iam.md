# IAM

## Identities implemented in this repository

| Identity | Created by | Responsibility | Key permissions |
| --- | --- | --- | --- |
| `hotel-search-ingestion@PROJECT_ID.iam.gserviceaccount.com` (runtime SA) | `environments/study/iam.tf` | Cloud Run runtime identity for the FastAPI service | `roles/pubsub.publisher` on the `hotel-search-events` topic only; `roles/secretmanager.secretAccessor` on the `hotel-search-api-bearer-token` secret only |
| Pub/Sub service agent (`service-PROJECT_NUMBER@gcp-sa-pubsub.iam.gserviceaccount.com`) | Google-managed, referenced (not created) in `environments/study/iam.tf` and `pubsub.tf` | Used internally by the BigQuery and Cloud Storage export subscriptions | `roles/bigquery.dataEditor` on the `hotel_search_raw` dataset only; `roles/storage.objectCreator` + `roles/storage.legacyBucketReader` on the archive bucket only; `roles/pubsub.publisher`/`subscriber` on the DLQ topic/subscriptions |

These two identities are **not the same**: the runtime service account
never has BigQuery or GCS permissions, and the Pub/Sub service agent never
has permission to invoke Cloud Run or read the Bearer token secret.

No identity in this repository is granted `Owner`, `Editor`, `Viewer`,
`BigQuery Data Editor` at the project level, or `Storage Object Admin`.

## Identities documented but NOT provisioned by this repository

Provisioning a full CI identity model (separate builder/planner/deployer
service accounts, their own IAM bindings, Workload Identity Federation,
etc.) would introduce a bootstrap circularity: those service accounts
would themselves need to be created by *something*, and granting that
"something" enough IAM permission to create service accounts and IAM
bindings starts to resemble a broad, project-admin-like role -- which
conflicts with the "no roles granted just for convenience" principle this
repository otherwise follows. For a small, single-partner study exercise,
that tradeoff is not worth making. These identities are documented here as
the expected shape for when this graduates beyond a study exercise:

| Identity | Responsibility |
| --- | --- |
| API builder SA | Build the FastAPI Docker image and push it to Artifact Registry (`fastapi-search-events` repo's own CI) |
| Terraform planner SA | Read-only: `terraform plan` in this repo's `plan` Cloud Build pipeline |
| Terraform deployer SA | Write: `terraform apply` in this repo's `apply` Cloud Build pipeline, after merge to `main` |
| Cloud Run runtime SA | **Implemented** -- see table above |
| Pub/Sub service agent | **Implemented** (Google-managed, referenced) -- see table above |

If/when this project needs real CI automation, the recommended minimum
scopes would be:

- API builder SA: `roles/artifactregistry.writer` on the single repository.
- Terraform planner SA: `roles/viewer`-equivalent, scoped as tightly as
  Terraform's own `plan` requires (in practice this tends to need broad
  read access across the services being planned; consider a custom role
  if this matters for your organization).
- Terraform deployer SA: permissions matching exactly the resource types
  this stack manages (Cloud Run admin, Pub/Sub admin, BigQuery admin
  scoped to the dataset, Storage admin scoped to the bucket, Secret
  Manager admin scoped to the secret, Service Account admin scoped to the
  single runtime SA) -- not a blanket `Editor`/`Owner` role.
