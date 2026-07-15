output "artifact_registry_repository" {
  description = "Full Artifact Registry repository path for the FastAPI image."
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.hotel_search_api.repository_id}"
}

output "state_bucket_name" {
  description = "Name of the GCS bucket holding Terraform remote state for the 'study' workload stack."
  value       = google_storage_bucket.tf_state.name
}

output "enabled_apis" {
  description = "APIs enabled by this bootstrap stack."
  value       = local.required_apis
}
