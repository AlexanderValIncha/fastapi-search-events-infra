# Dataform minimal viable models (example)

This folder contains a minimal SQLX example for a RAW -> Silver -> Gold design.
It is intentionally not wired to Terraform resources yet; it serves as a
reference implementation for model shape and semantics.

Business semantic model:

- Metric counted is searches (one canonical search event = one unit).
- Grain of the Silver fact is one canonical search event.
- Primary key at semantic level: partner_id + event_id.
- Do not UNNEST payload.search_results into the Silver fact, because that
  would multiply the search metric.

Suggested datasets:

- hotel_search_raw (already implemented in Terraform)
- hotel_search_silver
- hotel_search_gold

Included SQLX models:

- silver_fact_search_event.sqlx
- silver_dim_city.sqlx
- silver_dim_hotel.sqlx
- gold_arrival_daily.sqlx
- gold_country_daily.sqlx
- gold_stay_length_daily.sqlx
- assert_unique_event_key.sqlx
- assert_required_fact_fields.sqlx
- assert_country_code_format.sqlx
- assert_gold_arrival_reconciliation.sqlx

Hardening choices in this example:

- `search_date` is derived from payload event timestamp, with fallback to
  Pub/Sub `publish_time`.
- Missing city is imputed as `UNKNOWN_CITY` to avoid dropping otherwise
  valid events before trend aggregation.
