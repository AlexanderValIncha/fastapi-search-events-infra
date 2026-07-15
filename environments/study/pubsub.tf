# --- Dead-letter topic -------------------------------------------------------
# Messages that repeatedly fail delivery to either export subscription can be
# dead-lettered here for manual inspection. Kept intentionally minimal: a
# single shared DLQ topic plus one pull subscription to inspect it.

resource "google_pubsub_topic" "dlq" {
  project = var.project_id
  name    = local.pubsub_dlq_topic_id
  labels  = local.labels

  message_retention_duration = "604800s" # 7 days
}

# Pull subscription purely for manual inspection of dead-lettered messages.
# No push endpoint, no export sink: this is intentionally a passive holding
# area, not a processing pipeline.
resource "google_pubsub_subscription" "dlq_inspection" {
  project = var.project_id
  name    = "${local.pubsub_dlq_topic_id}-inspection"
  topic   = google_pubsub_topic.dlq.name
  labels  = local.labels

  message_retention_duration = "604800s" # 7 days
  retain_acked_messages      = false

  expiration_policy {
    ttl = "" # never expires the subscription itself
  }
}

# --- Main events topic -------------------------------------------------------

resource "google_pubsub_topic" "events" {
  project = var.project_id
  name    = local.pubsub_topic_id
  labels  = local.labels

  # Keep unacked/undelivered messages around for a reasonable window in case
  # a subscription falls behind (e.g. BigQuery export hiccups).
  message_retention_duration = "604800s" # 7 days

  # No Pub/Sub schema in this version: Pydantic already validates at the
  # single producer (the FastAPI app), the BigQuery Raw table preserves the
  # full canonical JSON, and a schema here would duplicate that contract.
  # `extra="allow"` in the Pydantic model is meant to allow additive,
  # backward-compatible evolution; enforcing an Avro/Protobuf schema at the
  # topic would work against that. Revisit if/when more producers appear.
}

# --- BigQuery export subscription --------------------------------------------
#
# NOTE (integration validation required): the exact runtime behavior of a
# managed BigQuery subscription (write_metadata, use_topic_schema,
# use_table_schema, drop_unknown_fields interplay) can only be fully
# confirmed by applying this against a real project. The block below is
# syntactically valid against the current `google` provider schema, but
# should be exercised in a sandbox project before being relied upon.
resource "google_pubsub_subscription" "bigquery_export" {
  project = var.project_id
  name    = "${local.pubsub_topic_id}-bigquery-export"
  topic   = google_pubsub_topic.events.name
  labels  = local.labels

  message_retention_duration = "604800s" # 7 days
  retain_acked_messages      = false

  expiration_policy {
    ttl = "" # never expires
  }

  dead_letter_policy {
    dead_letter_topic     = google_pubsub_topic.dlq.id
    max_delivery_attempts = 5
  }

  bigquery_config {
    table               = "${var.project_id}.${google_bigquery_dataset.raw.dataset_id}.${google_bigquery_table.raw_events.table_id}"
    write_metadata      = true
    use_topic_schema    = false
    use_table_schema    = false
    drop_unknown_fields = false
  }

  depends_on = [
    google_bigquery_dataset_iam_member.pubsub_agent_can_write_bq,
  ]
}

# --- Cloud Storage export subscription ---------------------------------------
#
# NOTE (integration validation required): the exact tokens accepted by
# `filename_datetime_format` and the resulting object key layout should be
# confirmed against a sandbox project; the folder hierarchy documented in
# docs/architecture.md is the intended target, derived from the provider's
# documented date/time tokens, not yet verified end-to-end.
resource "google_pubsub_subscription" "gcs_export" {
  project = var.project_id
  name    = "${local.pubsub_topic_id}-gcs-export"
  topic   = google_pubsub_topic.events.name
  labels  = local.labels

  message_retention_duration = "604800s" # 7 days
  retain_acked_messages      = false

  expiration_policy {
    ttl = "" # never expires
  }

  dead_letter_policy {
    dead_letter_topic     = google_pubsub_topic.dlq.id
    max_delivery_attempts = 5
  }

  cloud_storage_config {
    bucket          = google_storage_bucket.archive.name
    filename_prefix = "partner=${var.partner_id}/"
    filename_suffix = ".jsonl"

    filename_datetime_format = "ingestion_date=YYYY-MM-DD/hour=hh/'"

    max_duration = "300s"    # 5 minutes
    max_bytes    = 104857600 # 100 MiB

    # No avro_config block: omitting it means messages are written as plain
    # text (one message per line), which combined with .jsonl filenames
    # gives us the intended JSONL archive format. There is no max_messages
    # attribute on this block (batching is controlled by max_duration /
    # max_bytes only) -- confirmed by `terraform validate` against the
    # provider schema while building this repository.
  }

  depends_on = [
    google_storage_bucket_iam_member.pubsub_agent_can_create_objects,
    google_storage_bucket_iam_member.pubsub_agent_can_read_bucket,
  ]
}

# --- Dead-letter permissions --------------------------------------------------
# The Pub/Sub service agent needs explicit publish/subscribe permissions on
# the DLQ topic/subscription to be able to dead-letter messages from the two
# export subscriptions above.
resource "google_pubsub_topic_iam_member" "service_agent_can_publish_dlq" {
  project = var.project_id
  topic   = google_pubsub_topic.dlq.name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${local.pubsub_service_agent_email}"
}

resource "google_pubsub_subscription_iam_member" "service_agent_can_ack_source_subs" {
  for_each = {
    bigquery = google_pubsub_subscription.bigquery_export.name
    gcs      = google_pubsub_subscription.gcs_export.name
  }

  project      = var.project_id
  subscription = each.value
  role         = "roles/pubsub.subscriber"
  member       = "serviceAccount:${local.pubsub_service_agent_email}"
}
