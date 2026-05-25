
#!/bin/bash

# Enhanced Azure VM Setup Script for CI/CD Demo
# This script creates everything needed for the Recipe Cookbook deployment
# and ensures VM is updated/upgraded after creation
# Also sets the VM IP address in GitHub secrets


set -e  # Exit on any error

# Logging setup
LOG_FILE="$(dirname "$0")/setup.log"
echo "--- Azure setup started at $(date) ---" > "$LOG_FILE"
exec > >(tee -a "$LOG_FILE") 2>&1

pause_on_exit() {
    echo "--- Azure setup ended at $(date) ---" | tee -a "$LOG_FILE"
    read -p "Press Enter to close this script..." -r
}

trap 'pause_on_exit' ERR

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

# Avoid Git Bash path mangling of Azure resource IDs
if [[ -n "$MSYSTEM" ]]; then
    export MSYS2_ARG_CONV_EXCL="*"
fi

# Configuration variables - CUSTOMIZE THESE
RESOURCE_GROUP="recipe-cookbook-rg"
LOCATION="francecentral"  # Change to your preferred region (e.g., "eastus", "northeurope")
VM_NAME="recipe-cookbook-vm"
VM_SIZE="Standard_B1s"  # Change to "Standard_B2s" for better performance
ADMIN_USERNAME="azureuser"
SSH_KEY_PATH="$HOME/.ssh/id_rsa.pub"   # Change this path to point at your public key - (your private key should be in the same folder, and should be set in SSH_PRIVATE_KEY on GitHub)
SSH_PRIVATE_KEY_PATH="${SSH_KEY_PATH%.pub}"
APP_PUBLIC_IP_NAME="recipe-cookbook-public-ip"

# Backend (private) VM settings
BACKEND_VM_NAME="recipe-cookbook-backend-vm"
BACKEND_NIC_NAME="${BACKEND_VM_NAME}-nic"
BACKEND_NSG_NAME="${BACKEND_VM_NAME}-nsg"
BACKEND_VM_SIZE="Standard_B1s"

# Private DNS (internal name for backend)
PRIVATE_DNS_ZONE_NAME="backend.internal"
PRIVATE_DNS_RECORD_NAME="backend"

# Database VM configuration
DB_VM_NAME="recipe-cookbook-db-vm"
DB_VM_SIZE="Standard_B1s"
DB_NAME="recipe_cookbook"
DB_USER="recipe_user"
DB_PASSWORD="recipe_pass"


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
    echo "Generating new RSA SSH key..."
    ssh-keygen -t rsa -b 4096 -f "$SSH_PRIVATE_KEY_PATH" -N "" -C "azure-vm-cicd"
    echo -e "${GREEN}✅ SSH key generated${NC}"
else
    if grep -q '^ssh-rsa ' "$SSH_KEY_PATH"; then
        echo -e "${GREEN}✅ SSH key found at $SSH_KEY_PATH${NC}"
    else
        echo -e "${YELLOW}⚠️  SSH key is not RSA. Generating a dedicated RSA key for Azure...${NC}"
        SSH_KEY_PATH="$HOME/.ssh/id_rsa_azure.pub"
        SSH_PRIVATE_KEY_PATH="${SSH_KEY_PATH%.pub}"
        ssh-keygen -t rsa -b 4096 -f "$SSH_PRIVATE_KEY_PATH" -N "" -C "azure-vm-cicd"
        echo -e "${GREEN}✅ RSA SSH key generated at $SSH_KEY_PATH${NC}"
    fi
fi

# Create resource group
echo ""
echo "=========================================="
echo "Creating Resource Group"
echo "=========================================="
echo "Name: $RESOURCE_GROUP"
echo "Location: $LOCATION"


if az group exists --name "$RESOURCE_GROUP" | grep -q "true"; then
    echo -e "${YELLOW}⚠️  Resource group already exists. Using existing resource group.${NC}"
else
    az group create \
        --name "$RESOURCE_GROUP" \
        --location "$LOCATION" \
        --output table
    echo -e "${GREEN}✅ Resource group created${NC}"
fi

if ! az group exists --name "$RESOURCE_GROUP" | grep -q "true"; then
    az group create \
        --name "$RESOURCE_GROUP" \
        --location "$LOCATION" \
        --output table
    echo -e "${GREEN}✅ Resource group created${NC}"
fi

# Create or reuse a static public IP for the app VM
echo ""
echo "=========================================="
echo "Ensuring Static Public IP for App VM"
echo "=========================================="

