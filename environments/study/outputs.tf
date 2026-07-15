output "artifact_registry_repository" {
  description = "Docker repository path (created by bootstrap) expected to hold the deployed image."
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/hotel-search-api"
}

output "cloud_run_service_name" {
  description = "Name of the deployed Cloud Run service."
  value       = google_cloud_run_v2_service.api.name
}

output "cloud_run_service_url" {
  description = "Public HTTPS URL of the Cloud Run service."
  value       = google_cloud_run_v2_service.api.uri
}

output "pubsub_topic_name" {
  description = "Name of the main Pub/Sub events topic."
  value       = google_pubsub_topic.events.name
}

output "pubsub_dlq_topic_name" {
  description = "Name of the dead-letter Pub/Sub topic."
  value       = google_pubsub_topic.dlq.name
}

output "bigquery_dataset_id" {
  description = "BigQuery Raw dataset id."
  value       = google_bigquery_dataset.raw.dataset_id
}

output "bigquery_table_id" {
  description = "BigQuery Raw table id."
  value       = google_bigquery_table.raw_events.table_id
}

output "archive_bucket_name" {
  description = "GCS bucket used for the Cloud Storage export archive."
  value       = google_storage_bucket.archive.name
}

output "secret_name" {
  description = "Secret Manager secret id holding the API bearer token (container only; no version is managed by Terraform)."
  value       = google_secret_manager_secret.api_bearer_token.secret_id
}

output "runtime_service_account_email" {
  description = "Email of the Cloud Run runtime service account."
  value       = google_service_account.runtime.email
}
