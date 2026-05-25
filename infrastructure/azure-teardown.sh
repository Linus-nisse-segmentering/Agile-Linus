#!/bin/bash


# Azure Resource Teardown Script
# This script deletes all resources in the resource group except public IPs and VNet/subnet (to preserve static IPs)

set -e  # Exit on any error

# Logging setup
LOG_FILE="$(dirname "$0")/teardown.log"
echo "--- Azure teardown started at $(date) ---" > "$LOG_FILE"
exec > >(tee -a "$LOG_FILE") 2>&1

# record main shell pid so pause_on_exit only runs once (avoid duplicate trap runs in subprocesses)
MAIN_PID=$$

pause_on_exit() {
    # only run in the main shell (skip if invoked in a subprocess)
    if [ "$$" != "$MAIN_PID" ]; then
        return
    fi
    echo "--- Azure teardown ended at $(date) ---" | tee -a "$LOG_FILE"
    read -p "Press Enter to close this script..." -r
}

trap 'pause_on_exit' EXIT

# Configuration - MUST MATCH azure-setup.sh
RESOURCE_GROUP="recipe-cookbook-rg"

# Non-interactive mode: set AUTO_CONFIRM=1 to skip prompts
AUTO_CONFIRM=${AUTO_CONFIRM:-0}

# Helper: retry a command with backoff
retry_cmd() {
    local max_attempts=${1:-3}
    shift
    local attempt=0
    local cmd=("$@")
    while [ $attempt -lt $max_attempts ]; do
        attempt=$((attempt+1))
        "${cmd[@]}" && return 0 || true
        sleep $((attempt * 2))
    done
    return 1
}

# Helper: delete a resource by id with retries and debug on failure
delete_by_id() {
    local id="$1"
    # strip possible CRLF artifacts
    id=$(printf '%s' "$id" | tr -d '\r')
    echo "Deleting resource by id: $id"
    # prefer resource-specific delete commands (they accept --yes) to avoid generic resource errors
    rtype=$(az resource show --ids "$id" --query type -o tsv 2>/dev/null || true)
    # Normalize type to lowercase for checks
    rtype_lc=$(printf '%s' "$rtype" | tr '[:upper:]' '[:lower:]')

    ATTEMPTS=0
    MAX_ATTEMPTS=3
    DELETED=0
    while [ $ATTEMPTS -lt $MAX_ATTEMPTS ]; do
        ATTEMPTS=$((ATTEMPTS+1))
        if echo "$rtype_lc" | grep -q "microsoft.compute/virtualmachines"; then
            MSYS_NO_PATHCONV=1 az vm delete --ids "$id" --yes && { DELETED=1; break; } || true
        elif echo "$rtype_lc" | grep -q "microsoft.compute/disks"; then
            MSYS_NO_PATHCONV=1 az disk delete --ids "$id" --yes && { DELETED=1; break; } || true
        elif echo "$rtype_lc" | grep -q "microsoft.network/networkinterfaces"; then
            MSYS_NO_PATHCONV=1 az network nic delete --ids "$id" && { DELETED=1; break; } || true
        elif echo "$rtype_lc" | grep -q "microsoft.network/networksecuritygroups"; then
            MSYS_NO_PATHCONV=1 az network nsg delete --ids "$id" && { DELETED=1; break; } || true
        elif echo "$rtype_lc" | grep -q "microsoft.storage/storageaccounts"; then
            MSYS_NO_PATHCONV=1 az storage account delete --ids "$id" --yes && { DELETED=1; break; } || true
        else
            # fallback to generic resource delete (no --yes option)
            MSYS_NO_PATHCONV=1 az resource delete --ids "$id" && { DELETED=1; break; } || true
        fi
        sleep $((ATTEMPTS * 2))
    done

    if [ $DELETED -eq 1 ]; then
        echo "Deleted $id"
        return 0
    fi

    echo "Primary delete failed for $id; attempting az resource delete --ids with --no-wait and polling (debug output follows)"
    MSYS_NO_PATHCONV=1 az resource delete --ids "$id" --no-wait --debug || true
    # poll for up to 2 minutes
    local end=$((SECONDS+120))
    while true; do
        if ! az resource show --ids "$id" &>/dev/null; then
            echo "Resource $id no longer found"
            return 0
        fi
        if [ $SECONDS -ge $end ]; then
            echo "Timeout waiting for resource removal for $id"
            return 1
        fi
        sleep 5
    done
}

# Helper: remove resource locks in the resource group (if any)
remove_locks() {
    lock_ids=$(az lock list --resource-group "$RESOURCE_GROUP" --query "[].id" -o tsv)
    if [ -z "$lock_ids" ]; then
        echo "No resource locks found in $RESOURCE_GROUP"
        return 0
    fi
    echo "Found resource locks; attempting to remove them"
    for lockId in $lock_ids; do
        echo "Removing lock: $lockId"
        az lock delete --ids "$lockId" || echo "Failed to delete lock $lockId — you may need to remove it manually"
    done
}

# Check if terminal supports ANSI colors
if [ -t 1 ]; then
    # Terminal supports ANSI colors
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    RED='\033[0;31m'
    NC='\033[0m' # No Color
else
    # Terminal does not support ANSI colors
    GREEN=''
    YELLOW=''
    RED=''
    NC=''
fi

