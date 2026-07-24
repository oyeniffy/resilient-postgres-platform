# ADR-0003: Compute Platform — Azure App Service
**Status:** Accepted
**Date:** 2026-07-24

## Context
The API needs a compute host in both regions. The candidates considered:
Azure App Service, Azure Container Apps, and Virtual Machine Scale Sets.

## Decision
Azure App Service, Linux plan, one instance per region.

## Reasoning
- This project's evidence is database failover behavior — replication
  lag, promotion time, connection recovery after a region failure — not
  compute platform sophistication. Container orchestration is explicitly
  covered by a separate project (AKS/Container Apps platform engineering,
  #2 in the broader portfolio plan), so demonstrating it here would
  dilute focus rather than add signal.
- App Service removes an entire failure-mode category (container build,
  registry auth, image pull failures) that would otherwise compete for
  attention with the actual subject of this project during the failure
  drill — if something breaks during the drill, it should be the
  database/replication story, not a container registry hiccup.
- App Service's built-in health check endpoint integrates directly with
  Azure Front Door / Traffic Manager for regional failover routing,
  which is exactly the mechanism this project needs, with no additional
  infrastructure to build.

## Alternatives considered
- **Container Apps**: rejected for this project specifically — not
  because it's a worse platform, but because it answers a question
  (container portability, Dapr, KEDA scaling) that isn't this project's
  question. Revisit if this workload is later extended into the AKS
  platform-engineering project.
- **VM Scale Set**: rejected — highest operational overhead (patching,
  scaling policy, load balancer config) for no benefit relevant to the
  database-failover story being demonstrated.

## Consequences
- The `modules/compute` Terraform module targets `azurerm_linux_web_app`
  (or app service equivalent), not container-based resources.
- Health check configuration on the App Service is a dependency for the
  Front Door/Traffic Manager failover logic — must be built and verified
  before the failover drill can be meaningfully tested.
