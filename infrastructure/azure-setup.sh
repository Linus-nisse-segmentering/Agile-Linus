#!/bin/bash

# Enhanced Azure VM Setup Script for CI/CD Demo
# This script creates everything needed for the Recipe Cookbook deployment
# and ensures VM is updated/upgraded after creation
# Also sets the VM IP address in GitHub secrets

set -e  # Exit on any error

# Parse command line arguments
NO_COLORS=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --no-colors    Disable colored output"
            echo "  --help, -h     Show this help message"
            exit 0
            ;;
        --no-colors)
            NO_COLORS=true
            shift
            ;;
        *)
            shift
            ;;
    esac
done

# Configuration variables - CUSTOMIZE THESE
RESOURCE_GROUP="recipe-cookbook-rg"
LOCATION="swedencentral"  # Change to your preferred region (e.g., "eastus", "northeurope")
VM_NAME="recipe-cookbook-vm"
VM_SIZE="Standard_B1s"  # Change to "Standard_B2s" for better performance
ADMIN_USERNAME="azureuser"
SSH_KEY_PATH="$HOME/.ssh/id_rsa.pub"   # Change this path to point at your public key - (your private key should be in the same folder, and should be set in SSH_PRIVATE_KEY on GitHub)

# Disable all color output
GREEN=''
YELLOW=''
RED=''
NC=''

echo "=========================================="
echo "Enhanced Azure VM Setup for Recipe Cookbook"
echo "=========================================="
echo ""

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    echo -e "${RED}❌ Azure CLI is not installed${NC}"
    echo "Install it from: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
fi

echo -e "${GREEN}✅ Azure CLI is installed${NC}"

# Check if logged in to Azure
echo ""
echo "Checking Azure login status..."
if ! az account show &> /dev/null; then
    echo -e "${YELLOW}⚠️  Not logged in to Azure${NC}"
    echo "Logging in..."
    az login
else
    echo -e "${GREEN}✅ Already logged in to Azure${NC}"
    ACCOUNT=$(az account show --query name -o tsv)
    echo "Using subscription: $ACCOUNT"
fi

# Check if SSH key exists
echo ""
if [ ! -f "$SSH_KEY_PATH" ]; then
    echo -e "${YELLOW}⚠️  SSH key not found at $SSH_KEY_PATH${NC}"
    echo "Generating new SSH key..."
    ssh-keygen -t rsa -b 4096 -f "${SSH_KEY_PATH%.pub}" -N "" -C "azure-vm-cicd"
    echo -e "${GREEN}✅ SSH key generated${NC}"
else
    echo -e "${GREEN}✅ SSH key found at $SSH_KEY_PATH${NC}"
fi

# Create resource group
echo ""
echo "=========================================="
echo "Creating Resource Group"
echo "=========================================="
echo "Name: $RESOURCE_GROUP"
echo "Location: $LOCATION"

if az group exists --name "$RESOURCE_GROUP" | grep -q "true"; then
    echo -e "${YELLOW}⚠️  Resource group already exists${NC}"
    read -p "Do you want to delete and recreate it? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Deleting existing resource group..."
        az group delete --name "$RESOURCE_GROUP" --yes --no-wait
        echo "Waiting for deletion to complete..."
        DELETE_TIMEOUT_SEC=600
        DELETE_START_TIME=$SECONDS
        while az group exists --name "$RESOURCE_GROUP" | grep -q "true"; do
            if [ $((SECONDS - DELETE_START_TIME)) -ge $DELETE_TIMEOUT_SEC ]; then
                echo -e "${RED}❌ Timed out waiting for resource group deletion after ${DELETE_TIMEOUT_SEC}s.${NC}"
                echo "Try again later, or delete manually with: az group delete --name \"$RESOURCE_GROUP\" --yes"
                exit 1
            fi
            sleep 10
        done
    else
        echo "Using existing resource group"
    fi
fi

if ! az group exists --name "$RESOURCE_GROUP" | grep -q "true"; then
    az group create \
        --name "$RESOURCE_GROUP" \
        --location "$LOCATION" \
        --output table
    echo -e "${GREEN}✅ Resource group created${NC}"
fi

# Create Virtual Machine
echo ""
echo "=========================================="
echo "Creating Virtual Machine"
echo "=========================================="
echo "VM Name: $VM_NAME"
echo "Size: $VM_SIZE"
echo "Admin User: $ADMIN_USERNAME"
echo "This may take 2-5 minutes..."
echo ""

