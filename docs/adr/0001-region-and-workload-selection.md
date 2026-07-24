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
