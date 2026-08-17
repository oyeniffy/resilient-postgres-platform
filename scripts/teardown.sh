#!/usr/bin/env bash
#
# teardown.sh
#
# Destroys all applied infrastructure in the correct dependency order.
# Reverse of the apply order: global (Front Door) depends on both regions'
# App Service hostnames, so it must go first. Secondary depends on primary
# (replica source, VNet peering target), so secondary goes before primary.
#
# Does NOT destroy the Terraform state backend (rg-tfstate-haplatform) —
# that's a one-time bootstrap resource, not something torn down between
# sessions. Destroy it manually and separately if the project is being
# fully retired, not paused.
#
# Usage:
#   ./scripts/teardown.sh
#
# Requires: az CLI logged in, entra_admin_object_id/principal_name env
# vars set if primary's database module still needs them for the destroy
# plan (Terraform needs these vars even for destroy, since they're
# declared as required variables in environments/primary).

set -euo pipefail

ENTRA_ADMIN_OBJECT_ID="${ENTRA_ADMIN_OBJECT_ID:-}"
ENTRA_ADMIN_PRINCIPAL_NAME="${ENTRA_ADMIN_PRINCIPAL_NAME:-}"

if [[ -z "$ENTRA_ADMIN_OBJECT_ID" || -z "$ENTRA_ADMIN_PRINCIPAL_NAME" ]]; then
  echo "ERROR: Set ENTRA_ADMIN_OBJECT_ID and ENTRA_ADMIN_PRINCIPAL_NAME"
  echo "       environment variables before running this script."
  echo ""
  echo "  export ENTRA_ADMIN_OBJECT_ID=\"your-object-id\""
  echo "  export ENTRA_ADMIN_PRINCIPAL_NAME=\"you@yourorg.com\""
  exit 1
fi

echo "==> This will DESTROY all applied infrastructure in:"
echo "    - environments/global   (Front Door)"
echo "    - environments/secondary (networking, database replica, compute)"
echo "    - environments/primary   (networking, database, compute)"
echo ""
echo "    The Terraform state backend (rg-tfstate-haplatform) will NOT be touched."
echo ""
read -p "Type 'destroy' to confirm: " -r
if [[ "$REPLY" != "destroy" ]]; then
    echo "Aborted."
    exit 1
fi

echo ""
echo "==> [1/3] Destroying global (Front Door)..."
cd "$(dirname "$0")/../environments/global"
terraform init -input=false
terraform destroy -auto-approve

echo ""
echo "==> [2/3] Destroying secondary..."
cd ../secondary
terraform init -input=false
terraform destroy -auto-approve

echo ""
echo "==> [3/3] Destroying primary..."
cd ../primary
terraform init -input=false
terraform destroy -auto-approve \
  -var="entra_admin_object_id=$ENTRA_ADMIN_OBJECT_ID" \
  -var="entra_admin_principal_name=$ENTRA_ADMIN_PRINCIPAL_NAME"

echo ""
echo "==================================================================="
echo " Teardown complete. All region and global infrastructure destroyed."
echo " State backend (rg-tfstate-haplatform) left intact for future runs."
echo "==================================================================="
