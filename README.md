# Resilient Postgres Platform

A production-pattern reference implementation of a stateful workload deployed
across two Azure regions in an active-passive configuration, with automated
failover, geo-replication, and a documented, self-run failure drill.

This is not a toy "deploy two VMs" exercise. The point of this repository is
to demonstrate the actual hard part of multi-region architecture: what
happens to **state** (the database) when a region goes down, how replication
lag affects consistency guarantees, and how the system behaves — not just
how it's configured — under a real, induced failure.

## Status — as of 2026-08-10

🟡 **Paused, not stalled.** All infrastructure code is written, reviewed,
and (with the exception of Front Door and CI/CD) has been proven against
real Azure resources in a prior session. The subscription used for that
session hit its spending limit and was automatically disabled by Azure
(`ReadOnlyDisabledSubscription`) — a hard, protective cap, not a runaway
bill. A new subscription is expected around **August 28, 2026**. Until
then, this repo is in a scaffold-complete, apply-pending state.

**What's been built and verified against real Azure infrastructure:**
- ✅ Networking — VNets, delegated subnets, NSGs, both regions
- ✅ Bidirectional cross-region VNet peering (see ADR-0005 for the real
  six-attempt debugging history behind this)
- ✅ Postgres Flexible Server, primary + cross-region read replica,
  actively replicating, Entra ID-only authentication
- ✅ Confirmed: replica genuinely enforces read-only at the database level
  (not just receiving replicated data — verified by attempting a GRANT
  against it and getting a real Postgres error)
- ✅ App Service, both regions, VNet-integrated, health checks passing,
  managed identity granted database access (primary)

**What's fully coded but not yet applied/tested (pending new subscription):**
- ⏳ Front Door — priority-based origin failover (`modules/frontdoor`,
  `environments/global`)
- ⏳ GitHub Actions CI/CD — plan-on-PR, manual-approval-apply-on-merge,
  OIDC federated auth (`docs/CI-SETUP.md` has the one-time setup steps)
- ⏳ Teardown script (`scripts/teardown.sh`) — written, not yet exercised
  against a full live stack

**What can't happen until then:**
- The actual failure drill (`docs/FAILOVER-DRILL.md` has the full
  procedure and results template, ready to execute)
- First full end-to-end deploy verification

See the GitHub Issues/Project board for granular status per component.

## Architecture at a glance

| | Primary | Secondary |
|---|---|---|
| Region | South Africa North | North Europe (see region history below) |
| Role | Active — serves all traffic | Passive — warm standby, promoted on failover |
| Database | Azure Database for PostgreSQL Flexible Server (General Purpose, zone-redundant HA) | Geo-replica (read-only until promotion) |
| Compute | Azure App Service (Linux, VNet-integrated) | Mirrored |
| Traffic | Azure Front Door — priority-based failover | — |

### Region history — a real thing worth knowing before reading the code

Secondary's region changed **twice** during this build, for two different,
legitimate reasons — not indecision:

1. **South Africa West → West Europe**: the original plan (South Africa
   North + South Africa West, an official Azure paired-region set) hit a
   subscription-level Azure Policy blocking South Africa West entirely.
2. **West Europe → North Europe**: cross-region replica creation to West
   Europe failed four times with a generic `InternalServerError`. A
   diagnostic same-region test misleadingly suggested primary was healthy.
   North Europe was tried next, and a fifth failure finally surfaced the
   real, specific error: primary and secondary VNets were never peered,
   so there was no network path between them at all. This had been the
   root cause the entire time, across all three regions. See
   `docs/adr/0005-vnet-peering-root-cause.md` for the full trail.

## Repository structure

```
.
├── docs/
│   ├── adr/                  # Architecture Decision Records — the reasoning trail
│   ├── CI-SETUP.md           # One-time OIDC federated credential setup
│   └── FAILOVER-DRILL.md     # The failure drill procedure + results (pending execution)
├── modules/                  # Reusable Terraform modules
│   ├── networking/
│   ├── database/
│   ├── compute/
│   └── frontdoor/
├── environments/
│   ├── primary/               # South Africa North
│   ├── secondary/             # North Europe
│   └── global/                # Front Door — spans both regions, its own state file
├── app/                       # Minimal placeholder Node.js app (infra validation, not the real API yet)
├── scripts/                   # Bootstrap and operational scripts
└── .github/workflows/         # CI/CD — plan on PR, manual-approval apply on merge
```

## Infrastructure as Code

Terraform, with remote state in Azure Storage (locked via blob lease).
Three separate state files — `primary.tfstate`, `secondary.tfstate`,
`global.tfstate` — so no single `apply` can affect more than one
environment's blast radius. See `docs/adr/0002-terraform-and-state-backend.md`
for why Terraform over Bicep, and why Azure Storage over Terraform Cloud.

State backend is bootstrapped once, manually, via `scripts/bootstrap-backend.sh`
— it cannot be created by the Terraform configuration that depends on it.
**Note:** the state backend from the disabled subscription cannot be
reused — a fresh bootstrap will be needed under the new subscription.

## Database design

Postgres Flexible Server, General Purpose tier (required for cross-region
read replicas — Burstable doesn't support them), zone-redundant HA on
primary, Entra ID-only authentication (no admin password exists anywhere
in this project). Full reasoning and cost tradeoffs in
`docs/adr/0004-database-design.md`.

## Failure drill

The core artifact of this project isn't the Terraform — it's the
documented proof that failover works. Full procedure and results
template: `docs/FAILOVER-DRILL.md`. Not yet executed — pending
infrastructure redeployment.

## Cost discipline

This project runs on a personal Azure allocation with a hard spending
cap, not an unlimited company account. That constraint shaped real
decisions throughout — compute tier choices, session-scoped resource
lifecycles, and ultimately, this project hitting its cap mid-build and
pausing rather than continuing to accrue cost. That's treated here as a
real operational finding worth documenting, not something to omit.

## Related work

This platform is designed to run inside the guardrails established in
[multicloud-zero-trust-landing-zone](https://github.com/oyeniffy/multicloud-zero-trust-landing-zone) —
identity, network segmentation, and policy boundaries are assumed to be
provided by that project, not re-implemented here.