# Try preferred size first, then fall back to common student-friendly sizes.
VM_SIZE_CANDIDATES=(
    "$VM_SIZE"
    "Standard_B1ms"
    "Standard_B2s"
    "Standard_DS1_v2"
    "Standard_A1_v2"
)

VM_CREATED=false
for SIZE in "${VM_SIZE_CANDIDATES[@]}"; do
    echo "Attempting VM creation with size: $SIZE"

    set +e
    VM_CREATE_OUTPUT=$(az vm create \
        --resource-group "$RESOURCE_GROUP" \
        --name "$VM_NAME" \
        --image "Canonical:0001-com-ubuntu-server-jammy:22_04-lts:latest" \
        --size "$SIZE" \
        --admin-username "$ADMIN_USERNAME" \
        --ssh-key-values "$SSH_KEY_PATH" \
        --public-ip-sku Standard \
        --output table 2>&1)
    VM_CREATE_EXIT_CODE=$?
    set -e

    if [ $VM_CREATE_EXIT_CODE -eq 0 ]; then
        VM_SIZE="$SIZE"
        VM_CREATED=true
        echo "$VM_CREATE_OUTPUT"
        echo -e "${GREEN}✅ Virtual machine created with size $VM_SIZE${NC}"
        break
    fi

    echo "$VM_CREATE_OUTPUT"
    if echo "$VM_CREATE_OUTPUT" | grep -qiE "SkuNotAvailable|Capacity Restrictions|currently not available"; then
        echo -e "${YELLOW}⚠️  Size $SIZE is not currently available in $LOCATION. Trying next size...${NC}"
        continue
    fi

    echo -e "${RED}❌ VM creation failed for a non-capacity reason. Aborting.${NC}"
    exit 1
done

if [ "$VM_CREATED" != true ]; then
    echo -e "${RED}❌ Unable to create VM: no candidate sizes are currently available in $LOCATION.${NC}"
    echo "Tip: Change LOCATION in this script or add additional VM sizes to VM_SIZE_CANDIDATES."
    exit 1
fi

# Open required ports
echo ""
echo "=========================================="
echo "Configuring Network Security"
echo "=========================================="
echo "Opening ports: 22 (SSH), 80 (HTTP), 443 (HTTPS)"

az vm open-port \
    --resource-group "$RESOURCE_GROUP" \
    --name "$VM_NAME" \
    --port 22 \
    --priority 290 \
    --output table

az vm open-port \
    --resource-group "$RESOURCE_GROUP" \
    --name "$VM_NAME" \
    --port 80 \
    --priority 300 \
    --output table

az vm open-port \
    --resource-group "$RESOURCE_GROUP" \
    --name "$VM_NAME" \
    --port 443 \
    --priority 310 \
    --output table

echo -e "${GREEN}✅ Ports configured${NC}"

# Get VM public IP
echo ""
echo "=========================================="
echo "Getting VM Information"
echo "=========================================="

