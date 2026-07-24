# ADR-0002: Terraform as IaC Tool, Azure Storage as State Backend

**Status:** Accepted
**Date:** 2026-07-24

## Context

A companion repository (`multicloud-zero-trust-landing-zone`) already uses
a mix of Bicep and Terraform (HCL). This project needed its own explicit
decision rather than defaulting to whichever tool was used last.

## Decision: Terraform over Bicep

**Reasoning:**
- Bicep is Azure-only by design. Terraform's provider model demonstrates
  the ability to architect across clouds, which is closer to what a
  Principal Solutions Architect role implies than deep single-cloud DSL
  fluency alone.
- Terraform's state model (as opposed to Bicep/ARM's stateless,
  what-you-see-is-deployed model) forces explicit handling of drift,
  locking, and remote state — operational concerns that are themselves
  worth demonstrating competence in, not concerns to avoid.
- Module composition in Terraform (`modules/networking`,
  `modules/database`, `modules/compute`, consumed per-environment) is a
  visible, reviewable artifact of how the system is decomposed —
  relevant evidence for an architecture-focused portfolio.
- Using Terraform here, alongside the existing Bicep + Terraform mix in the
  landing zone repo, demonstrates range rather than single-tool comfort.

**Tradeoff accepted:** Terraform requires a manually bootstrapped state
backend (a chicken-and-egg problem Bicep doesn't have, since ARM/Bicep
deployments have no separate state store). This adds a real setup step,
treated here as something to document properly rather than a complexity to
hide.

## Decision: State Backend — Azure Storage, not Terraform Cloud

**Reasoning:**
- This is a single-operator project; Terraform Cloud's collaboration
  features (team state access, Sentinel policy gating, remote run UI)
  aren't exercised meaningfully by one person.
- Azure Storage + blob lease locking is the standard, resume-legible
  pattern for Azure-hosted Terraform state and requires no third-party
  account or trust boundary beyond Azure itself.
- It keeps the state backend inside the same cloud and (eventually) the
  same governance boundary as the landing zone project, which is a more
  coherent story than introducing an external SaaS dependency for state
  alone.

**Consequence:** The state storage account, container, and resource group
must be created *before* any Terraform in this repo runs, via a one-time
bootstrap script (`scripts/bootstrap-backend.sh`) run manually with the
Azure CLI — not via Terraform itself. This is documented explicitly so the
bootstrapping isn't mistaken for an oversight in the "should be IaC'd"
sense; it's a known, necessary exception.
