# Secret CONTAINER only. No secret version (no actual token value) is ever
# created by Terraform, so the token never enters Terraform state or this
# repository. See docs/deployment.md for how to add the real value with
# `gcloud secrets versions add` outside of Terraform.

resource "google_secret_manager_secret" "api_bearer_token" {
  project   = var.project_id
  secret_id = local.secret_id

  # Single-region replication, matching the regional design of the rest of
  # this stack. This is the simplest option that still lets us pin the
  # secret's storage location to the same region as everything else.
  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }

  labels = local.labels
}
