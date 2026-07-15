locals {
  name_prefix = "${var.application_name}-${var.environment}"

  # Artifact Registry repository id (letters, numbers, hyphens only).
  artifact_registry_repository_id = "hotel-search-api"

  # Terraform remote state bucket name. Bucket names are globally unique in
  # GCS, so we derive it from the project id.
  state_bucket_name = "${var.project_id}-tfstate-${var.application_name}"

  labels = var.labels
}
