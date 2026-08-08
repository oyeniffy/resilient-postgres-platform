# ADR-0001: Region Pair and Workload Selection

**Status:** Accepted
**Date:** 2026-07-24

## Context

This project's purpose is to demonstrate multi-region high availability for
a *stateful* workload — the hard part of HA is what happens to data during
failover, not just routing traffic to a healthy endpoint. Two decisions had
to be made before any infrastructure could be designed: what the workload
is, and which two regions it runs in.

## Decision: Workload

A small task/notes REST API backed by Azure Database for PostgreSQL
Flexible Server.

**Alternatives considered:**
- *Static site across two regions* — rejected. No state means no failover
  problem to actually solve; would demonstrate DNS/traffic routing only.
- *Full microservices application* — rejected as the first iteration. Adds
  application-layer complexity (service-to-service auth, multiple
  datastores) that would dilute focus away from the infrastructure problem
  being demonstrated. May be revisited as a v2.

The API needs to be complex enough to have real data at risk during
failover (concurrent writes, a client that notices stale reads), and simple
enough that debugging effort stays on infrastructure, not application code.

## Decision: Region Pair

**South Africa North** (primary, active) and **South Africa West**
(secondary, passive).

**Alternatives considered:**
- *East US / West US 2* — the default choice in most tutorials and
  reference architectures. Rejected: highest latency from the operator's
  actual location, which matters when the deliverable includes measured
  replication lag and recovery time — noise from a long round-trip
  obscures the numbers that make the failure drill meaningful. Also a
  less distinctive choice for a portfolio artifact.
- *North Europe / West Europe* — reasonable latency, but not an official
  Azure paired-region set at time of writing; loses the sequenced-update
  and prioritized-recovery guarantees that are part of the "why regional
  pairs matter" story.

**Why South Africa North / West specifically:**
1. Official Azure paired regions (Microsoft-defined pair, not an arbitrary
   choice) — inherits platform-level update sequencing and recovery
   prioritization.
2. Both regions support Azure Database for PostgreSQL Flexible Server with
   the features this project depends on (zone-redundant HA, geo-replicas).
3. Lowest latency available to the operator, which directly improves the
   quality of the failover drill's evidence.

**Known risk, accepted deliberately:** South Africa West has historically
had tighter capacity/quota constraints than higher-traffic regions. If
provisioning hits a quota wall, the response will be to document the
region-access-request process rather than silently switching regions —
that's a real operational scenario worth capturing, not a failure to hide.

## Consequences

- Any regional service used later in this project (compute, networking,
  monitoring) must be verified for availability in South Africa West before
  being adopted — this region has narrower service coverage than
  higher-tier regions.
- Failover drill timings will reflect real intra-Africa network conditions,
  not a best-case US backbone.

## Amendment — 2026-07-30

During deployment, `terraform apply` for the secondary environment failed:

```
LocationNotAvailableForResourceGroup: The provided location
'southafricawest' is not available for resource group.
```

This subscription is governed by an organization-level Azure Policy
restricting deployments to an explicit allow-list of regions.
`southafricawest` is not on that list; `southafricanorth` is — which is
why the primary region deployed without issue and the mismatch only
surfaced when applying secondary.

**Decision: secondary region changed to West Europe (`westeurope`).**

This was not the original plan and is recorded here rather than quietly
edited in, because encountering and adapting to a real subscription-level
constraint is itself relevant evidence — this is what "the design met
reality" actually looks like in a governed environment, not a hypothetical
to reason about in the abstract.

**Reasoning for West Europe specifically, from the allowed list:**
- Full, mature service parity with South Africa North for everything this
  project needs (Postgres Flexible Server with HA and geo-replication
  features, App Service, Front Door)
- UAE North was considered for closer geographic proximity, but was not
  chosen — West Europe's service maturity and documentation depth reduce
  the risk of hitting a second region-specific surprise mid-build, which
  matters more here than shaving some milliseconds off replication lag
- No longer an official Azure-paired-region relationship with South Africa
  North (that benefit, described in the original decision above, is lost)
  — accepted as a reasonable tradeoff against the alternative of fighting
  the subscription's allow-list policy to get South Africa West approved

**Consequence:** replication lag and failover timing numbers from the
eventual failure drill will reflect South Africa North ↔ West Europe
network conditions, not the original South Africa North ↔ West pairing.
This is noted here so the eventual `FAILOVER-DRILL.md` numbers aren't
read against the wrong baseline assumption.

## Amendment 2 — 2026-08-06: West Europe cross-region replica creation fails consistently; pivoted to North Europe

Cross-region replica creation to West Europe failed **four times**,
identically, with a generic `InternalServerError` from Azure's API — even
after ruling out three other hypotheses in sequence (an explicit `zone`
argument on the replica; unsupported region pairing, ruled out via
Microsoft Learn docs confirming any-region replication is supported; and
missing `geo_redundant_backup_enabled` on the primary, which was a real
fix worth keeping but did not resolve this specific failure).

**Diagnostic step that isolated the cause:** created a same-region replica
directly via Azure CLI (bypassing Terraform entirely) from the same
primary server. It succeeded immediately (`"state": "Ready"`, under a
minute). This confirms the primary server, its configuration, and the
Terraform provider are not the problem — the failure is specific to
**cross-region replication targeting West Europe**, from this
subscription, at this time.

**Decision:** secondary region changed again, from West Europe to
**North Europe**. Reasoning: North Europe is a similarly mature,
high-traffic region with full Postgres Flexible Server support, but is
infrastructurally distinct enough from West Europe to serve as a genuine
test of whether the issue is West-Europe-specific or a broader
cross-region pattern for this subscription.

**Why this is recorded rather than silently swapped again:** four
identical failures against one target region, followed by an instant
same-region success, is a meaningfully different situation from the
earlier South-Africa-West policy block (which had a clear, immediate,
correctly-worded error). This failure mode — consistent, generic,
platform-side — was not fully resolvable through client-side diagnosis
alone. The Azure Activity Log was checked and contained no further detail
beyond the top-level message; a Basic support ticket was considered as
the next step if North Europe also fails.