echo "=========================================="
echo "Azure Resource Teardown"
echo "=========================================="
echo ""

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    echo -e "${RED}❌ Azure CLI is not installed${NC}"
    exit 1
fi

# Check if logged in to Azure
if ! az account show &> /dev/null; then
    echo -e "${RED}❌ Not logged in to Azure${NC}"
    echo "Please login first: az login"
    exit 1
fi

echo -e "${GREEN}✅ Logged in to Azure${NC}"
ACCOUNT=$(az account show --query name -o tsv)
echo "Using subscription: $ACCOUNT"
echo ""

# Check if resource group exists
if ! az group exists --name "$RESOURCE_GROUP" | grep -q "true"; then
    echo -e "${YELLOW}⚠️  Resource group '$RESOURCE_GROUP' does not exist${NC}"
    echo "Nothing to delete."
    exit 0
fi


# Show what will be deleted
echo "=========================================="
echo "Resources to be deleted (except static IPs and VNet):"
echo "=========================================="
echo ""

# List resources to be deleted
echo "Virtual Machines:"
az vm list --resource-group "$RESOURCE_GROUP" --query "[].name" -o tsv
echo ""
echo "Managed Disks:"
az disk list --resource-group "$RESOURCE_GROUP" --query "[].name" -o tsv
echo ""
echo "Network Interfaces:"
az network nic list --resource-group "$RESOURCE_GROUP" --query "[].name" -o tsv
echo ""
echo "Network Security Groups:"
az network nsg list --resource-group "$RESOURCE_GROUP" --query "[].name" -o tsv
echo ""
echo "Storage Accounts:"
az storage account list --resource-group "$RESOURCE_GROUP" --query "[].name" -o tsv
echo ""


# Confirmation prompt (support AUTO_CONFIRM)
echo -e "${RED}⚠️  WARNING: This will permanently delete all VMs, disks, NICs, NSGs, and storage in '$RESOURCE_GROUP'${NC}"
echo -e "${YELLOW}Public IPs and VNet will be preserved for static IPs.${NC}"
echo ""
if [ "$AUTO_CONFIRM" -eq 1 ]; then
    echo "AUTO_CONFIRM=1: skipping interactive prompts and proceeding."
else
    read -p "Are you sure you want to continue? (yes/NO): " -r
    echo
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo "Teardown cancelled."
        exit 0
    fi

    # Double confirmation for safety
    echo ""
    echo -e "${RED}⚠️  FINAL CONFIRMATION${NC}"
    read -p "Type the resource group name '$RESOURCE_GROUP' to confirm deletion: " -r
    echo
    if [[ $REPLY != "$RESOURCE_GROUP" ]]; then
        echo -e "${RED}❌ Resource group name doesn't match. Teardown cancelled.${NC}"
        exit 1
    fi
fi

echo ""
echo "=========================================="
echo "Deleting Resources (except static IPs and VNet)"
echo "=========================================="
echo "Resource Group: $RESOURCE_GROUP"
echo "This may take several minutes..."
echo ""

remove_locks

# Delete VMs by resource id using robust delete_by_id
set +e
VM_DELETE_ERRORS=0
for vmId in $(az vm list --resource-group "$RESOURCE_GROUP" --query "[].id" -o tsv); do
    echo "Deleting VM resource: $vmId"
    if delete_by_id "$vmId"; then
        echo "Deleted VM $vmId"
    else
        VM_DELETE_ERRORS=$((VM_DELETE_ERRORS+1))
        echo "ERROR: Failed to delete VM resource: $vmId"
        echo "Collecting diagnostics for VM resource: $vmId"
        az resource show --ids "$vmId" --output json || true
    fi
done
set -e
if [ $VM_DELETE_ERRORS -ne 0 ]; then
    echo -e "${YELLOW}⚠️  Some VM deletions failed. Check the log for details.${NC}"
fi

# Delete managed disks
for diskId in $(az disk list --resource-group "$RESOURCE_GROUP" --query "[].id" -o tsv); do
    echo "Deleting Disk resource: $diskId"
    delete_by_id "$diskId" || echo "Failed to delete disk $diskId"
done

# Delete NICs
for nicId in $(az network nic list --resource-group "$RESOURCE_GROUP" --query "[].id" -o tsv); do
    echo "Deleting NIC resource: $nicId"
    delete_by_id "$nicId" || echo "Failed to delete nic $nicId"
done

# Delete NSGs
for nsgId in $(az network nsg list --resource-group "$RESOURCE_GROUP" --query "[].id" -o tsv); do
    echo "Deleting NSG resource: $nsgId"
    delete_by_id "$nsgId" || echo "Failed to delete nsg $nsgId"
done

# Delete storage accounts
for saId in $(az storage account list --resource-group "$RESOURCE_GROUP" --query "[].id" -o tsv); do
    echo "Deleting Storage Account resource: $saId"
    delete_by_id "$saId" || echo "Failed to delete storage account $saId"
done

echo -e "${GREEN}✅ Resource deletion complete (static IPs and VNet preserved)${NC}"
echo ""
echo "You may need to manually check for any remaining resources."
echo "Public IPs and VNet/subnet are still present for static IP stability."
echo ""
echo "=========================================="
echo "Teardown Complete! 🗑️"
echo "=========================================="
echo ""
echo "All deletable resources in '$RESOURCE_GROUP' have been deleted. Static IPs and VNet are preserved."
echo ""