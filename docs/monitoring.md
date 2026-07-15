# Monitoring

No alerting suite or dashboard is implemented as Terraform in this
repository, beyond what's noted below, because none of it could be
verified against a real project as part of this exercise (see root README
"Restrictions": no real GCP resources were created).

## Recommended metrics to watch in production

### Cloud Run

- Request count (by response code class: 2xx/4xx/5xx).
- `401` count (auth failures -- expected baseline noise, but spikes may
  indicate a partner misconfiguration or a credential leak/rotation
  issue).
- `429` count (if any client-side or platform-level throttling is added
  later).
- `5xx` count (unexpected errors, per the app's own error semantics: a
  `500` should never leak internal details, but should still be alerted
  on).
- p95/p99 request latency.
- Instance count (min/max/current) -- compare against
  `cloud_run_max_instances` to see how close to the configured ceiling
  traffic gets.
- CPU and memory utilization per instance.

### Pub/Sub

- Oldest unacked message age, per subscription (`bigquery_export`,
  `gcs_export`) -- a growing value indicates the export sink is falling
  behind.
- Backlog (num_undelivered_messages), per subscription.
- Dead-letter topic message count -- should be ~0 in steady state; any
  sustained growth means messages are failing delivery repeatedly and
  need manual investigation.

### BigQuery

- Time since the latest `publish_time` value landed in
  `hotel_search_raw.pubsub_search_events` -- a simple, effective "is data
  still flowing" freshness check.

### Cloud Storage

- Time since the latest object was created in the archive bucket -- same
  freshness idea as above, for the GCS export path.

### Cost

- A budget alert on the project (or a label-scoped budget, if the project
  is shared with other workloads), since `cloud_run_min_instances = 1`
  with `cpu_idle = false` bills continuously even at zero traffic, and
  traffic assumptions here are theoretical (see `cost-estimation.md`).

## Why not implement Terraform alerting policies here

Implementing `google_monitoring_alert_policy` resources requires either:

- Real notification channels (email/Slack/PagerDuty integrations), which
  would need real, non-placeholder configuration to be meaningful, or
- Leaving notification channels empty/fake, which risks giving a false
  impression that alerting is "done" when it would silently never notify
  anyone.

Both outcomes are worse than clearly documenting the intended metrics and
thresholds here, to be wired up deliberately once this moves beyond a
study exercise into a real, owned environment with a real on-call
destination.
