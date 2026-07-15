data "google_project" "current" {
  project_id = var.project_id
}

locals {
  name_prefix = "${var.application_name}-${var.environment}"

  # Resource ids (letters, numbers, hyphens; GCP naming constraints).
  runtime_service_account_id = "hotel-search-ingestion"
  pubsub_topic_id            = "hotel-search-events"
  pubsub_dlq_topic_id        = "hotel-search-events-dlq"
  bigquery_dataset_id        = "hotel_search_raw"
  bigquery_table_id          = "pubsub_search_events"
  secret_id                  = "hotel-search-api-bearer-token"
  archive_bucket_name        = "${var.project_id}-hotel-search-events-archive"
  cloud_run_service_name     = "${local.name_prefix}-api"

  # The Pub/Sub service agent is a Google-managed identity, one per project,
  # used by Pub/Sub itself when writing to BigQuery/GCS export destinations.
  # It is NOT the same identity as the Cloud Run runtime service account.
  pubsub_service_agent_email = "service-${data.google_project.current.number}@gcp-sa-pubsub.iam.gserviceaccount.com"

  labels = var.labels
}
