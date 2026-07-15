# Docker repository that will hold the FastAPI application image built and
# pushed by the *application* repository's own CI. Terraform never builds or
# pushes images here; it only provisions the destination repository.

resource "google_artifact_registry_repository" "hotel_search_api" {
  project       = var.project_id
  location      = var.region
  repository_id = local.artifact_registry_repository_id
  description   = "Docker images for the hotel-search-ingestion FastAPI study service."
  format        = "DOCKER"

  labels = local.labels

  depends_on = [google_project_service.required]
}
