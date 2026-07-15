# Raw ingestion dataset/table. Preserves the FULL canonical event JSON
# (event_id, partner_id, schema_version, ingested_at, payload) exactly as
# published, plus Pub/Sub delivery metadata. No typed, fully-exploded table
# is created here on purpose: that belongs to a future Silver layer.

resource "google_bigquery_dataset" "raw" {
  project     = var.project_id
  dataset_id  = local.bigquery_dataset_id
  location    = var.region
  description = "Raw landing zone for hotel search events delivered via the Pub/Sub BigQuery export subscription. One row per Pub/Sub message; canonical event preserved as JSON."

  labels = local.labels

  # deletion_protection = false ONLY because this is a disposable study
  # environment. A production dataset would use stricter protection
  # (deletion_protection = true) plus explicit lifecycle/retention policy
  # review before any destroy.
  delete_contents_on_destroy = false
}

resource "google_bigquery_table" "raw_events" {
  project             = var.project_id
  dataset_id          = google_bigquery_dataset.raw.dataset_id
  table_id            = local.bigquery_table_id
  description         = "One row per Pub/Sub message delivered by the BigQuery export subscription. 'data' holds the full canonical event JSON; 'attributes' holds Pub/Sub message attributes, if any."
  deletion_protection = false

  labels = local.labels

  time_partitioning {
    type  = "DAY"
    field = "publish_time"
  }

  # No clustering initially: table is small/simple enough that clustering
  # would add complexity without a demonstrated query-pattern benefit yet.

  schema = jsonencode([
    {
      name        = "subscription_name"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "Full resource name of the Pub/Sub subscription that delivered this message."
    },
    {
      name        = "message_id"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "Pub/Sub-assigned message ID. Distinct from the application-level event_id inside 'data'."
    },
    {
      name        = "publish_time"
      type        = "TIMESTAMP"
      mode        = "NULLABLE"
      description = "Time Pub/Sub received the message. Partitioning column."
    },
    {
      name        = "data"
      type        = "JSON"
      mode        = "NULLABLE"
      description = "Full canonical event JSON as published by the FastAPI service: event_id, partner_id, schema_version, ingested_at, payload."
    },
    {
      name        = "attributes"
      type        = "JSON"
      mode        = "NULLABLE"
      description = "Pub/Sub message attributes, if any were set (currently none are set by the publisher)."
    },
  ])
}
