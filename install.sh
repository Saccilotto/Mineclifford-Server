#!/bin/bash
# Mineclifford Installation Script
# Installs all dependencies and sets up the environment

set -e

echo "=================================="
echo "Mineclifford Installation Script"
echo "=================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check Python version
echo "Checking Python version..."
PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}')
REQUIRED_VERSION="3.8"

if [ "$(printf '%s\n' "$REQUIRED_VERSION" "$PYTHON_VERSION" | sort -V | head -n1)" != "$REQUIRED_VERSION" ]; then
    echo -e "${RED}Error: Python 3.8+ required. Found: $PYTHON_VERSION${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Python $PYTHON_VERSION${NC}"

# Check Terraform
echo ""
echo "Checking Terraform..."
if ! command -v terraform &> /dev/null; then
    echo -e "${YELLOW}! Terraform not found. Installing...${NC}"

    # Detect OS
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        wget https://releases.hashicorp.com/terraform/1.10.3/terraform_1.10.3_linux_amd64.zip
        unzip terraform_1.10.3_linux_amd64.zip
        sudo mv terraform /usr/local/bin/
        rm terraform_1.10.3_linux_amd64.zip
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        brew install terraform
    else
        echo -e "${RED}Please install Terraform manually: https://www.terraform.io/downloads${NC}"
        exit 1
    fi
fi

TERRAFORM_VERSION=$(terraform version -json | grep -o '"version":"[^"]*' | cut -d'"' -f4)
echo -e "${GREEN}✓ Terraform $TERRAFORM_VERSION${NC}"

# Check Ansible
echo ""
echo "Checking Ansible..."
if ! command -v ansible &> /dev/null; then
    echo -e "${YELLOW}! Ansible not found. Installing...${NC}"
    pip3 install ansible
fi

ANSIBLE_VERSION=$(ansible --version | head -n1 | awk '{print $3}' | tr -d ']')
echo -e "${GREEN}✓ Ansible $ANSIBLE_VERSION${NC}"

# Install Python dependencies
echo ""
echo "Installing Python dependencies..."
pip3 install -r requirements.txt
echo -e "${GREEN}✓ Python dependencies installed${NC}"

# Install Ansible collections
echo ""
echo "Installing Ansible collections..."
ansible-galaxy collection install -r deployment/ansible/requirements.yml
echo -e "${GREEN}✓ Ansible collections installed${NC}"

# Install Mineclifford Version Manager
echo ""
echo "Installing Mineclifford Version Manager..."
pip3 install -e .
echo -e "${GREEN}✓ Version Manager installed${NC}"

# Verify installation
echo ""
echo "Verifying installation..."
if command -v mineclifford-version &> /dev/null; then
    echo -e "${GREEN}✓ CLI tool available${NC}"
else
    echo -e "${RED}✗ CLI tool not available. Try adding ~/.local/bin to PATH${NC}"
fi

# Check cloud CLI tools (optional)
echo ""
echo "Checking cloud CLI tools (optional)..."

if command -v aws &> /dev/null; then
    AWS_VERSION=$(aws --version 2>&1 | awk '{print $1}' | cut -d'/' -f2)
    echo -e "${GREEN}✓ AWS CLI $AWS_VERSION${NC}"
else
    echo -e "${YELLOW}! AWS CLI not found (optional for AWS deployments)${NC}"
fi

if command -v az &> /dev/null; then
    AZURE_VERSION=$(az version --output json | grep -o '"azure-cli": "[^"]*' | cut -d'"' -f4)
    echo -e "${GREEN}✓ Azure CLI $AZURE_VERSION${NC}"
else
    echo -e "${YELLOW}! Azure CLI not found (optional for Azure deployments)${NC}"
fi

# Create directory for generated files
echo ""
echo "Setting up directories..."
mkdir -p generated/ansible
mkdir -p generated/terraform
echo -e "${GREEN}✓ Directories created${NC}"

# Final message
echo ""
echo "=================================="
echo -e "${GREEN}Installation complete!${NC}"
echo "=================================="
echo ""
echo "Next steps:"
echo "  1. Configure cloud credentials:"
echo "     - AWS: aws configure"
echo "     - Azure: az login"
echo ""
echo "  2. Test Version Manager:"
echo "     mineclifford-version types"
echo "     mineclifford-version latest paper"
echo ""
echo "  3. Generate Ansible variables:"
echo "     python3 src/ansible_integration.py generate \\"
echo "       --java-type paper \\"
echo "       -o deployment/ansible/minecraft_vars.yml"
echo ""
echo "  4. Deploy your server:"
echo "     ./minecraft-ops.sh deploy --provider aws --orchestration swarm"
echo ""
echo "For more information, see: docs/version-manager.md"
