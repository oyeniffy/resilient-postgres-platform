# ADR-0004: Database Design — Compute Tier, HA, Authentication, Replica Architecture

**Status:** Accepted
**Date:** 2026-07-30

## Context

The database is the actual subject of this project's evidence: replication
lag, promotion behavior, and data survival during a regional failure. Several
decisions had real cost and complexity implications that needed to be made
deliberately rather than defaulted into.

## Decision: Compute tier — General Purpose (`GP_Standard_D4ds_v5`)

Cross-region read replicas — the core mechanism this project demonstrates —
are **not supported on the Burstable tier** in Azure Database for PostgreSQL
Flexible Server; General Purpose or Memory Optimized is required. This
wasn't a preference, it was a hard platform constraint discovered during
research before writing the module (verified against Microsoft Learn
documentation, since this materially affects both design and cost).

`D4ds_v5` (4 vCore) was chosen over the minimum `D2ds_v5` (2 vCore) for a
more realistic demo — closer to what a production reviewer would expect to
see performance numbers from, rather than the smallest possible instance.

## Decision: Zone-redundant HA — enabled

In addition to cross-region replication (the project's core subject), a
same-region zone-redundant standby is enabled on the primary. This adds a
second, orthogonal HA mechanism to the demo: zone failure is handled
locally (automatic, synchronous, sub-minute), while regional failure is
handled via the cross-region replica (manual promotion, asynchronous,
longer RTO). Documenting both mechanisms and their different recovery
characteristics is part of what this ADR set is meant to demonstrate.

**Cost consequence, made explicit:** zone-redundant HA bills a full second
compute instance identical to the primary. Combined with the cross-region
replica (a third full instance), running this continuously costs
approximately **$0.68/hour** (compute only, D4ds_v5 pricing) — roughly
$495/month if left running. This is not sustainable against this project's
$130 working budget. **Operational discipline required:** the database
tier is stopped or destroyed between every work session; it is deployed
fresh, evidence is captured, then torn down — never left running
unattended. This constraint is treated as a real operational lesson, not
an inconvenience to hide from the writeup.

## Decision: Authentication — Microsoft Entra ID only (no password auth)

`password_auth_enabled = false`, `active_directory_auth_enabled = true`.

**Reasoning:**
- No admin password to generate, store, rotate, or accidentally commit —
  removes an entire category of secret-management risk from the project
  rather than managing it "carefully."
- Entra ID auth is the pattern a governed enterprise environment expects;
  demonstrating it (app registration / signed-in-user assignment as
  database admin) is a stronger signal than password auth for a Principal
  Architect portfolio piece.
- Tradeoff accepted: more setup steps before the first successful
  connection test (a manual Azure CLI step to capture the signed-in user's
  object ID and UPN is required before `terraform apply`, since Terraform
  has no way to discover "who is currently authenticated as a human" on
  its own beyond the service principal/user running it).

## Decision: Replica creation — cross-state reference via `terraform_remote_state`

Primary and secondary environments have **separate Terraform state files**
(by design, per ADR-0002 — separate state keys prevent one environment's
apply from affecting the other). But creating a read replica requires the
replica's configuration to reference the primary server's resource ID.

**Decision:** the secondary environment reads the primary environment's
state as a **data source** (`terraform_remote_state`, read-only) to obtain
`postgres_server_id`, rather than merging the two environments into a
single state file.

**Reasoning:** keeping separate state per environment remains correct even
with this cross-reference — the secondary environment can *read* primary's
outputs without being able to *modify* primary's resources, which preserves
the blast-radius isolation that was the whole point of separate state
files in the first place. The alternative (one combined state for both
regions) would make every `plan`/`apply` touch both regions' resources
simultaneously — a worse failure mode for a project whose entire premise
is regional isolation.

**Consequence:** the secondary environment cannot be applied successfully
until the primary environment's database has been applied and its state
pushed to the remote backend — an explicit ordering dependency, documented
here rather than discovered as a confusing error.

## Consequences

- `terraform apply` order is no longer arbitrary: primary's database module
  must be applied before secondary's.
- Total per-session cost while both regions are up: ~$0.68/hr — sessions
  should be time-boxed and resources torn down or stopped immediately
  after evidence is captured.
- No admin password exists anywhere in this project — access is entirely
  via Entra ID identity, which also means losing access to the Azure
  account in use would require an Entra-level fix, not a password reset.

## Amendment — 2026-08-06: geo-redundant backup is a real prerequisite for cross-region replicas

Creating the secondary replica failed three times in a row with an
identical, generic error:

```
Status: "InternalServerError"
Message: "An unexpected error occured while processing the request."
```

Each failure occurred at the same point (~3 minutes into server creation),
with `source_server_id` correctly pointing at the real primary server —
ruling out the cross-state reference (ADR-0004's main design point) as the
cause. Two other hypotheses were tested and ruled out first: an explicit
`zone` argument on the replica (removed — replicas don't accept a caller-
specified zone) and an unsupported region pairing (ruled out — Microsoft
Learn confirms replicas are supported in any region combination, not just
paired regions).

**Root cause, found via a Microsoft-authored reference architecture repo
rather than the prescriptive API docs:** cross-region read replicas
require the *primary* server to have been created with
`geo_redundant_backup_enabled = true`. This isn't stated as a hard
requirement in Azure's plain-language documentation — it was inferred from
observing that every working reference example paired zone-redundant HA
and geo-redundant backup together on the primary before provisioning
replicas, combined with the primary in this project having been created
with the default `geo_redundant_backup_enabled = false`.

**Consequence:** `geo_redundant_backup_enabled` can only be set at server
creation time (Azure does not allow changing it afterward), so fixing this
requires destroying and recreating the primary server — acceptable here
since no real application data existed on it yet at the time this was
discovered.

**Why this is worth recording rather than quietly fixing:** this is a
genuine example of an undocumented dependency between two features
(HA and geo-replication) that Azure's API surfaces as an unhelpful generic
500 error instead of a clear validation message. Diagnosing it required
ruling out simpler explanations first (config error, region support,
platform incident) via evidence — not guessing — before reaching the
actual cause via a working example rather than the missing documentation.
This is the kind of debugging trail a portfolio reviewer should be able to
follow, not something to sand smooth after the fact.
