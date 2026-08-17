# Failure Drill Runbook

**Status:** Not yet executed — pending new Azure subscription (see
`docs/adr/` for the subscription spending-limit history). This document
is the pre-written procedure; results get filled in under "Results" once
the drill is actually run.

## Purpose

This is the actual flagship evidence of the project: proof, not just
configuration, that the system survives a regional failure. Everything
built so far — networking, peering, replication, compute, Front Door —
exists to make this drill possible and to make its outcome meaningful.

## Pre-drill checklist

- [ ] Both regions fully deployed (`terraform apply` clean in primary,
      secondary, and global)
- [ ] Front Door endpoint confirmed serving traffic, routed to primary
      (verify via `curl <front-door-url>/health` — should return
      `"region":"primary"`)
- [ ] Replication confirmed healthy (Portal → primary Postgres server →
      Replication tab)
- [ ] A monitoring terminal open, polling the Front Door endpoint
      continuously during the drill:
      ```bash
      while true; do
        date; curl -s <front-door-url>/health; echo; sleep 2
      done
      ```
- [ ] Screenshot/log capture ready — this drill's evidence is the point

## Procedure

### Step 1: Establish baseline

Record, before touching anything:
- Current Front Door → primary routing confirmed via repeated `/health`
  calls (region: primary)
- Current replication lag on the Postgres replica (Portal → Replication
  tab → lag metric)
- Timestamp: baseline established at `__________`

### Step 2: Induce primary failure

Stop primary's App Service (simulates a regional compute outage without
needing to actually take down the whole region, which isn't available as
a controllable action):

```bash
az webapp stop --resource-group rg-haplatform-primary --name app-haplatform-primary
```

Record the exact timestamp this command was run: `__________`

### Step 3: Observe and time the failover

Watch the polling terminal from the pre-drill checklist. Record:
- Timestamp of the last successful response from **primary**:
  `__________`
- Timestamp of the first successful response from **secondary**:
  `__________`
- **Failover time (RTO)** = difference between the two: `__________`
- What did clients see during the gap — errors, timeouts, nothing?
  `__________`

### Step 4: Promote the secondary database (if testing full data-layer failover)

At this point, secondary's App Service still can't write to its own
database (it's a read replica — see the read-only enforcement finding
from the database setup session). To make the failover *functionally*
complete, not just traffic-complete, the replica needs promotion:

```bash
az postgres flexible-server replica promote \
  --resource-group rg-haplatform-secondary \
  --name psql-haplatform-secondary \
  --promote-mode standalone \
  --promote-option planned
```

Record:
- Timestamp promotion was initiated: `__________`
- Timestamp promotion completed (server no longer shows as a replica):
  `__________`
- **Promotion time**: `__________`
- Any data loss window (RPO) — check replication lag recorded in Step 1
  as the upper bound on data at risk: `__________`

### Step 5: Grant secondary's App Service database access

Now that secondary is standalone (no longer read-only), run the same
grant sequence used for primary (see `docs/adr/0004-database-design.md`
session notes) against `psql-haplatform-secondary`.

### Step 6: Confirm full recovery

- `curl <front-door-url>/health` returns `"region":"secondary"`
- A write against secondary's database succeeds (proves it's genuinely
  writable now, not just reachable)

### Step 7: Restore primary (optional — documents recovery, not just failure)

```bash
az webapp start --resource-group rg-haplatform-primary --name app-haplatform-primary
```

Note: at this point primary is **not** automatically the source of
replication again — secondary is now standalone/primary. Restoring the
original topology (making the old primary a replica of the new one, or
manually re-establishing the original direction) is a separate exercise,
deliberately out of scope for this drill. Worth noting explicitly in the
writeup: **failover is demonstrated; failback is not** — a real and
common limitation worth being upfront about rather than implying more
was tested than actually was.

## Results

*(Fill in after the drill is actually executed)*

| Metric | Value |
|---|---|
| Baseline replication lag | |
| Front Door failover time (RTO) | |
| Client-visible impact during failover | |
| Replica promotion time | |
| Data loss window (RPO) | |
| Anything that didn't go as expected | |

## What "didn't go as expected" is for

This section is deliberately not optional. The most valuable part of a
failure drill writeup is what surprised you — not a clean narrative where
everything worked exactly as designed. If the drill goes perfectly with
zero surprises, that itself is worth noting and being a little skeptical
of, given this project's actual history (the six-attempt VNet peering
debugging arc, the subscription limit, the OneDrive sync issue) — this is
not a project where "everything just worked" has been the norm, and
that's a more honest and more useful thing to document than pretending
otherwise.
