#!/bin/bash


# Azure Resource Teardown Script
# This script deletes all resources in the resource group except public IPs and VNet/subnet (to preserve static IPs)

set -e  # Exit on any error

# Configuration - MUST MATCH azure-setup.sh
RESOURCE_GROUP="recipe-cookbook-rg"

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


# Confirmation prompt
echo -e "${RED}⚠️  WARNING: This will permanently delete all VMs, disks, NICs, NSGs, and storage in '$RESOURCE_GROUP'${NC}"
echo -e "${YELLOW}Public IPs and VNet will be preserved for static IPs.${NC}"
echo ""
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

echo ""
echo "=========================================="
echo "Deleting Resources (except static IPs and VNet)"
echo "=========================================="
echo "Resource Group: $RESOURCE_GROUP"
echo "This may take several minutes..."
echo ""

# Delete VMs
for vm in $(az vm list --resource-group "$RESOURCE_GROUP" --query "[].name" -o tsv); do
    echo "Deleting VM: $vm"
    az vm delete --resource-group "$RESOURCE_GROUP" --name "$vm" --yes
done

# Delete managed disks
for disk in $(az disk list --resource-group "$RESOURCE_GROUP" --query "[].name" -o tsv); do
    echo "Deleting Disk: $disk"
    az disk delete --resource-group "$RESOURCE_GROUP" --name "$disk" --yes
done

# Delete NICs
for nic in $(az network nic list --resource-group "$RESOURCE_GROUP" --query "[].name" -o tsv); do
    echo "Deleting NIC: $nic"
    az network nic delete --resource-group "$RESOURCE_GROUP" --name "$nic"
done

# Delete NSGs
for nsg in $(az network nsg list --resource-group "$RESOURCE_GROUP" --query "[].name" -o tsv); do
    echo "Deleting NSG: $nsg"
    az network nsg delete --resource-group "$RESOURCE_GROUP" --name "$nsg"
done

# Delete storage accounts
for sa in $(az storage account list --resource-group "$RESOURCE_GROUP" --query "[].name" -o tsv); do
    echo "Deleting Storage Account: $sa"
    az storage account delete --resource-group "$RESOURCE_GROUP" --name "$sa" --yes
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