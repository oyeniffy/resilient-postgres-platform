# Resilient Postgres Platform

A production-pattern reference implementation of a stateful workload deployed
across two Azure regions in an active-passive configuration, with automated
failover, geo-replication, and a documented, self-run failure drill.

This is not a toy "deploy two VMs" exercise. The point of this repository is
to demonstrate the actual hard part of multi-region architecture: what
happens to **state** (the database) when a region goes down, how replication
lag affects consistency guarantees, and how the system behaves — not just
how it's configured — under a real, induced failure.

## Status

Core platform — networking, cross-region VNet peering, database
replication, and compute — is built and verified against live Azure
infrastructure. Traffic routing (Front Door) and CI/CD are implemented
and code-complete, pending a scheduled deployment window.

Deployment is currently paused as a deliberate cost-governance decision:
this project runs against a capped personal Azure budget rather than an
unlimited account, and the cap was intentionally reached rather than
exceeded. Redeployment resumes late August 2026, at which point the
failure drill (`docs/FAILOVER-DRILL.md`) will be executed and its results
recorded.

**Built and verified:**
- Networking — VNets, delegated subnets, NSGs, both regions
- Bidirectional cross-region VNet peering
- Postgres Flexible Server, primary + cross-region read replica, actively
  replicating, Entra ID-only authentication
- Confirmed at the database level: the replica enforces read-only access,
  not merely receiving replicated data
- App Service, both regions, VNet-integrated, health checks passing,
  managed identity granted database access

**Implemented, deployment pending:**
- Front Door — priority-based origin failover (`modules/frontdoor`,
  `environments/global`)
- GitHub Actions CI/CD — plan-on-PR, manual-approval-apply-on-merge,
  OIDC federated authentication (`docs/CI-SETUP.md`)
- Teardown automation (`scripts/teardown.sh`)
- The failure drill itself — procedure and results template ready in
  `docs/FAILOVER-DRILL.md`

See the GitHub Issues/Project board for granular status per component.

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

## Cost governance

This project runs against a capped personal Azure budget, not an
unlimited account — a deliberate constraint, not an incidental one. That
constraint shaped real architectural and operational decisions throughout:
compute tier selection, session-scoped resource lifecycles, and the
decision to pause deployment once the cap was reached rather than request
an increase mid-build. Operating under a fixed budget is itself a
condition worth designing for, not an edge case to work around.

## Related work

This platform is designed to run inside the guardrails established in
[multicloud-zero-trust-landing-zone](https://github.com/oyeniffy/multicloud-zero-trust-landing-zone) —
identity, network segmentation, and policy boundaries are assumed to be
provided by that project, not re-implemented here.