if az network public-ip show --resource-group "$RESOURCE_GROUP" --name "$APP_PUBLIC_IP_NAME" &> /dev/null; then
    echo -e "${YELLOW}⚠️  Public IP $APP_PUBLIC_IP_NAME already exists. Reusing.${NC}"
else
    az network public-ip create \
        --resource-group "$RESOURCE_GROUP" \
        --name "$APP_PUBLIC_IP_NAME" \
        --sku Standard \
        --allocation-method Static \
        --output table
    echo -e "${GREEN}✅ Public IP created${NC}"
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
        --ssh-key-values "$(cat "$SSH_KEY_PATH")" \
        --public-ip-address "$APP_PUBLIC_IP_NAME" \
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

# Wait for VM resource to be available (Azure eventual consistency)
VM_WAIT_TIMEOUT=180 # seconds
VM_WAIT_INTERVAL=5
VM_WAIT_ELAPSED=0
echo "Waiting for VM resource to become available..."
while ! az vm show --resource-group "$RESOURCE_GROUP" --name "$VM_NAME" &> /dev/null; do
    sleep $VM_WAIT_INTERVAL
    VM_WAIT_ELAPSED=$((VM_WAIT_ELAPSED + VM_WAIT_INTERVAL))
    if [ $VM_WAIT_ELAPSED -ge $VM_WAIT_TIMEOUT ]; then
        echo -e "${RED}❌ Timed out waiting for VM resource to become available in Azure.${NC}"
        exit 1
    fi
done
echo -e "${GREEN}✅ VM resource is now available in Azure${NC}"

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

