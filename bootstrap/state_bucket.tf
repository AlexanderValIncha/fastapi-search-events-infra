# Dedicated bucket for Terraform remote state of the "study" workload stack.
#
# This bucket is intentionally NOT used by the bootstrap stack itself (see
# versions.tf and README.md for the bootstrap chicken-and-egg explanation).

resource "google_storage_bucket" "tf_state" {
  project  = var.project_id
  name     = local.state_bucket_name
  location = var.region

  uniform_bucket_level_access = true

  public_access_prevention = "enforced"

  versioning {
    enabled = true
  }

  # Never allow `terraform destroy` to silently delete state history.
  force_destroy = false

  # Keep a bounded number of noncurrent (overwritten) state versions instead
  # of retaining them forever, without adding a complex multi-rule lifecycle.
  lifecycle_rule {
    condition {
      num_newer_versions = 10
    }
    action {
      type = "Delete"
    }
  }

  labels = local.labels

  depends_on = [google_project_service.required]
}