VM_IP=$(az vm show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$VM_NAME" \
    --show-details \
    --query publicIps \
    --output tsv)

echo -e "${GREEN}✅ VM is ready!${NC}"
echo ""
echo "VM Public IP: ${GREEN}$VM_IP${NC}"
echo "SSH command: ${YELLOW}ssh $ADMIN_USERNAME@$VM_IP${NC}"

# Wait for VM to be fully ready
echo ""
echo "Waiting for VM to be fully ready..."
sleep 30

# Test SSH connection and update/upgrade VM
echo ""
echo "=========================================="
echo "Connecting to VM and updating system"
echo "=========================================="

if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=30 "$ADMIN_USERNAME@$VM_IP" "
    set -e
    echo 'Connected to VM, starting system update...'
    
    echo 'Updating package lists...'
    sudo apt update -y
    
    echo 'Upgrading installed packages...'
    sudo apt upgrade -y
    
    echo 'Installing basic utilities...'
    sudo apt install -y curl wget git unzip
    
    echo 'Cleaning up...'
    sudo apt autoremove -y
    sudo apt autoclean
    
    echo 'System update and upgrade complete!'
    echo 'VM is ready for Docker installation.'
"; then
    echo -e "${GREEN}✅ VM system update and upgrade completed successfully${NC}"
else
    echo -e "${YELLOW}⚠️  SSH connection failed. VM may still be initializing. Wait a minute and try again.${NC}"
    exit 1
fi

# Install Docker on the VM
echo ""
read -p "Do you want to install Docker on the VM now? (Y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    echo ""
    echo "=========================================="
    echo "Installing Docker on VM"
    echo "=========================================="

    ssh -o StrictHostKeyChecking=no "$ADMIN_USERNAME@$VM_IP" << 'ENDSSH'
        set -e
        echo "Updating package index..."
        sudo apt update

        echo "Installing prerequisites..."
        sudo apt install -y apt-transport-https ca-certificates curl software-properties-common

        echo "Adding Docker GPG key..."
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

        echo "Adding Docker repository..."
        echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

        echo "Installing Docker and Docker Compose..."
        sudo apt update
        sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

        echo "Adding user to docker group..."
        sudo usermod -aG docker $USER

        echo "Enabling UFW firewall..."
        sudo ufw --force enable
        sudo ufw allow 22/tcp
        sudo ufw allow 80/tcp
        sudo ufw allow 443/tcp

        echo "Creating app directory..."
        mkdir -p ~/app

        echo "Docker installation complete!"
        docker --version
        docker compose version
ENDSSH

    echo -e "${GREEN}✅ Docker installed successfully${NC}"
    echo -e "${YELLOW}⚠️  Note: You need to logout and login again for docker group changes to take effect${NC}"
fi

# Set VM IP in GitHub secrets
echo ""
echo "=========================================="
echo "Setting VM IP in GitHub Secrets"
echo "=========================================="

# Check if GitHub CLI is installed
if ! command -v gh &> /dev/null; then
    echo -e "${YELLOW}⚠️  GitHub CLI is not installed${NC}"
    echo "Install it from: https://cli.github.com/"
    echo "Then run: gh auth login"
    echo ""
    echo "Manual steps to set GitHub secrets:"
    echo "1. Navigate to your GitHub repository Settings > Secrets and variables > Actions"
    echo "2. Add these secrets:"
    echo "   SSH_USER = $ADMIN_USERNAME"
    echo "   SSH_HOST = $VM_IP"
    echo "   SSH_PRIVATE_KEY = Contents of ~/.ssh/id_rsa"
    echo ""
    echo "3. Or install GitHub CLI and run this script from your repository directory"
else
    # Check if authenticated with GitHub CLI
    if ! gh auth status &> /dev/null; then
        echo -e "${YELLOW}⚠️  Not authenticated with GitHub CLI${NC}"
        echo "Running: gh auth login"
        gh auth login
    fi
    
    echo "Setting GitHub secrets..."
    
    # Set SSH_USER secret
    echo "$ADMIN_USERNAME" | gh secret set SSH_USER
    
    # Set SSH_HOST secret  
    echo "$VM_IP" | gh secret set SSH_HOST
    
    # Set SSH_PRIVATE_KEY secret
    gh secret set SSH_PRIVATE_KEY < "${SSH_KEY_PATH%.pub}"
    
    echo -e "${GREEN}✅ GitHub secrets set successfully${NC}"
fi

# Summary
echo ""
echo "=========================================="
echo "Setup Complete! 🎉"
echo "=========================================="
echo ""
echo "Resource Group: ${GREEN}$RESOURCE_GROUP${NC}"
echo "VM Name: ${GREEN}$VM_NAME${NC}"
echo "VM Public IP: ${GREEN}$VM_IP${NC}"
echo "Admin Username: ${GREEN}$ADMIN_USERNAME${NC}"
echo ""
echo "=========================================="
echo "Next Steps:"
echo "=========================================="
echo ""
echo "1. SSH to your VM (logout and login if Docker was installed):"
echo "   ${YELLOW}ssh $ADMIN_USERNAME@$VM_IP${NC}"
echo ""
echo "2. Login to GitHub Container Registry on the VM:"
echo "   ${YELLOW}docker login ghcr.io -u YOUR_GITHUB_USERNAME${NC}"
echo "   (Use your CR_PAT token as password)"
echo ""
echo "3. GitHub secrets have been set automatically:"
echo "   ${YELLOW}SSH_USER${NC} = $ADMIN_USERNAME"
echo "   ${YELLOW}SSH_HOST${NC} = $VM_IP"
echo "   ${YELLOW}SSH_PRIVATE_KEY${NC} = Your SSH private key"
echo ""
echo "=========================================="
echo ""
echo "To delete everything later, run:"
echo "   ${RED}./azure-teardown.sh${NC}"
echo ""