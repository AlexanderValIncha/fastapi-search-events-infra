# Archive bucket: batched JSONL files written by the Cloud Storage export
# subscription. Not a per-event object -- see pubsub.tf cloud_storage_config
# for the batching thresholds (max_duration/max_bytes/max_messages).

resource "google_storage_bucket" "archive" {
  project  = var.project_id
  name     = local.archive_bucket_name
  location = var.region

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  requester_pays              = false

  # Never allow `terraform destroy` to silently wipe archived events.
  force_destroy = false

  labels = local.labels

  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      type          = "SetStorageClass"
      storage_class = "NEARLINE"
    }
  }

  lifecycle_rule {
    condition {
      age = 90
    }
    action {
      type          = "SetStorageClass"
      storage_class = "COLDLINE"
    }
  }

  lifecycle_rule {
    condition {
      age = var.archive_retention_days
    }
    action {
      type = "Delete"
    }
  }
}
