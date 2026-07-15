# Cost estimation

This is a **transparent, parametrized estimate**, not a measured result.
No load test has been run (see the application repository's own
"Performance reasoning" section, which this builds on).

## Traffic assumptions (from the application repository's README)

```text
Average:  100 requests/second
Peak:     1,000 requests/second (assumed, not observed)
Average payload size: ~1 KiB
```

```text
100 req/s x 1 KiB           ~= 0.1 MiB/s
                              ~= 8.64 million events/day
                              ~= 259.2 million events/month
                              ~= 247 GiB of payload/month
```

## Cost drivers in this architecture

| Component | Pricing driver | Notes |
| --- | --- | --- |
| Cloud Run | Instance-time (CPU + memory), instance-based billing, `min_instances=1` kept warm continuously | Dominant, predictable cost driver for steady 24/7 traffic; `cpu_idle=false` means CPU is billed even between requests on warm instances |
| Pub/Sub | Per-message throughput (publish + delivery), roughly proportional to the ~247 GiB/month figure above, doubled (once per export subscription: BigQuery + GCS) | Pub/Sub pricing is throughput-based (GiB), not strictly per-request, but scales with message volume |
| BigQuery | Storage (Raw table, partitioned by day) + any query costs incurred later by a Silver layer (not part of this repo) | Storage cost only from this repo's perspective; query cost depends on future consumers |
| GCS archive | Storage (Standard -> Nearline -> Coldline lifecycle) + operation costs (writes from the export subscription) | Lifecycle rules (30/90/365 days) are designed to reduce storage cost as data ages, at the cost of retrieval latency/cost if old data needs to be read back |
| Secret Manager | Negligible (single secret, low access rate) | Not a meaningful cost driver here |
| Artifact Registry | Storage of container image layers | Negligible relative to the above |

## What would be needed for a real cost number

- Actual Cloud Run instance count over time (depends on real concurrency,
  not the theoretical `expected_concurrency` formula in `decisions.md`).
- Actual Pub/Sub message volume (the 259.2M events/month figure is a
  theoretical ceiling based on the assumed average rate, not an observed
  number).
- Actual BigQuery storage growth rate and any downstream query patterns.
- Real GCS lifecycle transition savings, which depend on how often (if
  ever) Coldline-tier archived data needs to be retrieved.
- Current GCP list prices for the target region (`europe-west1`), which
  this document deliberately does not hardcode, since prices change over
  time and a stale number here would be actively misleading.

No specific monthly dollar figure is provided in this document, since any
such figure would imply a precision this exercise cannot support. Use the
GCP Pricing Calculator with the volumes above, and current list prices,
before making any real budgeting decision.
