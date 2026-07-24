#!/usr/bin/env bash
#
# bootstrap-backend.sh
#
# One-time setup for the Terraform remote state backend.
# This CANNOT be done with Terraform itself (chicken-and-egg problem —
# Terraform needs a backend to exist before it can manage anything).
# Run this manually, once, with the Azure CLI, then never again unless
# the backend is being rebuilt from scratch.
#
# Usage:
#   ./scripts/bootstrap-backend.sh
#
# Requires: az CLI logged in (az login), Contributor on the target subscription.

set -euo pipefail

# ---- Config: adjust these if your naming convention differs ----
LOCATION="southafricanorth"
RG_NAME="rg-tfstate-haplatform"
STORAGE_ACCOUNT_NAME="sthaplatformtfstate$RANDOM" # storage account names must be globally unique
CONTAINER_NAME="tfstate"
# ------------------------------------------------------------------

echo "==> Checking Azure login context..."
az account show --output table
echo ""
echo "==> This will create:"
echo "    Resource Group:    $RG_NAME (in $LOCATION)"
echo "    Storage Account:   $STORAGE_ACCOUNT_NAME"
echo "    Blob Container:    $CONTAINER_NAME"
echo "    Blob versioning:   Enabled (protects state history from corruption)"
echo ""
read -p "Proceed? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
echo "Aborted."
    exit 1
fi

echo "==> Creating resource group..."
az group create \
  --name "$RG_NAME" \
  --location "$LOCATION" \
  --output table

echo "==> Creating storage account (this can take a minute)..."
az storage account create \
  --resource-group "$RG_NAME" \
  --name "$STORAGE_ACCOUNT_NAME" \
  --sku Standard_LRS \
  --encryption-services blob \
  --min-tls-version TLS1_2 \
  --allow-blob-public-access false \
  --output table

echo "==> Enabling blob versioning (protects Terraform state history)..."
az storage account blob-service-properties update \
  --resource-group "$RG_NAME" \
  --account-name "$STORAGE_ACCOUNT_NAME" \
  --enable-versioning true \
  --output table

echo "==> Creating blob container for state..."
az storage container create \
  --name "$CONTAINER_NAME" \
  --account-name "$STORAGE_ACCOUNT_NAME" \
  --auth-mode login \
  --output table

echo ""
echo "==================================================================="
echo " Backend created. SAVE THESE VALUES — you'll need them for backend.tf"
echo "==================================================================="
echo "resource_group_name  = \"$RG_NAME\""
echo "storage_account_name = \"$STORAGE_ACCOUNT_NAME\""
echo "container_name       = \"$CONTAINER_NAME\""
echo "key (per environment) = \"primary.tfstate\" / \"secondary.tfstate\""
echo "==================================================================="
echo ""
echo "Next: paste these values into environments/primary/backend.tf and"
echo "environments/secondary/backend.tf, then run 'terraform init' in each."
