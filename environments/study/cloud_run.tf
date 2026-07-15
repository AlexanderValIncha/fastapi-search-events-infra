# Cloud Run service running the FastAPI ingestion API.
#
# Image is consumed by IMMUTABLE DIGEST (var.container_image), never built
# here. See docs/deployment.md for the promotion process from the
# application repository.

resource "google_cloud_run_v2_service" "api" {
  project  = var.project_id
  name     = local.cloud_run_service_name
  location = var.region

  # Requests must reach FastAPI's own Bearer auth check; see iam.tf
  # (public_invoker) and docs/decisions.md for the justification.
  ingress = "INGRESS_TRAFFIC_ALL"

  labels = local.labels

  template {
    service_account                  = google_service_account.runtime.email
    max_instance_request_concurrency = var.cloud_run_concurrency
    timeout                          = "5s"

    scaling {
      min_instance_count = var.cloud_run_min_instances
      max_instance_count = var.cloud_run_max_instances
    }

    containers {
      image = var.container_image

      ports {
        container_port = 8000
      }

      resources {
        limits = {
          cpu    = tostring(var.cloud_run_cpu)
          memory = var.cloud_run_memory
        }
        # Instance-based billing: CPU stays allocated (and billed) even when
        # not actively handling a request. See docs/decisions.md for the
        # cost/traffic-pattern justification (steady ~100 req/s, 24/7).
        cpu_idle = false
      }

      env {
        name  = "PARTNER_ID"
        value = var.partner_id
      }
      env {
        name  = "PUBLISHER_BACKEND"
        value = "pubsub"
      }
      env {
        name  = "GCP_PROJECT_ID"
        value = var.project_id
      }
      env {
        name  = "PUBSUB_TOPIC_ID"
        value = google_pubsub_topic.events.name
      }
      env {
        name  = "SUPPORTED_SCHEMA_VERSION"
        value = "1.0"
      }
      env {
        name = "API_BEARER_TOKEN"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.api_bearer_token.secret_id
            version = "latest"
          }
        }
      }
    }
  }

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }

  depends_on = [
    google_pubsub_topic_iam_member.runtime_can_publish,
    google_secret_manager_secret_iam_member.runtime_can_read_token,
  ]
}
