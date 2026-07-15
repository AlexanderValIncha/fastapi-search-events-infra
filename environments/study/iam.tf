# Runtime service account: the ONLY identity Cloud Run runs as. In Cloud
# Run, this identity is used automatically via Application Default
# Credentials (ADC) -- no JSON key is ever created or downloaded.

resource "google_service_account" "runtime" {
  project      = var.project_id
  account_id   = local.runtime_service_account_id
  display_name = "Hotel Search Ingestion - Cloud Run runtime"
  description  = "Runtime identity for the FastAPI ingestion service. Used only to publish to the events topic and read the Bearer token secret."
}

# --- Pub/Sub: publish only, scoped to the single events topic ------------
# Deliberately NOT roles/pubsub.publisher at the project level.
resource "google_pubsub_topic_iam_member" "runtime_can_publish" {
  project = var.project_id
  topic   = google_pubsub_topic.events.name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${google_service_account.runtime.email}"
}

# --- Secret Manager: read only, scoped to the single Bearer token secret --
resource "google_secret_manager_secret_iam_member" "runtime_can_read_token" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.api_bearer_token.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.runtime.email}"
}

# --- Public invocation ------------------------------------------------------
# The application implements its own Bearer authentication (see app/main.py
# in the fastapi-search-events repository: authenticate_partner dependency).
# Cloud Run's own IAM invoker check is therefore intentionally left open at
# the platform level so that requests reach FastAPI, which then enforces
# auth itself. See docs/decisions.md for the full justification and the
# production alternatives that were deliberately NOT implemented here
# (Cloud Run IAM + OIDC, API Gateway, Load Balancer + Cloud Armor).
resource "google_cloud_run_v2_service_iam_member" "public_invoker" {
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.api.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# --- Pub/Sub service agent: writes to BigQuery Raw table -------------------
# This is a DIFFERENT identity than the Cloud Run runtime service account.
# It is a Google-managed, per-project identity used internally by the
# BigQuery/Cloud Storage export subscriptions.
resource "google_bigquery_dataset_iam_member" "pubsub_agent_can_write_bq" {
  project    = var.project_id
  dataset_id = google_bigquery_dataset.raw.dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = "serviceAccount:${local.pubsub_service_agent_email}"
}

# --- Pub/Sub service agent: writes archive objects to GCS -------------------
resource "google_storage_bucket_iam_member" "pubsub_agent_can_create_objects" {
  bucket = google_storage_bucket.archive.name
  role   = "roles/storage.objectCreator"
  member = "serviceAccount:${local.pubsub_service_agent_email}"
}

resource "google_storage_bucket_iam_member" "pubsub_agent_can_read_bucket" {
  bucket = google_storage_bucket.archive.name
  role   = "roles/storage.legacyBucketReader"
  member = "serviceAccount:${local.pubsub_service_agent_email}"
}
