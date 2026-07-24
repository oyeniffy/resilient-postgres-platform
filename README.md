# Azure Multi-Region High Availability Platform

A production-pattern reference implementation of a stateful workload deployed
across two Azure regions in an active-passive configuration, with automated
failover, geo-replication, and a documented, self-run failure drill.

This is not a toy "deploy two VMs" exercise. The point of this repository is
to demonstrate the actual hard part of multi-region architecture: what
happens to **state** (the database) when a region goes down, how replication
lag affects consistency guarantees, and how the system behaves — not just
how it's configured — under a real, induced failure.

## Status

🚧 In progress. See `docs/adr/` for design decisions as they're made, and the
GitHub Issues / Project board for current build state.

## Architecture at a glance

| | Primary | Secondary |
|---|---|---|
| Region | South Africa North | South Africa West |
| Role | Active — serves all traffic | Passive — warm standby, promoted on failover |
| Database | Azure Database for PostgreSQL Flexible Server | Geo-replica (read-only until promotion) |
| Compute | Azure App Service (Linux) — see ADR-0003 | Mirrored |

Full architecture diagram and reasoning: see `docs/adr/0001-region-and-workload-selection.md`.

## Why these regions

South Africa North and South Africa West are an official Azure paired-region
set. They were chosen over a more common pair (e.g. East US / West US2) for
three reasons: proven Postgres Flexible Server support in both regions,
Microsoft's paired-region SLA benefits (sequenced platform updates,
prioritized recovery), and — pragmatically — the lowest latency available to
the engineer running and testing failover drills, which matters when the
artifact being produced is *measured replication lag and recovery time*, not
just a working deployment.

## Repository structure

```
.
├── docs/
│   └── adr/                 # Architecture Decision Records — the reasoning trail
├── modules/                 # Reusable Terraform modules
│   ├── networking/
│   ├── database/
│   └── compute/
├── environments/
│   ├── primary/              # Root config: South Africa North
│   └── secondary/            # Root config: South Africa West
├── scripts/                  # Bootstrap and operational scripts (state backend, failover drill, teardown)
└── .github/workflows/        # CI/CD — plan on PR, manual-approval apply on merge
```

## Infrastructure as Code

Terraform, with remote state in Azure Storage (locked via blob lease). See
`docs/adr/0002-terraform-and-state-backend.md` for why Terraform over Bicep for
this project, and why Azure Storage over Terraform Cloud for state.

State backend is bootstrapped once, manually, via `scripts/bootstrap-backend.sh`
— it cannot be created by the Terraform configuration that depends on it.

## Local development / running this yourself

Prerequisites and step-by-step setup: see `docs/SETUP.md` (added once the
backend bootstrap step is complete).

## Failure drill

The core artifact of this project isn't the Terraform — it's the documented
proof that failover works. See `docs/FAILOVER-DRILL.md` (added once the
platform is live) for the induced-failure test: what was killed, what broke,
what the recovery time actually was, and what didn't go as planned.

## Related work

This platform is designed to run inside the guardrails established in
[multicloud-zero-trust-landing-zone](https://github.com/oyeniffy/multicloud-zero-trust-landing-zone) —
identity, network segmentation, and policy boundaries are assumed to be
provided by that project, not re-implemented here.
