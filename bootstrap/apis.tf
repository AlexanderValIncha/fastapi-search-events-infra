# Enables the Google Cloud APIs required by both the bootstrap stack and the
# "study" workload stack. Enabling them here (once, centrally) avoids races
# where the workload stack tries to use an API before it is active.
#
# disable_on_destroy = false: destroying this Terraform stack must never
# disable APIs project-wide, since other resources/humans may depend on them
# being enabled.

locals {
  required_apis = [
    "run.googleapis.com",
    "artifactregistry.googleapis.com",
    "pubsub.googleapis.com",
    "bigquery.googleapis.com",
    "storage.googleapis.com",
    "secretmanager.googleapis.com",
    "iam.googleapis.com",
    "cloudbuild.googleapis.com",
    "monitoring.googleapis.com",
  ]
}

resource "google_project_service" "required" {
  for_each = toset(local.required_apis)

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}
