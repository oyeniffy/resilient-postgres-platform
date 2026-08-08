# ADR-0005: Root Cause of Replica Creation Failures — Missing VNet Peering

**Status:** Accepted
**Date:** 2026-08-08

## Context

Cross-region read replica creation failed **five times** across this
project's debugging history — four times against West Europe, once
against North Europe — before a specific, actionable Azure error finally
surfaced instead of a generic one:

```
Status: "ReadReplicaToSourceServerNetworkBlocked"
Message: "The TCP connection from 'psql-haplatform-secondary' server to
'psql-haplatform-primary' server failed. If both servers are in different
virtual networks make sure both virtual networks peered..."
```

## Root cause

Both database servers were correctly configured with
`public_network_access_enabled = false` and full VNet integration
(delegated subnet + private DNS zone), per the original database design
(ADR-0004) — meaning each server is reachable **only** over private
networking. But primary's VNet and secondary's VNet were never peered to
each other. There was no network path between them at all.

This was the actual cause of every prior replica failure, not region
choice or platform flakiness. Azure's API returned an unhelpful generic
`InternalServerError` in four of the five attempts and only surfaced the
specific, correct error on this final attempt — the same underlying
problem was almost certainly present the entire time, across all three
regions tried (South Africa West, West Europe, North Europe).

**A misleading diagnostic, in hindsight:** an earlier same-region CLI test
(creating a replica in the same region/resource group as primary) had
succeeded instantly, which was read at the time as evidence the primary
server and its configuration were healthy — ruling out a chain of other
hypotheses. In hindsight, that test never actually exercised cross-VNet
connectivity, since a same-region replica sits inside the source's own
VNet by default. Its success was consistent with the peering hypothesis,
not evidence against it. Worth remembering for future debugging: a
passing test only rules out what it actually exercises, not everything
adjacent to it.

## Decision

Add bidirectional global VNet peering between primary's and secondary's
VNets — one `azurerm_virtual_network_peering` resource in each
environment, each referencing the other's VNet ID via
`terraform_remote_state`. Azure supports global (cross-region) peering
natively; no VPN gateway or ExpressRoute circuit is required.

## Bootstrapping consequence

Both new peering resources depend on a `vnet_id` output that the *other*
environment does not yet publish (since this output didn't exist before
this change). This isn't a true Terraform circular dependency — primary
and secondary are separate applies — but it does mean the first rollout
of this change requires a specific apply order rather than a simple
"apply both":

1. Apply secondary with `-target` limited to its resource group and
   networking module, so its state publishes `vnet_id` without yet
   attempting the peering resource (which needs primary's `vnet_id`,
   not yet published either).
2. Apply primary fully — secondary's `vnet_id` is now available, so
   primary's peering resource and its own `vnet_id` output both succeed.
3. Apply secondary fully — primary's `vnet_id` is now available, so
   secondary's peering resource succeeds, and (the actual goal) the
   Postgres replica creation can finally be attempted with a real network
   path to its source server.

This ordering is a one-time cost for introducing peering, not an ongoing
constraint on future applies.

## Related, non-causal fix kept in place

An earlier fix enabling `geo_redundant_backup_enabled = true` on the
primary (ADR-0004 amendment) remains in the configuration as a reasonable
best practice, but is now understood not to have been the actual cause of
the failures observed at the time — the primary was recreated with that
setting in the same debugging session as continued West Europe failures,
which in hindsight should have been a stronger signal that the hypothesis
was wrong sooner than it was abandoned. Recorded here as an honest
correction.