# Get app VM private IP for DB access rules
APP_PRIVATE_IP=$(az vm show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$VM_NAME" \
    --show-details \
    --query privateIps \
    --output tsv)

APP_NIC_ID=$(az vm show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$VM_NAME" \
    --query "networkProfile.networkInterfaces[0].id" \
    --output tsv)

APP_NIC_NAME=$(az network nic show \
    --ids "$APP_NIC_ID" \
    --query name \
    --output tsv)

APP_IPCONFIG_NAME=$(az network nic show \
    --ids "$APP_NIC_ID" \
    --query "ipConfigurations[0].name" \
    --output tsv)

az network nic ip-config update \
    --resource-group "$RESOURCE_GROUP" \
    --nic-name "$APP_NIC_NAME" \
    --name "$APP_IPCONFIG_NAME" \
    --private-ip-address "$APP_PRIVATE_IP" \
    --output table

# Derive VNet and Subnet names from the app NIC so we can reuse the same subnet for backend NIC
APP_SUBNET_ID=$(az network nic show \
    --ids "$APP_NIC_ID" \
    --query "ipConfigurations[0].subnet.id" \
    --output tsv)

VNET_NAME=$(echo "$APP_SUBNET_ID" | awk -F/ '{print $(NF-2)}')
SUBNET_NAME=$(echo "$APP_SUBNET_ID" | awk -F/ '{print $NF}')

# --- Create backend NIC and VM (private-only) ---
echo ""
echo "=========================================="
echo "Creating Backend (private) VM and NIC"
echo "=========================================="
if az network nic show --resource-group "$RESOURCE_GROUP" --name "$BACKEND_NIC_NAME" &> /dev/null; then
    echo -e "⚠️  Backend NIC $BACKEND_NIC_NAME already exists. Reusing.${NC}"
else
    az network nic create \
        --resource-group "$RESOURCE_GROUP" \
        --name "$BACKEND_NIC_NAME" \
        --vnet-name "$VNET_NAME" \
        --subnet "$SUBNET_NAME" \
        --output table
    echo -e "${GREEN}✅ Backend NIC created${NC}"
fi

BACKEND_NIC_ID=$(az network nic show --resource-group "$RESOURCE_GROUP" --name "$BACKEND_NIC_NAME" --query id -o tsv)

if az vm show --resource-group "$RESOURCE_GROUP" --name "$BACKEND_VM_NAME" &> /dev/null; then
    echo -e "${YELLOW}⚠️  Backend VM already exists. Skipping creation.${NC}"
else
    az vm create \
        --resource-group "$RESOURCE_GROUP" \
        --name "$BACKEND_VM_NAME" \
        --nics "$BACKEND_NIC_ID" \
        --image "Canonical:0001-com-ubuntu-server-jammy:22_04-lts:latest" \
        --size "$BACKEND_VM_SIZE" \
        --admin-username "$ADMIN_USERNAME" \
        --ssh-key-values "$(cat "$SSH_KEY_PATH")" \
        --public-ip-address "" \
        --output table

    echo -e "${GREEN}✅ Backend VM created (no public IP)${NC}"
fi

BACKEND_PRIVATE_IP=$(az network nic show --resource-group "$RESOURCE_GROUP" --name "$BACKEND_NIC_NAME" --query "ipConfigurations[0].privateIpAddress" -o tsv)
echo "Backend private IP: $BACKEND_PRIVATE_IP"

# Create Private DNS zone and link to VNet, add A record for backend
if az network private-dns zone show --resource-group "$RESOURCE_GROUP" --name "$PRIVATE_DNS_ZONE_NAME" &> /dev/null; then
    echo -e "${YELLOW}⚠️  Private DNS zone $PRIVATE_DNS_ZONE_NAME exists. Reusing.${NC}"
else
    az network private-dns zone create --resource-group "$RESOURCE_GROUP" --name "$PRIVATE_DNS_ZONE_NAME"
    echo -e "${GREEN}✅ Private DNS zone created: $PRIVATE_DNS_ZONE_NAME${NC}"
fi

# Link zone to VNet
if az network private-dns link vnet show --resource-group "$RESOURCE_GROUP" --zone-name "$PRIVATE_DNS_ZONE_NAME" --name "link-$VNET_NAME" &> /dev/null; then
    echo -e "${YELLOW}⚠️  Private DNS zone already linked to VNet.${NC}"
else
    az network private-dns link vnet create --resource-group "$RESOURCE_GROUP" --zone-name "$PRIVATE_DNS_ZONE_NAME" --name "link-$VNET_NAME" --virtual-network "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Network/virtualNetworks/$VNET_NAME" --registration-enabled false
    echo -e "${GREEN}✅ Private DNS zone linked to VNet${NC}"
fi

# Create A record for backend
az network private-dns record-set a create --resource-group "$RESOURCE_GROUP" --zone-name "$PRIVATE_DNS_ZONE_NAME" --name "$PRIVATE_DNS_RECORD_NAME" --ttl 300 || true
az network private-dns record-set a add-record --resource-group "$RESOURCE_GROUP" --zone-name "$PRIVATE_DNS_ZONE_NAME" --record-set-name "$PRIVATE_DNS_RECORD_NAME" --ipv4-address "$BACKEND_PRIVATE_IP" || true

# Create Database Virtual Machine
echo ""
echo "=========================================="
echo "Creating Database Virtual Machine"
echo "=========================================="
echo "DB VM Name: $DB_VM_NAME"
echo "Size: $DB_VM_SIZE"
echo "Admin User: $ADMIN_USERNAME"

APP_SUBNET_ID=$(az network nic show \
    --ids "$APP_NIC_ID" \
    --query "ipConfigurations[0].subnet.id" \
    --output tsv)

VNET_NAME=$(echo "$APP_SUBNET_ID" | awk -F/ '{print $(NF-2)}')
SUBNET_NAME=$(echo "$APP_SUBNET_ID" | awk -F/ '{print $NF}')

if az vm show --resource-group "$RESOURCE_GROUP" --name "$DB_VM_NAME" &> /dev/null; then
    echo -e "${YELLOW}⚠️  DB VM already exists. Skipping creation.${NC}"
else
    az vm create \
        --resource-group "$RESOURCE_GROUP" \
        --name "$DB_VM_NAME" \
        --image "Canonical:0001-com-ubuntu-server-jammy:22_04-lts:latest" \
        --size "$DB_VM_SIZE" \
        --admin-username "$ADMIN_USERNAME" \
        --ssh-key-values "$(cat "$SSH_KEY_PATH")" \
        --public-ip-sku Standard \
        --vnet-name "$VNET_NAME" \
        --subnet "$SUBNET_NAME" \
        --output table

    echo -e "${GREEN}✅ Database virtual machine created${NC}"
fi

# Open SSH port for DB VM
az vm open-port \
    --resource-group "$RESOURCE_GROUP" \
    --name "$DB_VM_NAME" \
    --port 22 \
    --priority 320 \
    --output table

# Allow Postgres only from the app VM private IP
DB_NIC_ID=$(az vm show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$DB_VM_NAME" \
    --query "networkProfile.networkInterfaces[0].id" \
    --output tsv)

DB_NSG_ID=$(az network nic show \
    --ids "$DB_NIC_ID" \
    --query "networkSecurityGroup.id" \
    --output tsv)

DB_NSG_NAME=$(az network nsg show \
    --ids "$DB_NSG_ID" \
    --query "name" \
    --output tsv)

az network nsg rule create \
    --resource-group "$RESOURCE_GROUP" \
    --nsg-name "$DB_NSG_NAME" \
    --name AllowPostgresFromApp \
    --priority 330 \
    --direction Inbound \
    --access Allow \
    --protocol Tcp \
    --source-address-prefixes "$BACKEND_PRIVATE_IP" \
    --destination-port-ranges 5432 \
    --output table

DB_PRIVATE_IP=$(az vm show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$DB_VM_NAME" \
    --show-details \
    --query privateIps \
    --output tsv)

DB_NIC_NAME=$(az network nic show \
    --ids "$DB_NIC_ID" \
    --query name \
    --output tsv)

DB_IPCONFIG_NAME=$(az network nic show \
    --ids "$DB_NIC_ID" \
    --query "ipConfigurations[0].name" \
    --output tsv)

az network nic ip-config update \
    --resource-group "$RESOURCE_GROUP" \
    --nic-name "$DB_NIC_NAME" \
    --name "$DB_IPCONFIG_NAME" \
    --private-ip-address "$DB_PRIVATE_IP" \
    --output table

DB_PUBLIC_IP=$(az vm show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$DB_VM_NAME" \
    --show-details \
    --query publicIps \
    --output tsv)

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

# Install PostgreSQL on the DB VM
echo ""
read -p "Do you want to install PostgreSQL on the DB VM now? (Y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    echo ""
    echo "=========================================="
    echo "Installing PostgreSQL on DB VM"
    echo "=========================================="

    ssh -o StrictHostKeyChecking=no "$ADMIN_USERNAME@$DB_PUBLIC_IP" << ENDSSH
        set -e
        echo "Updating package index..."
        sudo apt update

        echo "Installing PostgreSQL..."
        sudo apt install -y postgresql postgresql-contrib

        echo "Configuring PostgreSQL for remote access..."
        sudo sed -i "s/^#listen_addresses =.*/listen_addresses = '*'/" /etc/postgresql/*/main/postgresql.conf

        echo "Allowing app VM to connect..."
        echo "host    all             all             ${APP_PRIVATE_IP}/32            md5" | sudo tee -a /etc/postgresql/*/main/pg_hba.conf > /dev/null

        echo "Restarting PostgreSQL..."
        sudo systemctl restart postgresql

        echo "Creating database and user..."
        sudo -u postgres psql -v ON_ERROR_STOP=1 << SQL
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${DB_USER}') THEN
        CREATE ROLE ${DB_USER} LOGIN PASSWORD '${DB_PASSWORD}';
    END IF;
END
$$;

DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_database WHERE datname = '${DB_NAME}') THEN
        CREATE DATABASE ${DB_NAME};
    END IF;
END
$$;

GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} TO ${DB_USER};
SQL

        echo "PostgreSQL installation complete."
ENDSSH

    echo -e "${GREEN}✅ PostgreSQL installed and configured${NC}"
fi

# Set VM IP in GitHub secrets
echo ""
echo "=========================================="
echo "Setting VM IP in GitHub Secrets"
echo "=========================================="

# Re-fetch IP in case it changed during provisioning.
VM_IP=$(az vm show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$VM_NAME" \
    --show-details \
    --query publicIps \
    --output tsv)

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
    echo "   DB_HOST = $DB_PRIVATE_IP" 
    echo "   DB_PORT = 5432" 
    echo "   DB_NAME = $DB_NAME" 
    echo "   DB_USER = $DB_USER" 
    echo "   DB_PASSWORD = $DB_PASSWORD" 
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
    gh secret set SSH_PRIVATE_KEY < "$SSH_PRIVATE_KEY_PATH"

    # Set DB connection secrets
    echo "$DB_PRIVATE_IP" | gh secret set DB_HOST
    echo "5432" | gh secret set DB_PORT
    echo "$DB_NAME" | gh secret set DB_NAME
    echo "$DB_USER" | gh secret set DB_USER
    echo "$DB_PASSWORD" | gh secret set DB_PASSWORD
    
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
echo "DB VM Name: ${GREEN}$DB_VM_NAME${NC}"
echo "DB VM Public IP: ${GREEN}$DB_PUBLIC_IP${NC}"
echo "DB VM Private IP: ${GREEN}$DB_PRIVATE_IP${NC}"
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
echo "   ${YELLOW}DB_HOST${NC} = $DB_PRIVATE_IP" 
echo "   ${YELLOW}DB_PORT${NC} = 5432" 
echo "   ${YELLOW}DB_NAME${NC} = $DB_NAME" 
echo "   ${YELLOW}DB_USER${NC} = $DB_USER" 
echo "   ${YELLOW}DB_PASSWORD${NC} = $DB_PASSWORD" 
echo ""
echo "=========================================="
echo ""
echo "To delete everything later, run:"
echo "   ${RED}./azure-teardown.sh${NC}"
echo ""

pause_on_exit