# Decisions

Mirrors the level of detail in the application repository's own README, but
for infrastructure choices.

## Why Cloud Run allows public invocation (`allUsers` -> `roles/run.invoker`)

The FastAPI application already implements its own Bearer token
authentication (`authenticate_partner` dependency, checked on every call to
`POST /v1/search-events`). If Cloud Run's own IAM invoker check were also
enforced, callers would need **two** layers of Google-specific
authentication (an OIDC identity token *and* the Bearer token), which:

- Duplicates the auth decision in two places with different failure modes.
- Requires the partner to understand and integrate with Google IAM/OIDC,
  which is out of scope for a demo-grade partner integration.

So, for this study exercise, Cloud Run's platform-level invoker check is
opened to `allUsers`, and **all actual authorization is enforced inside
FastAPI**. This means:

- The endpoint is reachable from the public internet.
- Every request without a valid `Authorization: Bearer <token>` header is
  rejected by FastAPI itself with `401`.
- Checkov (or an equivalent static scanner) will very likely flag
  `allUsers` + `roles/run.invoker` as a finding. This is expected and
  accepted here, with this specific justification, not silently
  suppressed.
- **We do not combine Cloud Run IAM auth with the app's Bearer token.**
  Only one auth layer is active by design, to keep the demo explainable in
  a few minutes.

In a production setting, this would be revisited with one of:

- A **private Cloud Run service** (`roles/run.invoker` restricted to
  specific identities) plus OIDC ID tokens, if the partner can federate
  its identity with GCP IAM.
- A properly issued **JWT** from an identity provider.
- **HMAC** with a timestamp and replay protection.
- **API Gateway or Apigee** for quotas, client management, and centralized
  policy.

None of these are implemented here.

## Why instance-based billing for Cloud Run

```text
100 req/s average, 24/7 traffic
259.2 million requests/month (theoretical, see cost-estimation.md)
I/O-bound workload (waiting on Pub/Sub publish confirmation)
```

- Request-based billing charges per-request on top of CPU/memory time,
  which tends to cost more for **steady, continuous** traffic than
  instance-based billing, where you instead pay for allocated instance
  time regardless of exact request count.
- Cloud Run still autoscales the number of *instances* under
  instance-based billing; this setting only changes how each running
  instance is billed and whether CPU is throttled when idle
  (`cpu_idle = false` keeps CPU allocated/billed continuously, which is
  appropriate for a workload with a steady request rate rather than
  bursty, idle-most-of-the-time traffic).
- `cloud_run_min_instances = 1` keeps at least one warm instance, avoiding
  cold starts on the (assumed) steady baseline traffic.
- `cloud_run_max_instances = 20` is an initial, unvalidated cost/capacity
  ceiling, not a number derived from an actual load test.

Expected concurrency, for context (not a measured result):

```text
expected_concurrency = requests_per_second x average_latency_seconds

100 req/s  x 0.1 s = 10 concurrent requests
1000 req/s x 0.1 s = 100 concurrent requests
1000 req/s x 0.5 s = 500 concurrent requests
```

These numbers are theoretical planning inputs, not benchmarked results.
See `docs/cost-estimation.md` for the full cost reasoning and
`../../fastapi-search-events/README.md` (Performance reasoning) for the
application-level traffic assumptions this is based on.

## Why no Pub/Sub schema

- Pydantic v2 already validates structurally and semantically at the
  single producer (the FastAPI service) -- see
  `fastapi-search-events/app/models.py`.
- The BigQuery Raw table preserves the full canonical event as JSON, so no
  information is lost without an enforced Pub/Sub schema.
- Enforcing an Avro/Protobuf schema at the topic level would duplicate
  that contract and would work against the app's `extra="allow"` policy,
  which is deliberately meant to tolerate additive, backward-compatible
  payload evolution.
- If more producers appear in the future (bypassing the FastAPI
  validation layer), revisit adding a topic schema then.

## Why a single shared DLQ topic, not one per subscription

Both export subscriptions (BigQuery, GCS) can fail independently, but a
single DLQ topic keeps the "what needs manual attention" surface in one
place for this small, single-partner study deployment, at the cost of not
being able to tell from the topic alone which subscription a
dead-lettered message originally came from (the message's delivery
attempt count and subscription-specific Cloud Logging entries can still be
used to investigate that manually).

## Why the Raw table stores `data JSON`, not a fully-typed schema

- `event_id` and `partner_id` live inside the JSON payload
  (`JSON_VALUE(data, '$.event_id')`), not as separate typed BigQuery
  columns, so that schema evolution in the canonical event (additive
  fields from `extra="allow"`) never requires a BigQuery schema migration.
- A typed, exploded table (with every Pydantic field as its own BigQuery
  column) is exactly the kind of transformation a future Silver layer
  would own -- implementing it here would duplicate that layer's
  responsibility.

## Why `deletion_protection = false` / no `force_destroy` inconsistency

- BigQuery dataset/table: `delete_contents_on_destroy = false` and table
  `deletion_protection = false` -- explicitly acceptable **only** because
  this is a disposable study environment that may need to be torn down
  and recreated during learning/iteration. Production would use
  `deletion_protection = true` and a deliberate, reviewed process for any
  destroy.
- GCS buckets (state, archive): `force_destroy = false` everywhere, even
  in this study environment, because accidentally destroying either the
  Terraform state history or the archived events is a much more
  disruptive failure mode than a BigQuery table needing to be recreated,
  and the extra friction of manually emptying a bucket before destroy is
  an acceptable safeguard even for a study environment.

## Why the runtime service account is scoped, not project-wide

`roles/pubsub.publisher` and `roles/secretmanager.secretAccessor` are
granted at the **topic** and **secret** level respectively (IAM member
bindings on those specific resources), not at the project level. This
means the Cloud Run runtime identity cannot publish to any other topic in
the project, nor read any other secret, even though both roles would
technically exist at the project level too. This is the minimum privilege
needed for the one thing this service account does.
