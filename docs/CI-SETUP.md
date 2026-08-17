# CI/CD Setup — OIDC Federated Credentials

The GitHub Actions workflows in this repo authenticate to Azure using
OIDC federated credentials, not stored secrets/passwords. This means
GitHub proves its identity to Azure AD at runtime via a short-lived
token, and no long-lived Azure credential is ever stored in GitHub
Secrets — only non-secret identifiers (client ID, tenant ID,
subscription ID).

This is a one-time setup, done once per subscription.

## 1. Create an app registration

```bash
az ad app create --display-name "github-actions-resilient-postgres-platform"
```

Note the `appId` from the output — this is your `AZURE_CLIENT_ID`.

## 2. Create a service principal for the app

```bash
az ad sp create --id <appId-from-step-1>
```

## 3. Grant the service principal Contributor on the subscription

```bash
az role assignment create \
  --assignee <appId-from-step-1> \
  --role Contributor \
  --scope /subscriptions/<subscription-id>
```

## 4. Create the federated credential, scoped to this repo's main branch

```bash
az ad app federated-credential create \
  --id <appId-from-step-1> \
  --parameters '{
    "name": "github-main-branch",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:oyeniffy/resilient-postgres-platform:ref:refs/heads/main",
    "audiences": ["api://AzureADTokenExchange"]
  }'
```

Also add a second federated credential for pull requests, so the plan
workflow can authenticate too:

```bash
az ad app federated-credential create \
  --id <appId-from-step-1> \
  --parameters '{
    "name": "github-pull-requests",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:oyeniffy/resilient-postgres-platform:pull_request",
    "audiences": ["api://AzureADTokenExchange"]
  }'
```

## 5. Add GitHub Secrets

In the repo: **Settings → Secrets and variables → Actions → New repository secret**

| Secret name | Value |
|---|---|
| `AZURE_CLIENT_ID` | `appId` from step 1 |
| `AZURE_TENANT_ID` | your Entra tenant ID |
| `AZURE_SUBSCRIPTION_ID` | the new subscription's ID |
| `ENTRA_ADMIN_OBJECT_ID` | your Entra object ID (used for Postgres admin assignment) |
| `ENTRA_ADMIN_PRINCIPAL_NAME` | your UPN (e.g. `you@yourorg.com`) |

## 6. Create the `production` GitHub Environment with a manual approval rule

**Settings → Environments → New environment** → name it `production` →
under **Deployment protection rules**, check **Required reviewers** and
add yourself.

This is what makes `terraform-apply.yml` pause for manual approval before
actually running — merges to `main` trigger the workflow, but nothing
touches real infrastructure until a human clicks Approve.

## Why this setup, not simpler alternatives

- **OIDC over stored secrets**: no Azure credential exists anywhere
  outside Azure AD itself — nothing to rotate, nothing to leak from a
  compromised GitHub Secret.
- **Manual approval gate over auto-apply on merge**: real infrastructure
  changes should never be one accidental merge away from happening. A
  human confirms intent before anything runs, matching how a real
  production change-control process works.
