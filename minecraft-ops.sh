#!/bin/bash
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
ACTION="deploy"                # deploy, destroy, status
PROVIDER="aws"                 # aws, azure
ORCHESTRATION="swarm"          # swarm, kubernetes, compose (local is alias)
SKIP_TERRAFORM=false
INTERACTIVE=true
DEPLOYMENT_LOG="minecraft_ops_$(date +%Y%m%d_%H%M%S).log"
ROLLBACK_ENABLED=true
MINECRAFT_VERSION="1.21.11"
MINECRAFT_MODE="survival"
MINECRAFT_DIFFICULTY="normal"
USE_BEDROCK=false
NAMESPACE="mineclifford"
KUBERNETES_PROVIDER="eks"      # eks, aks
MEMORY="2G"
FORCE_CLEANUP=false
SAVE_STATE=true
STORAGE_TYPE="github"          # s3, azure, github
SERVER_NAMES=("instance1")     # Default server names
SINGLE_NODE_SWARM=true         # Default to single-node swarm
WORLD_IMPORT=""
PROJECT_NAME="mineclifford"
ENVIRONMENT="production"        # production, staging, development, test
OWNER="minecraft"
AWS_REGION="sa-east-1"
AZURE_LOCATION="East US 2"
INSTANCE_TYPE=""                # auto-set per provider if empty
DISK_SIZE_GB=30
REGION_OVERRIDE=""

# Mod support
SERVER_TYPE="VANILLA"             # VANILLA, FORGE, FABRIC, NEOFORGE, PAPER
MODRINTH_PROJECTS=""              # Comma-separated Modrinth project slugs (e.g. "create-fabric,fabric-api")
MODRINTH_DOWNLOAD_DEPS="required" # none, required, optional
MOD_LOADER_VERSION=""             # Specific loader version (empty = latest)

# Shared gameplay/runtime defaults (used across compose, swarm, and kubernetes)
MINECRAFT_MAX_PLAYERS=15
MINECRAFT_ONLINE_MODE="FALSE"
MINECRAFT_ALLOW_NETHER=true
MINECRAFT_ENABLE_COMMAND_BLOCK=false
MINECRAFT_SPAWN_PROTECTION=0
MINECRAFT_VIEW_DISTANCE=8
MINECRAFT_SIMULATION_DISTANCE=6
TIMEZONE="America/Sao_Paulo"
MINECRAFT_JAVA_MOTD=""
MINECRAFT_BEDROCK_SERVER_NAME=""
MINECRAFT_BEDROCK_LEVEL_NAME=""

# Create log file
touch $DEPLOYMENT_LOG
exec > >(tee -a $DEPLOYMENT_LOG)
exec 2>&1

# Export environment variables for Ansible and Python
export ANSIBLE_FORCE_COLOR=true
export PYTHONIOENCODING=utf-8
export ANSIBLE_HOST_KEY_CHECKING=False

# Load environment variables from .env if it exists
if [[ -f ".env" ]]; then
    echo -e "${YELLOW}Loading environment variables from .env file...${NC}"
    set -o allexport
    source .env
    set +o allexport
    
else
    echo -e "${YELLOW}No .env file found. Using default values.${NC}"
fi

SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

echo "==========================================="
echo "Mineclifford Operations - $(date)"
echo "==========================================="

# Function to show help
function show_help {
    echo -e "${BLUE}Usage: $0 [ACTION] [OPTIONS]${NC}"
    echo -e "${YELLOW}Actions:${NC}"
    echo -e "  deploy                          Deploy Minecraft infrastructure (default)"
    echo -e "  destroy                         Destroy Minecraft infrastructure"
    echo -e "  status                          Check status of deployed infrastructure"
    echo -e "  save-state                      Save Terraform state"
    echo -e "  load-state                      Load Terraform state"
    echo -e "  backup                          Backup Minecraft worlds"
    echo -e "  restore                         Restore Minecraft worlds from backup"
    echo -e "${YELLOW}Options:${NC}"
    echo -e "  -p, --provider <aws|azure>      Specify the cloud provider (default: aws)"
    echo -e "  -o, --orchestration <swarm|kubernetes|compose|local>"
    echo -e "                                  Orchestration method (default: swarm)"
    echo -e "  -s, --skip-terraform            Skip Terraform provisioning"
    echo -e "  -v, --minecraft-version VERSION Specify Minecraft version (default: latest)"
    echo -e "  -m, --mode <survival|creative>  Game mode (default: survival)"
    echo -e "  -d, --difficulty <peaceful|easy|normal|hard>"
    echo -e "                                  Game difficulty (default: normal)"
    echo -e "  --bedrock                       Enable Bedrock Edition deployment"
    echo -e "  -b, --no-bedrock                Disable Bedrock Edition deployment"
    echo -e "  -w, --world-import FILE         Import world from zip file"
    echo -e "  -k, --k8s <eks|aks>             Kubernetes provider (default: eks)" 
    echo -e "  -n, --namespace NAMESPACE       Kubernetes namespace (default: mineclifford)"
    echo -e "  -mem, --memory MEMORY           Memory allocation for Java Edition (default: 2G)"
    echo -e "  -sn, --server-names NAMES       Comma-separated list of server names (default: instance1)"
    echo -e "  -f, --force                     Force cleanup during destroy"
    echo -e "  --no-interactive                Run in non-interactive mode"
    echo -e "  --no-rollback                   Disable rollback on failure"
    echo -e "  --no-save-state                 Don't save Terraform state"
    echo -e "  --storage-type <s3|azure|github> State storage type (default: github)"
    echo -e "  --project-name NAME             Project name for resource naming/tagging (default: mineclifford)"
    echo -e "  --environment ENV               Environment tag: production|staging|development|test (default: production)"
    echo -e "  --owner OWNER                   Owner tag for resources (default: minecraft)"
    echo -e "  --region REGION                 Cloud region (provider-aware, default: sa-east-1 / East US 2)"
    echo -e "  --instance-type TYPE            VM/instance type (provider-aware)"
    echo -e "  --disk-size GB                  Disk size in GB (default: 30)"
    echo -e ""
    echo -e "${YELLOW}Mod Support:${NC}"
    echo -e "  --server-type TYPE              Server type: VANILLA|FORGE|FABRIC|NEOFORGE|PAPER (default: VANILLA)"
    echo -e "  --mods PROJECTS                 Comma-separated Modrinth project slugs (e.g. create-fabric,fabric-api)"
    echo -e "  --mod-deps <none|required|optional>"
    echo -e "                                  Auto-download mod dependencies (default: required)"
    echo -e "  --mod-loader-version VERSION    Specific mod loader version (default: latest)"
    echo -e "  -h, --help                      Show this help message"
    echo -e "${YELLOW}Examples:${NC}"
    echo -e "  $0 deploy --provider aws --orchestration swarm"
    echo -e "  $0 deploy --provider azure --orchestration kubernetes --k8s aks"
    echo -e "  $0 destroy --provider aws --orchestration swarm --force"
    echo -e "  $0 deploy --orchestration compose --skip-terraform"
    echo -e "  $0 deploy --orchestration local --minecraft-version 1.19"
    echo -e "  $0 backup --provider aws --orchestration swarm"
    echo -e ""
    echo -e "${YELLOW}Mod Examples:${NC}"
    echo -e "  $0 deploy --orchestration compose --skip-terraform --server-type FABRIC --mods 'create-fabric,fabric-api' --minecraft-version 1.20.1"
    echo -e "  $0 deploy --provider aws --orchestration swarm --server-type FORGE --mods 'create' --minecraft-version 1.20.1"
    exit 0
}

function initialize_runtime_config {
    MINECRAFT_JAVA_MOTD="${PROJECT_NAME} Java Server"
    MINECRAFT_BEDROCK_SERVER_NAME="${PROJECT_NAME} Bedrock Server"
    MINECRAFT_BEDROCK_LEVEL_NAME="$PROJECT_NAME"
}

# Function for error handling
function handle_error {
    local exit_code=$?
    local error_message=$1
    local step=$2
    
    echo -e "${RED}ERROR: $error_message (Exit Code: $exit_code)${NC}" 
    echo -e "${RED}Operation failed during step: $step${NC}"
    
    if [[ "$ROLLBACK_ENABLED" == "true" && "$step" != "pre-operation" ]]; then
        echo -e "${YELLOW}Initiating rollback procedure...${NC}"
        
        case "$step" in
            "terraform")
                echo -e "${YELLOW}Rolling back infrastructure changes...${NC}"
                local tf_rollback_dir=""
                if [[ "$PROVIDER" == "aws" ]]; then
                    tf_rollback_dir="$SCRIPT_DIR/terraform/aws"
                    if [[ "$ORCHESTRATION" == "kubernetes" ]]; then
                        tf_rollback_dir="$tf_rollback_dir/kubernetes"
                    fi
                elif [[ "$PROVIDER" == "azure" ]]; then
                    tf_rollback_dir="$SCRIPT_DIR/terraform/azure"
                    if [[ "$ORCHESTRATION" == "kubernetes" ]]; then
                        tf_rollback_dir="$tf_rollback_dir/kubernetes"
                    fi
                fi
                (cd "$tf_rollback_dir" && terraform destroy -auto-approve)
                ;;
            "ansible"|"swarm")
                if [[ -f "static_ip.ini" ]]; then
                    echo -e "${YELLOW}Attempting to remove Docker stack...${NC}"
                    # Get manager node from inventory
                    MANAGER_IP=$(grep -A1 '\[instance1\]' static_ip.ini | tail -n1 | awk '{print $1}')
                    if [[ -n "$MANAGER_IP" ]]; then
                        echo -e "${YELLOW}Connecting to manager node $MANAGER_IP...${NC}"
                        ssh $SSH_OPTS -i ssh_keys/instance1.pem ubuntu@$MANAGER_IP "docker stack rm Mineclifford" || true
                    fi
                fi
                ;;
            "kubernetes")
                if [[ -n "$NAMESPACE" ]]; then
                    echo -e "${YELLOW}Removing Kubernetes deployments from namespace $NAMESPACE...${NC}"
                    kubectl delete namespace $NAMESPACE || true
                fi
                ;;
            "compose")
                echo -e "${YELLOW}Stopping and removing local Docker containers...${NC}"
                docker compose down -v || true
                ;;
        esac
    fi
    
    echo -e "${YELLOW}See log file for details: $DEPLOYMENT_LOG${NC}"
    exit 1
}

# Pre-operation validation
function validate_environment {
    echo -e "${BLUE}Validating environment...${NC}"
    
    # Check required tools for all operations except fully local compose mode
    if [[ ! ( "$ORCHESTRATION" == "compose" && "$SKIP_TERRAFORM" == "true" ) ]]; then
        for cmd in terraform jq; do
            if ! command -v $cmd &> /dev/null; then
                echo -e "${RED}Error: Required tool '$cmd' is not installed.${NC}"
                handle_error "Missing required tool: $cmd" "pre-operation"
            fi
        done
    fi
    
    # Check orchestration-specific tools
    if [[ "$ORCHESTRATION" == "swarm" ]]; then
        if ! command -v ansible-playbook &> /dev/null; then
            echo -e "${RED}Error: Required tool 'ansible-playbook' is not installed.${NC}"
            handle_error "Missing required tool: ansible-playbook" "pre-operation"
        fi
    elif [[ "$ORCHESTRATION" == "kubernetes" ]]; then
        if ! command -v kubectl &> /dev/null; then
            echo -e "${RED}Error: Required tool 'kubectl' is not installed.${NC}"
            handle_error "Missing required tool: kubectl" "pre-operation"
        fi
    elif [[ "$ORCHESTRATION" == "compose" ]]; then
        if [[ "$SKIP_TERRAFORM" == "true" ]]; then
            if ! command -v docker &> /dev/null; then
                echo -e "${RED}Error: Required tool 'docker' is not installed.${NC}"
                handle_error "Missing required tool: docker" "pre-operation"
            fi
            if ! docker compose version &> /dev/null; then
                echo -e "${RED}Error: Required tool 'docker compose' (Docker Compose V2 plugin) is not installed.${NC}"
                handle_error "Missing required tool: docker compose" "pre-operation"
            fi
        else
            if ! command -v ansible-playbook &> /dev/null; then
                echo -e "${RED}Error: Required tool 'ansible-playbook' is not installed.${NC}"
                handle_error "Missing required tool: ansible-playbook" "pre-operation"
            fi
        fi
    fi
    
    # For compose + --skip-terraform, run purely local and skip cloud credential checks.
    if [[ "$ORCHESTRATION" == "compose" && "$SKIP_TERRAFORM" == "true" ]]; then
        echo -e "${YELLOW}Compose local mode detected (no Terraform). Skipping cloud credential checks.${NC}"
    # Check provider-specific tools
    elif [[ "$PROVIDER" == "aws" ]]; then
        if ! command -v aws &> /dev/null; then
            echo -e "${RED}Error: AWS CLI is not installed.${NC}"
            handle_error "Missing required tool: aws" "pre-operation"
        fi
        
        echo -e "${YELLOW}Validating AWS credentials...${NC}"
        if ! aws sts get-caller-identity &> /dev/null; then
            handle_error "Invalid AWS credentials" "pre-operation"
        fi
        
        if [[ "$ORCHESTRATION" == "kubernetes" && "$KUBERNETES_PROVIDER" == "eks" ]]; then
            if ! command -v eksctl &> /dev/null; then
                echo -e "${RED}Error: eksctl is not installed.${NC}"
                handle_error "Missing required tool: eksctl" "pre-operation"
            fi
        fi
    elif [[ "$PROVIDER" == "azure" ]]; then
        if ! command -v az &> /dev/null; then
            echo -e "${RED}Error: Azure CLI is not installed.${NC}"
            handle_error "Missing required tool: az" "pre-operation"
        fi
        
        echo -e "${YELLOW}Validating Azure credentials...${NC}"
        if ! az account show &> /dev/null; then
            handle_error "Invalid Azure credentials" "pre-operation"
        fi
    fi

    # Validate parameters
    if [[ "$ACTION" == "deploy" ]]; then
        if [[ ! "$MINECRAFT_MODE" =~ ^(survival|creative|adventure|spectator)$ ]]; then
            handle_error "Invalid game mode. Must be one of: survival, creative, adventure, spectator" "pre-operation"
        fi

        if [[ ! "$MINECRAFT_DIFFICULTY" =~ ^(peaceful|easy|normal|hard)$ ]]; then
            handle_error "Invalid difficulty. Must be one of: peaceful, easy, normal, hard" "pre-operation"
        fi
    fi

    if [[ -z "$PROJECT_NAME" ]]; then
        handle_error "Project name cannot be empty" "pre-operation"
    fi

    if [[ ! "$ENVIRONMENT" =~ ^(production|staging|development|test)$ ]]; then
        handle_error "Invalid environment. Must be one of: production, staging, development, test" "pre-operation"
    fi

    if [[ ! "$PROVIDER" =~ ^(aws|azure)$ ]]; then
        handle_error "Invalid provider. Must be 'aws' or 'azure'" "pre-operation"
    fi

    if [[ ! "$ORCHESTRATION" =~ ^(swarm|kubernetes|compose)$ ]]; then
        handle_error "Invalid orchestration. Must be 'swarm', 'kubernetes', or 'compose' (or alias 'local')" "pre-operation"
    fi

    if [[ "$ORCHESTRATION" == "kubernetes" && ! "$KUBERNETES_PROVIDER" =~ ^(eks|aks)$ ]]; then
        handle_error "Invalid Kubernetes provider. Must be 'eks' or 'aks'" "pre-operation"
    fi

    echo -e "${GREEN}Environment validation passed.${NC}"
}

# Function to save Terraform state
function save_terraform_state {
    if [[ "$SAVE_STATE" != "true" ]]; then
        echo -e "${YELLOW}Skipping state saving as requested.${NC}"
        return
    fi
    
    echo -e "${BLUE}Saving Terraform state...${NC}"
    
    local tf_dir=""
    if [[ "$PROVIDER" == "aws" ]]; then
        tf_dir="terraform/aws"
        if [[ "$ORCHESTRATION" == "kubernetes" ]]; then
            tf_dir="${tf_dir}/kubernetes"
        fi
    elif [[ "$PROVIDER" == "azure" ]]; then
        tf_dir="terraform/azure"
        if [[ "$ORCHESTRATION" == "kubernetes" ]]; then
            tf_dir="${tf_dir}/kubernetes"
        fi
    fi
    
    if $SCRIPT_DIR/scripts/save-terraform-state.sh --provider "$PROVIDER" --action save --orchestration "$ORCHESTRATION" --storage "$STORAGE_TYPE"; then
        echo -e "${GREEN}Terraform state saved successfully.${NC}"
    else
        echo -e "${YELLOW}Could not save Terraform state to remote storage. Continuing with local state.${NC}"
        return 1
    fi
}

# Function to load Terraform state
function load_terraform_state {
    echo -e "${BLUE}Loading Terraform state...${NC}"

    if $SCRIPT_DIR/scripts/save-terraform-state.sh --provider "$PROVIDER" --action load --orchestration "$ORCHESTRATION" --storage "$STORAGE_TYPE"; then
        echo -e "${GREEN}Terraform state loaded successfully.${NC}"
    else
        echo -e "${YELLOW}No remote Terraform state available (or failed to load). Using local state.${NC}"
        return 1
    fi
}

# Export Terraform variables from script settings
function export_terraform_vars {
    echo -e "${YELLOW}Exporting Terraform variables...${NC}"

    # Resolve instance type defaults per provider
    local resolved_instance_type="$INSTANCE_TYPE"
    if [[ -z "$resolved_instance_type" ]]; then
        if [[ "$PROVIDER" == "aws" ]]; then
            resolved_instance_type="t3.medium"
        elif [[ "$PROVIDER" == "azure" ]]; then
            resolved_instance_type="Standard_B2s"
        fi
    fi

    # Apply region override to the correct provider
    if [[ -n "$REGION_OVERRIDE" ]]; then
        if [[ "$PROVIDER" == "aws" ]]; then
            AWS_REGION="$REGION_OVERRIDE"
        elif [[ "$PROVIDER" == "azure" ]]; then
            AZURE_LOCATION="$REGION_OVERRIDE"
        fi
    fi

    # Universal variables
    export TF_VAR_server_names="$(printf '%s\n' "${SERVER_NAMES[@]}" | jq -R . | jq -cs .)"

    # Provider-specific variables
    if [[ "$PROVIDER" == "aws" ]]; then
        export TF_VAR_project_name="$PROJECT_NAME"
        export TF_VAR_region="$AWS_REGION"
        export TF_VAR_vpc_name="${PROJECT_NAME}-vpc"
        export TF_VAR_subnet_name="${PROJECT_NAME}-subnet"
        export TF_VAR_instance_type="$resolved_instance_type"

        if [[ "$ORCHESTRATION" == "kubernetes" ]]; then
            export TF_VAR_cluster_name="${PROJECT_NAME}-eks"
            export TF_VAR_node_instance_type="$resolved_instance_type"
            export TF_VAR_node_disk_size="$DISK_SIZE_GB"
            export TF_VAR_tags="{\"Project\":\"${PROJECT_NAME}\",\"Environment\":\"${ENVIRONMENT}\",\"ManagedBy\":\"terraform\",\"Owner\":\"${OWNER}\",\"Orchestration\":\"${ORCHESTRATION}\",\"ServerType\":\"${SERVER_TYPE}\"}"
        else
            export TF_VAR_environment="$ENVIRONMENT"
            export TF_VAR_owner="$OWNER"
            export TF_VAR_disk_size_gb="$DISK_SIZE_GB"
        fi
    elif [[ "$PROVIDER" == "azure" ]]; then
        export TF_VAR_resource_group_name="$PROJECT_NAME"
        export TF_VAR_location="$AZURE_LOCATION"
        export TF_VAR_vnet_name="${PROJECT_NAME}-vnet"
        export TF_VAR_instance_type="$resolved_instance_type"
        export TF_VAR_azure_subscription_id="${AZURE_SUBSCRIPTION_ID:-}"

        if [[ "$ORCHESTRATION" == "kubernetes" ]]; then
            export TF_VAR_prefix="$PROJECT_NAME"
            export TF_VAR_vm_size="$resolved_instance_type"
            export TF_VAR_os_disk_size_gb="$DISK_SIZE_GB"
            export TF_VAR_tags="{\"Project\":\"${PROJECT_NAME}\",\"Environment\":\"${ENVIRONMENT}\",\"ManagedBy\":\"terraform\",\"Owner\":\"${OWNER}\",\"Orchestration\":\"${ORCHESTRATION}\",\"ServerType\":\"${SERVER_TYPE}\"}"
        else
            export TF_VAR_environment="$ENVIRONMENT"
            export TF_VAR_owner="$OWNER"
            export TF_VAR_disk_size_gb="$DISK_SIZE_GB"
        fi
    fi
}

# Run Terraform with error handling
function run_terraform {
    if [[ "$SKIP_TERRAFORM" == "true" ]]; then
        echo -e "${YELLOW}Skipping Terraform provisioning as requested.${NC}"
        return
    fi

    export_terraform_vars

    echo -e "${BLUE}Running Terraform for $PROVIDER...${NC}"
    
    # Determine the directory
    local tf_dir=""
    if [[ "$PROVIDER" == "aws" ]]; then
        tf_dir="terraform/aws"
        if [[ "$ORCHESTRATION" == "kubernetes" ]]; then
            tf_dir="${tf_dir}/kubernetes"
        fi
    elif [[ "$PROVIDER" == "azure" ]]; then
        tf_dir="terraform/azure"
        if [[ "$ORCHESTRATION" == "kubernetes" ]]; then
            tf_dir="${tf_dir}/kubernetes"
        fi
    fi
    
    # Check if directory exists
    if [[ ! -d "$tf_dir" ]]; then
        handle_error "Terraform directory $tf_dir does not exist" "terraform"
    fi
    
    cd "$tf_dir" || handle_error "Failed to change to directory $tf_dir" "terraform"
    
    echo -e "${YELLOW}Initializing Terraform...${NC}"
    terraform init || handle_error "Terraform initialization failed" "terraform"
    
    echo -e "${YELLOW}Planning Terraform changes...${NC}"
    terraform plan -out=tf.plan || handle_error "Terraform plan failed" "terraform"
    
    echo -e "${YELLOW}Applying Terraform changes...${NC}"
    terraform apply tf.plan || handle_error "Terraform apply failed" "terraform"

    # Extract outputs section in run_terraform function
    echo -e "${YELLOW}Extracting Terraform outputs...${NC}"
        
    if [[ "$ORCHESTRATION" == "kubernetes" ]]; then
        # For Kubernetes, extract cluster information instead of instance IPs
        if [[ "$PROVIDER" == "aws" ]]; then
            # Save cluster info from EKS
            terraform output -json cluster_name > ../../../cluster_info.json 2>/dev/null || echo '{"cluster_name":"eks-cluster"}' > ../../../cluster_info.json
        elif [[ "$PROVIDER" == "azure" ]]; then
            # Save cluster info from AKS
            terraform output -json kubernetes_cluster_name > ../../../cluster_info.json 2>/dev/null || echo '{"kubernetes_cluster_name":"aks-cluster"}' > ../../../cluster_info.json
        fi
    else
        # For non-Kubernetes deployments, extract instance IPs
        if [[ "$PROVIDER" == "aws" ]]; then
            # Save instance public IPs to a file
            terraform output -json instance_public_ips > ../../../instance_ips.json 2>/dev/null || echo '{}' > ../../../instance_ips.json
        elif [[ "$PROVIDER" == "azure" ]]; then
            # Save VM public IPs to a file
            terraform output -json vm_public_ips > ../../../instance_ips.json 2>/dev/null || echo '{}' > ../../../instance_ips.json
        fi
    fi
    
    cd - > /dev/null
    echo -e "${GREEN}Terraform execution completed successfully.${NC}"
    
    echo -e "${YELLOW}Waiting for instances to initialize (60 seconds)...${NC}"
    for i in {1..60}; do
        echo -n "."
        sleep 1
        if (( i % 10 == 0 )); then
            echo " $i seconds"
        fi
    done
    echo ""
}

# Load or generate persistent passwords for RCON/Grafana
function ensure_passwords {
    local pw_file="$SCRIPT_DIR/.rcon_password"
    if [[ -f "$pw_file" ]]; then
        source "$pw_file"
    fi
    if [[ -z "${RCON_PASSWORD:-}" ]]; then
        RCON_PASSWORD="$(openssl rand -base64 16)"
    fi
    if [[ -z "${GRAFANA_PASSWORD:-}" ]]; then
        GRAFANA_PASSWORD="$(openssl rand -base64 16)"
    fi
    # Cache for future runs
    cat > "$pw_file" << PWEOF
RCON_PASSWORD="$RCON_PASSWORD"
GRAFANA_PASSWORD="$GRAFANA_PASSWORD"
PWEOF
    chmod 600 "$pw_file"
}

# Run Ansible with error handling
function run_ansible {
    echo -e "${BLUE}Running Ansible playbooks for Minecraft...${NC}"

    # Verify inventory file exists
    if [[ ! -f "static_ip.ini" ]]; then
        handle_error "Inventory file static_ip.ini not found" "ansible"
    fi
    
    # Set proper permissions for SSH keys
    echo -e "${YELLOW}Setting SSH key permissions...${NC}"
    chmod 400 ssh_keys/*.pem
    
    # Create vars file for Ansible with single_node_swarm info
    echo -e "${YELLOW}Creating Minecraft configuration vars...${NC}"
    cat > deployment/ansible/minecraft_vars.yml << EOF
---
# Minecraft Configuration Variables
minecraft_java_version: "$MINECRAFT_VERSION"
minecraft_java_type: "$SERVER_TYPE"
minecraft_java_memory: "$MEMORY"
minecraft_java_max_players: $MINECRAFT_MAX_PLAYERS
minecraft_java_online_mode: "$MINECRAFT_ONLINE_MODE"
minecraft_java_gamemode: "$MINECRAFT_MODE"
minecraft_java_difficulty: "$MINECRAFT_DIFFICULTY"
minecraft_java_motd: "$MINECRAFT_JAVA_MOTD"
minecraft_java_allow_nether: $MINECRAFT_ALLOW_NETHER
minecraft_java_enable_command_block: $MINECRAFT_ENABLE_COMMAND_BLOCK
minecraft_java_spawn_protection: $MINECRAFT_SPAWN_PROTECTION
minecraft_java_view_distance: $MINECRAFT_VIEW_DISTANCE
minecraft_java_simulation_distance: $MINECRAFT_SIMULATION_DISTANCE

# Bedrock Edition
minecraft_bedrock_enabled: $USE_BEDROCK
minecraft_bedrock_gamemode: "$MINECRAFT_MODE"
minecraft_bedrock_difficulty: "$MINECRAFT_DIFFICULTY"
minecraft_bedrock_server_name: "$MINECRAFT_BEDROCK_SERVER_NAME"
minecraft_bedrock_level_name: "$MINECRAFT_BEDROCK_LEVEL_NAME"

# Mod Support
minecraft_modrinth_projects: "$MODRINTH_PROJECTS"
minecraft_modrinth_download_deps: "$MODRINTH_DOWNLOAD_DEPS"
minecraft_mod_loader_version: "$MOD_LOADER_VERSION"

# Monitoring Configuration
rcon_password: "$RCON_PASSWORD"
grafana_password: "$GRAFANA_PASSWORD"
timezone: "$TIMEZONE"

# Server Names
server_names:
$(for name in "${SERVER_NAMES[@]}"; do echo "  - $name"; done)

# Swarm Configuration
single_node_swarm: $SINGLE_NODE_SWARM

# Docker orchestration mode
orchestration_mode: "$ORCHESTRATION"
compose_file_source: "$SCRIPT_DIR/docker-compose.generated.yml"
EOF
    
    # Append world import vars AFTER the heredoc so they are not overwritten.
    # Uses MINECRAFT_WORLD_IMPORT_TAR (the repacked tar.gz) not the raw zip,
    # and sets minecraft_world_import_dir explicitly so the stack.yml volume
    # mount has a reliable value rather than falling back to a default.
    if [[ "$MINECRAFT_WORLD_IMPORT_READY" == "true" && -f "$MINECRAFT_WORLD_IMPORT_TAR" ]]; then
        echo -e "${YELLOW}Adding world import to Ansible variables...${NC}"
        cat >> deployment/ansible/minecraft_vars.yml << EOF

# World import — Aternos backup
minecraft_world_import: "$MINECRAFT_WORLD_IMPORT_TAR"
minecraft_world_import_dir: "/tmp/minecraft-world-import"
EOF
    fi

    # Run Ansible playbook
    echo -e "${YELLOW}Deploying Minecraft infrastructure via Ansible...${NC}"
    cd deployment/ansible || handle_error "Failed to change to ansible directory" "ansible"
    
    # Test connectivity
    echo -e "${YELLOW}Testing connectivity to hosts...${NC}"
    ansible -i ../../static_ip.ini all -m ping || handle_error "Ansible connectivity test failed" "ansible"
    
    # Run main playbook
    echo -e "${YELLOW}Running Minecraft setup playbook...${NC}"
    if [[ "$ORCHESTRATION" == "swarm" || "$ORCHESTRATION" == "compose" ]]; then
        ansible-playbook -i ../../static_ip.ini swarm_setup.yml -e "@minecraft_vars.yml" ${ANSIBLE_EXTRA_VARS:+-e "$ANSIBLE_EXTRA_VARS"} || handle_error "Ansible playbook execution failed" "ansible"
    fi

    cd ../..
    
    # Final connectivity verification
    echo -e "${YELLOW}Verifying final deployment...${NC}"
    
    # Get manager node from inventory
    MANAGER_IP=$(grep -A1 '\[instance1\]' static_ip.ini | tail -n1 | awk '{print $1}')
    if [[ -n "$MANAGER_IP" ]]; then
        echo -e "${YELLOW}Checking services on manager node $MANAGER_IP...${NC}"
        if [[ "$ORCHESTRATION" == "compose" ]]; then
            ssh $SSH_OPTS -i ssh_keys/instance1.pem ubuntu@$MANAGER_IP "docker compose -f /home/ubuntu/mineclifford-compose/docker-compose.yml ps" || echo -e "${YELLOW}Unable to check services, may still be initializing...${NC}"
        else
            ssh $SSH_OPTS -i ssh_keys/instance1.pem ubuntu@$MANAGER_IP "docker service ls" || echo -e "${YELLOW}Unable to check services, may still be initializing...${NC}"
        fi
    fi
    
    echo -e "${GREEN}Ansible deployment completed successfully.${NC}"
}

function import_world {
    if [[ -z "$WORLD_IMPORT" || ! -f "$WORLD_IMPORT" ]]; then
        return
    fi
    
    echo -e "${BLUE}Importing Minecraft world from $WORLD_IMPORT...${NC}"
    
    # Extract to imports directory with timestamp
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    IMPORT_DIR="world_imports/$TIMESTAMP"
    mkdir -p "$IMPORT_DIR"
    
    # Unzip world file
    unzip "$WORLD_IMPORT" -d "$IMPORT_DIR"
    
    # Based on orchestration type, copy the world
    case "$ORCHESTRATION" in
        compose)
            # Set up for local import during docker compose
            export MINECRAFT_WORLD_DIR="$IMPORT_DIR"
            ;;
        swarm|kubernetes)
            # Create a special tarball for later use
            tar -czf "world_imports/world_import_$TIMESTAMP.tar.gz" -C "$IMPORT_DIR" .
            export MINECRAFT_WORLD_IMPORT_TAR="$(realpath "world_imports/world_import_$TIMESTAMP.tar.gz")"
            export MINECRAFT_WORLD_IMPORT_DIR="$(realpath "$IMPORT_DIR")"
            export MINECRAFT_WORLD_IMPORT_READY="true"
            ;;
    esac

    echo -e "${YELLOW}World imported successfully to $IMPORT_DIR.${NC}"
}

# Deploy to Kubernetes
function deploy_to_kubernetes {
    echo -e "${BLUE}Deploying Minecraft to Kubernetes...${NC}"
    
    # Setup kubectl context based on provider
    if [[ "$PROVIDER" == "aws" ]]; then
        echo -e "${YELLOW}Configuring kubectl for EKS...${NC}"
        # Get the cluster name from Terraform output
        CLUSTER_NAME=$(cd terraform/aws/kubernetes && terraform output -raw cluster_name)
        aws eks update-kubeconfig --name $CLUSTER_NAME --region $AWS_REGION || handle_error "Failed to configure kubectl for EKS" "kubernetes"
    elif [[ "$PROVIDER" == "azure" ]]; then
        echo -e "${YELLOW}Configuring kubectl for AKS...${NC}"
        # Get the resource group and cluster name from Terraform output
        RG_NAME=$(cd terraform/azure/kubernetes && terraform output -raw kubernetes_cluster_resource_group)
        CLUSTER_NAME=$(cd terraform/azure/kubernetes && terraform output -raw kubernetes_cluster_name)
        az aks get-credentials --resource-group $RG_NAME --name $CLUSTER_NAME || handle_error "Failed to configure kubectl for AKS" "kubernetes"
    fi
    
    # Create namespace if it doesn't exist
    if ! kubectl get namespace $NAMESPACE &> /dev/null; then
        kubectl create namespace $NAMESPACE || handle_error "Failed to create namespace" "kubernetes"
    else
        # Check if we're redeploying to an existing namespace
        echo -e "${YELLOW}Namespace $NAMESPACE already exists. Checking for existing resources...${NC}"
        if kubectl get deployments -n $NAMESPACE 2>/dev/null | grep -q "minecraft"; then
            echo -e "${YELLOW}Found existing Minecraft deployments in namespace. They will be replaced.${NC}"
            if [[ "$INTERACTIVE" == "true" ]]; then
                echo -e "${YELLOW}Continue? (yes/no)${NC}"
                read -r confirm
                if [[ "$confirm" != "yes" ]]; then
                    handle_error "Deployment cancelled by user" "kubernetes"
                fi
            fi
        fi
    fi
    
    # Handle world import if enabled
    if [[ "$MINECRAFT_WORLD_IMPORT_READY" == "true" && -f "$MINECRAFT_WORLD_IMPORT_TAR" ]]; then
        echo -e "${YELLOW}Setting up Kubernetes world import...${NC}"
        
        # Create ConfigMap to store import settings
        kubectl create configmap minecraft-world-import -n $NAMESPACE \
            --from-literal=IMPORT_ENABLED="true" \
            --dry-run=client -o yaml | kubectl apply -f -
            
        # Create an init container definition in a ConfigMap
        cat <<EOF | kubectl apply -n $NAMESPACE -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: minecraft-init-scripts
data:
  import-world.sh: |
    #!/bin/sh
    echo "Starting world import..."
    mkdir -p /data/world
    if [ -f /import-data/world.tar.gz ]; then
      echo "Extracting world data..."
      tar -xzf /import-data/world.tar.gz -C /data/world/
      echo "World data import complete"
    else
      echo "No world data found"
      exit 1
    fi
EOF

        # Create a temporary PVC for import data
        cat <<EOF | kubectl apply -n $NAMESPACE -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: minecraft-import-data
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
EOF

        # Create a temporary Pod to receive the import data
        cat <<EOF | kubectl apply -n $NAMESPACE -f -
apiVersion: v1
kind: Pod
metadata:
  name: import-data-receiver
spec:
  volumes:
  - name: import-data
    persistentVolumeClaim:
      claimName: minecraft-import-data
  containers:
  - name: receiver
    image: alpine:latest
    command: ["sh", "-c", "mkdir -p /import-data && sleep 3600"]
    volumeMounts:
    - mountPath: /import-data
      name: import-data
EOF

        # Wait for the pod to be ready
        echo -e "${YELLOW}Waiting for import pod to be ready...${NC}"
        kubectl wait --for=condition=ready pod/import-data-receiver -n $NAMESPACE --timeout=60s || handle_error "Import pod failed to start" "kubernetes"
        
        # Copy the world data to the pod
        echo -e "${YELLOW}Copying world data to Kubernetes...${NC}"
        kubectl cp "$MINECRAFT_WORLD_IMPORT_TAR" $NAMESPACE/import-data-receiver:/import-data/world.tar.gz || handle_error "Failed to copy world data" "kubernetes"
        
        # Modify the Minecraft deployment to use init container for importing
        echo -e "${YELLOW}Updating Minecraft deployment to use world import...${NC}"
        
        # Create a patch file for the Java deployment
        cat > /tmp/minecraft-java-patch.yaml << EOF
spec:
  template:
    spec:
      initContainers:
      - name: world-importer
        image: alpine:latest
        command: ["sh", "/scripts/import-world.sh"]
        volumeMounts:
        - name: minecraft-data
          mountPath: /data
        - name: import-data
          mountPath: /import-data
        - name: init-scripts
          mountPath: /scripts
      volumes:
      - name: minecraft-data
        persistentVolumeClaim:
          claimName: minecraft-java-pvc
      - name: import-data
        persistentVolumeClaim:
          claimName: minecraft-import-data
      - name: init-scripts
        configMap:
          name: minecraft-init-scripts
          defaultMode: 0755
EOF
    fi
    
    # Generate ConfigMap with game settings from script variables
    echo -e "${YELLOW}Generating Kubernetes ConfigMaps from script variables...${NC}"

    # Build mod-related ConfigMap literals
    local mod_literals=""
    if [[ -n "$MODRINTH_PROJECTS" ]]; then
        mod_literals="$mod_literals --from-literal=MODRINTH_PROJECTS=$MODRINTH_PROJECTS"
        mod_literals="$mod_literals --from-literal=MODRINTH_DOWNLOAD_DEPENDENCIES=$MODRINTH_DOWNLOAD_DEPS"
    fi
    if [[ -n "$MOD_LOADER_VERSION" ]]; then
        case "$SERVER_TYPE" in
            FABRIC)  mod_literals="$mod_literals --from-literal=FABRIC_LOADER_VERSION=$MOD_LOADER_VERSION" ;;
            FORGE)   mod_literals="$mod_literals --from-literal=FORGE_VERSION=$MOD_LOADER_VERSION" ;;
            NEOFORGE) mod_literals="$mod_literals --from-literal=NEOFORGE_VERSION=$MOD_LOADER_VERSION" ;;
        esac
    fi

    kubectl create configmap minecraft-config -n $NAMESPACE \
        --from-literal=EULA=TRUE \
        --from-literal=VERSION="$MINECRAFT_VERSION" \
        --from-literal=TYPE="$SERVER_TYPE" \
        --from-literal=MEMORY="$MEMORY" \
        --from-literal=DIFFICULTY="$MINECRAFT_DIFFICULTY" \
        --from-literal=MODE="$MINECRAFT_MODE" \
        --from-literal=MOTD="$MINECRAFT_JAVA_MOTD" \
        --from-literal=MAX_PLAYERS=$MINECRAFT_MAX_PLAYERS \
        --from-literal=ONLINE_MODE=$MINECRAFT_ONLINE_MODE \
        --from-literal=ENABLE_RCON=true \
        --from-literal=RCON_PASSWORD="${RCON_PASSWORD:-minecraft}" \
        --from-literal=ALLOW_NETHER=$MINECRAFT_ALLOW_NETHER \
        --from-literal=ENABLE_COMMAND_BLOCK=$MINECRAFT_ENABLE_COMMAND_BLOCK \
        --from-literal=SPAWN_PROTECTION=$MINECRAFT_SPAWN_PROTECTION \
        --from-literal=VIEW_DISTANCE=$MINECRAFT_VIEW_DISTANCE \
        --from-literal=SIMULATION_DISTANCE=$MINECRAFT_SIMULATION_DISTANCE \
        --from-literal=TZ=$TIMEZONE \
        $mod_literals \
        --dry-run=client -o yaml | kubectl apply -f - || handle_error "Failed to create minecraft-config ConfigMap" "kubernetes"

    if [[ "$USE_BEDROCK" == "true" ]]; then
        kubectl create configmap minecraft-bedrock-config -n $NAMESPACE \
            --from-literal=EULA=TRUE \
            --from-literal=GAMEMODE="$MINECRAFT_MODE" \
            --from-literal=DIFFICULTY="$MINECRAFT_DIFFICULTY" \
            --from-literal=SERVER_NAME="$MINECRAFT_BEDROCK_SERVER_NAME" \
            --from-literal=LEVEL_NAME="$MINECRAFT_BEDROCK_LEVEL_NAME" \
            --from-literal=ALLOW_CHEATS=false \
            --from-literal=TZ=$TIMEZONE \
            --dry-run=client -o yaml | kubectl apply -f - || handle_error "Failed to create minecraft-bedrock-config ConfigMap" "kubernetes"
    fi

    # Apply base manifests
    echo -e "${YELLOW}Applying Kubernetes deployments...${NC}"
    kubectl apply -f deployment/kubernetes/base/volume-claims.yaml -n $NAMESPACE || handle_error "Failed to apply volume claims" "kubernetes"
    kubectl apply -f deployment/kubernetes/base/minecraft-java-deployment.yaml -n $NAMESPACE || handle_error "Failed to deploy Minecraft Java" "kubernetes"
    kubectl apply -f deployment/kubernetes/base/rcon-web-admin-deployment.yaml -n $NAMESPACE || handle_error "Failed to deploy RCON Web Admin" "kubernetes"
    kubectl apply -f deployment/kubernetes/base/auto-updater.yaml -n $NAMESPACE || handle_error "Failed to deploy auto-updater" "kubernetes"

    if [[ "$USE_BEDROCK" == "true" ]]; then
        kubectl apply -f deployment/kubernetes/base/minecraft-bedrock-deployment.yaml -n $NAMESPACE || handle_error "Failed to deploy Minecraft Bedrock" "kubernetes"
    fi

    # Apply provider-specific patches
    if [[ "$PROVIDER" == "aws" ]]; then
        echo -e "${YELLOW}Applying AWS-specific patches...${NC}"
        kubectl apply -f deployment/kubernetes/aws/patches/storage-aws.yaml -n $NAMESPACE 2>/dev/null || true
        kubectl apply -f deployment/kubernetes/aws/patches/services-aws.yaml -n $NAMESPACE 2>/dev/null || true
    elif [[ "$PROVIDER" == "azure" ]]; then
        echo -e "${YELLOW}Applying Azure-specific patches...${NC}"
        kubectl apply -f deployment/kubernetes/azure/patches/services-azure.yaml -n $NAMESPACE 2>/dev/null || true
    fi
    
    # Apply the patch for world import if needed
    if [[ "$MINECRAFT_WORLD_IMPORT_READY" == "true" && -f "$MINECRAFT_WORLD_IMPORT_TAR" ]]; then
        kubectl patch deployment minecraft-java -n $NAMESPACE --patch "$(cat /tmp/minecraft-java-patch.yaml)" || handle_error "Failed to patch deployment for world import" "kubernetes"
        
        # Delete the temporary pod once the deployment is updated
        kubectl delete pod import-data-receiver -n $NAMESPACE
    fi
    
    # Wait for deployments to be ready
    echo -e "${YELLOW}Waiting for deployments to be ready...${NC}"
    kubectl rollout status deployment/minecraft-java -n $NAMESPACE --timeout=300s || echo -e "${YELLOW}Minecraft Java deployment still in progress...${NC}"
    kubectl rollout status deployment/rcon-web-admin -n $NAMESPACE --timeout=300s || echo -e "${YELLOW}RCON Web Admin deployment still in progress...${NC}"
    
    if [[ "$USE_BEDROCK" == "true" ]]; then
        kubectl rollout status deployment/minecraft-bedrock -n $NAMESPACE --timeout=300s || echo -e "${YELLOW}Minecraft Bedrock deployment still in progress...${NC}"
    fi

    # Get service information for connecting
    echo -e "${YELLOW}Getting service information...${NC}"
    kubectl get services -n $NAMESPACE
    
    echo -e "${GREEN}Minecraft deployed to Kubernetes successfully.${NC}"
}

function generate_docker_compose_file {
        local compose_file="$1"
        local data_prefix="$2"

        cat > "$compose_file" << EOF
version: '3.8'

services:
    # Java Edition Minecraft Server
    minecraft-java:
        image: itzg/minecraft-server:latest
        container_name: minecraft-java
        environment:
            - EULA=TRUE
            - VERSION=$MINECRAFT_VERSION
            - TYPE=$SERVER_TYPE
            - MEMORY=$MEMORY
            - DIFFICULTY=$MINECRAFT_DIFFICULTY
            - MODE=$MINECRAFT_MODE
            - MOTD=$MINECRAFT_JAVA_MOTD
            - MAX_PLAYERS=$MINECRAFT_MAX_PLAYERS
            - ONLINE_MODE=$MINECRAFT_ONLINE_MODE
            - ENABLE_RCON=true
            - RCON_PASSWORD=$RCON_PASSWORD
            - ALLOW_NETHER=$MINECRAFT_ALLOW_NETHER
            - ENABLE_COMMAND_BLOCK=$MINECRAFT_ENABLE_COMMAND_BLOCK
            - SPAWN_PROTECTION=$MINECRAFT_SPAWN_PROTECTION
            - VIEW_DISTANCE=$MINECRAFT_VIEW_DISTANCE
            - SIMULATION_DISTANCE=$MINECRAFT_SIMULATION_DISTANCE
            - JVM_XX_OPTS=-XX:+UseG1GC -XX:G1HeapRegionSize=4M -XX:+UnlockExperimentalVMOptions -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200
            - TZ=$TIMEZONE
EOF

        if [[ -n "$MODRINTH_PROJECTS" ]]; then
                cat >> "$compose_file" << EOF
            - MODRINTH_PROJECTS=$MODRINTH_PROJECTS
            - MODRINTH_DOWNLOAD_DEPENDENCIES=$MODRINTH_DOWNLOAD_DEPS
EOF
        fi

        if [[ -n "$MOD_LOADER_VERSION" ]]; then
                case "$SERVER_TYPE" in
                        FABRIC)
                                cat >> "$compose_file" << EOF
            - FABRIC_LOADER_VERSION=$MOD_LOADER_VERSION
EOF
                                ;;
                        FORGE)
                                cat >> "$compose_file" << EOF
            - FORGE_VERSION=$MOD_LOADER_VERSION
EOF
                                ;;
                        NEOFORGE)
                                cat >> "$compose_file" << EOF
            - NEOFORGE_VERSION=$MOD_LOADER_VERSION
EOF
                                ;;
                esac
        fi

        if [[ "$MINECRAFT_WORLD_IMPORT_READY" == "true" && -d "$MINECRAFT_WORLD_IMPORT_DIR" ]]; then
                cat >> "$compose_file" << EOF
            - WORLD=/import_world/world.tar.gz
EOF
        fi

        cat >> "$compose_file" << EOF
        ports:
            - "25565:25565"
        volumes:
            - ${data_prefix}/minecraft-java:/data
        labels:
            - "com.centurylinklabs.watchtower.enable=true"
            - "com.centurylinklabs.watchtower.stop-signal=SIGTERM"
EOF

        if [[ "$MINECRAFT_WORLD_IMPORT_READY" == "true" && -d "$MINECRAFT_WORLD_IMPORT_DIR" ]]; then
                cat >> "$compose_file" << EOF
            - $MINECRAFT_WORLD_IMPORT_DIR:/import_world:ro
EOF
        fi

        cat >> "$compose_file" << EOF
        restart: unless-stopped
        networks:
            - minecraft_network
EOF

        if [[ "$USE_BEDROCK" == "true" ]]; then
            cat >> "$compose_file" << EOF

    # Bedrock Edition Minecraft Server
    minecraft-bedrock:
        image: itzg/minecraft-bedrock-server:latest
        container_name: minecraft-bedrock
        environment:
            - EULA=TRUE
            - GAMEMODE=$MINECRAFT_MODE
            - DIFFICULTY=$MINECRAFT_DIFFICULTY
            - SERVER_NAME=$MINECRAFT_BEDROCK_SERVER_NAME
            - LEVEL_NAME=$MINECRAFT_BEDROCK_LEVEL_NAME
            - ALLOW_CHEATS=false
            - TZ=$TIMEZONE
        ports:
            - "19132:19132/udp"
        volumes:
            - ${data_prefix}/minecraft-bedrock:/data
        labels:
            - "com.centurylinklabs.watchtower.enable=true"
            - "com.centurylinklabs.watchtower.stop-signal=SIGTERM"
        restart: unless-stopped
        networks:
            - minecraft_network
EOF
        fi

        cat >> "$compose_file" << EOF

    # RCON Web Admin
    rcon-web-admin:
        image: itzg/rcon:latest
        ports:
            - "127.0.0.1:4326:4326"
            - "127.0.0.1:4327:4327"
        volumes:
            - ${data_prefix}/rcon:/opt/rcon-web-admin/db
        environment:
            - RWA_PASSWORD=$RCON_PASSWORD
            - RWA_ADMIN=true
            - RWA_RCON_HOST=minecraft-java
            - RWA_RCON_PORT=25575
            - RWA_RCON_PASSWORD=$RCON_PASSWORD
        depends_on:
            - minecraft-java
        restart: unless-stopped
        networks:
            - minecraft_network

    # Watchtower auto-updater
    watchtower:
        image: containrrr/watchtower:latest
        volumes:
            - /var/run/docker.sock:/var/run/docker.sock
        environment:
            - WATCHTOWER_LABEL_ENABLE=true
            - WATCHTOWER_ROLLING_RESTART=true
            - WATCHTOWER_STOP_TIMEOUT=120s
            - WATCHTOWER_CLEANUP=true
            - WATCHTOWER_POLL_INTERVAL=86400
        restart: unless-stopped
        networks:
            - minecraft_network
EOF

        cat >> "$compose_file" << EOF

networks:
    minecraft_network:
        driver: bridge
EOF
}

function deploy_local_compose {
        echo -e "${BLUE}Deploying Minecraft locally with Docker Compose...${NC}"

        mkdir -p data/minecraft-java
    mkdir -p data/rcon
        if [[ "$USE_BEDROCK" == "true" ]]; then
                mkdir -p data/minecraft-bedrock
        fi

        echo -e "${YELLOW}Creating docker-compose.yml with:${NC}"
        echo -e "  Version: ${YELLOW}$MINECRAFT_VERSION${NC}"
        echo -e "  Server Type: ${YELLOW}$SERVER_TYPE${NC}"
        echo -e "  Game Mode: ${YELLOW}$MINECRAFT_MODE${NC}"
        echo -e "  Difficulty: ${YELLOW}$MINECRAFT_DIFFICULTY${NC}"
        echo -e "  Memory: ${YELLOW}$MEMORY${NC}"
        echo -e "  Bedrock Edition: ${YELLOW}$([[ "$USE_BEDROCK" == "true" ]] && echo "Enabled" || echo "Disabled")${NC}"
        if [[ -n "$MODRINTH_PROJECTS" ]]; then
                echo -e "  Mods (Modrinth): ${YELLOW}$MODRINTH_PROJECTS${NC}"
        fi

        generate_docker_compose_file "docker-compose.yml" "./data"

        echo -e "${YELLOW}Starting Minecraft servers...${NC}"
        docker compose -f docker-compose.yml up -d || handle_error "Failed to start Docker containers" "compose"

        echo -e "${YELLOW}Checking if services are running...${NC}"
        sleep 10
        docker compose -f docker-compose.yml ps || handle_error "Failed to check Docker container status" "compose"

        echo -e "${GREEN}Local deployment completed successfully.${NC}"
        echo -e "${YELLOW}Access Minecraft Java server at: localhost:25565${NC}"
        if [[ "$USE_BEDROCK" == "true" ]]; then
                echo -e "${YELLOW}Access Minecraft Bedrock server at: localhost:19132${NC}"
        fi
}

# Backup Minecraft worlds
function backup_worlds {
    echo -e "${BLUE}Backing up Minecraft worlds...${NC}"
    
    # Create backup directory if it doesn't exist
    local BACKUP_DIR="minecraft-backups"
    local TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    mkdir -p "$BACKUP_DIR"
    
if [[ "$ORCHESTRATION" == "compose" && "$SKIP_TERRAFORM" == "true" ]]; then
        # Back up local volumes
        echo -e "${YELLOW}Backing up local Minecraft Java world...${NC}"
        tar -czf "$BACKUP_DIR/minecraft_java_$TIMESTAMP.tar.gz" -C data/minecraft-java .
        
        if [[ "$USE_BEDROCK" == "true" ]]; then
            echo -e "${YELLOW}Backing up local Minecraft Bedrock world...${NC}"
            tar -czf "$BACKUP_DIR/minecraft_bedrock_$TIMESTAMP.tar.gz" -C data/minecraft-bedrock .
        fi
        
    elif [[ "$ORCHESTRATION" == "swarm" || ( "$ORCHESTRATION" == "compose" && "$SKIP_TERRAFORM" != "true" ) ]]; then
        # Backup remote Docker Swarm volumes
        if [[ ! -f "static_ip.ini" ]]; then
            handle_error "Inventory file static_ip.ini not found" "backup"
        fi
        
        # Get manager node from inventory
        MANAGER_IP=$(grep -A1 '\[instance1\]' static_ip.ini | tail -n1 | awk '{print $1}')
        
        if [[ -n "$MANAGER_IP" ]]; then
            echo -e "${YELLOW}Connecting to manager node $MANAGER_IP for backup...${NC}"
            
            # Run backup command on remote server
            ssh $SSH_OPTS -i ssh_keys/instance1.pem ubuntu@$MANAGER_IP "bash /home/ubuntu/backup-minecraft.sh" || handle_error "Remote backup failed" "backup"
            
            # Create local backup directory
            mkdir -p "$BACKUP_DIR/$TIMESTAMP"
            
            # Copy backups from remote server
            echo -e "${YELLOW}Downloading backups from remote server...${NC}"
            scp $SSH_OPTS -i ssh_keys/instance1.pem "ubuntu@$MANAGER_IP:/home/ubuntu/minecraft-backups/*.tar.gz" "$BACKUP_DIR/$TIMESTAMP/" || handle_error "Failed to download backups" "backup"
        else
            handle_error "Could not find manager IP in inventory" "backup"
        fi
        
    elif [[ "$ORCHESTRATION" == "kubernetes" ]]; then
        # Backup Kubernetes volumes
        echo -e "${YELLOW}Backing up Kubernetes volumes...${NC}"
        
        # Create backup script
        cat > /tmp/k8s-backup.sh << EOF
#!/bin/bash
# Get the Minecraft Java pod name
POD=\$(kubectl get pod -l app=minecraft-java -n $NAMESPACE -o jsonpath="{.items[0].metadata.name}")
echo "Backing up from pod: \$POD"

# Create backup directory
mkdir -p /tmp/minecraft-backup
cd /tmp/minecraft-backup

# Backup Java world
kubectl exec -n $NAMESPACE \$POD -- tar -cz -C /data . > minecraft_java_$TIMESTAMP.tar.gz

# Backup Bedrock world if enabled
if kubectl get pod -l app=minecraft-bedrock -n $NAMESPACE &>/dev/null; then
    BEDROCK_POD=\$(kubectl get pod -l app=minecraft-bedrock -n $NAMESPACE -o jsonpath="{.items[0].metadata.name}")
    kubectl exec -n $NAMESPACE \$BEDROCK_POD -- tar -cz -C /data . > minecraft_bedrock_$TIMESTAMP.tar.gz
fi
EOF
        
        # Make the script executable
        chmod +x /tmp/k8s-backup.sh
        
        # Run the backup script
        /tmp/k8s-backup.sh || handle_error "Kubernetes backup failed" "backup"
        
        # Copy backups to backup directory
        mkdir -p "$BACKUP_DIR/$TIMESTAMP"
        cp /tmp/minecraft-backup/*.tar.gz "$BACKUP_DIR/$TIMESTAMP/" || handle_error "Failed to save backups" "backup"
        
        # Clean up
        rm -rf /tmp/minecraft-backup
        rm /tmp/k8s-backup.sh
    fi
    
    echo -e "${GREEN}Backup completed successfully.${NC}"
    echo -e "${YELLOW}Backups saved to: $BACKUP_DIR${NC}"
    
    # Clean up old backups (keep last 5)
    echo -e "${YELLOW}Cleaning up old backups (keeping last 5)...${NC}"
    (cd "$BACKUP_DIR" && ls -t | grep -v "/$" | tail -n +6 | xargs -r rm -rf)
}

# Restore Minecraft worlds
function restore_worlds {
    echo -e "${BLUE}Restoring Minecraft worlds...${NC}"
    
    # List available backups
    local BACKUP_DIR="minecraft-backups"
    
    if [[ ! -d "$BACKUP_DIR" ]]; then
        handle_error "Backup directory not found" "restore"
    fi
    
    # List backups in reverse order (newest first)
    echo -e "${YELLOW}Available backups:${NC}"
    local backup_list=($(ls -t "$BACKUP_DIR"))
    
    if [[ ${#backup_list[@]} -eq 0 ]]; then
        handle_error "No backups found" "restore"
    fi
    
    # Print the list with numbers
    for i in "${!backup_list[@]}"; do
        echo -e "$((i+1)). ${backup_list[$i]}"
    done
    
    # Prompt for backup selection unless in non-interactive mode
    local backup_selection=0
    
    if [[ "$INTERACTIVE" == "true" ]]; then
        echo -e "${YELLOW}Enter backup number to restore (1-${#backup_list[@]}) or 'q' to quit:${NC}"
        read -r selection
        
        if [[ "$selection" == "q" ]]; then
            echo -e "${YELLOW}Restore cancelled.${NC}"
            exit 0
        fi
        
        backup_selection=$((selection-1))
    else
        # In non-interactive mode, use the latest backup
        backup_selection=0
    fi
    
    # Validate selection
    if [[ $backup_selection -lt 0 || $backup_selection -ge ${#backup_list[@]} ]]; then
        handle_error "Invalid backup selection" "restore"
    fi
    
    local selected_backup="${backup_list[$backup_selection]}"
    echo -e "${YELLOW}Selected backup: $selected_backup${NC}"
    
    # Restore based on orchestration method
    if [[ "$ORCHESTRATION" == "compose" && "$SKIP_TERRAFORM" == "true" ]]; then
        # Restore local volumes
        if [[ -f "$BACKUP_DIR/$selected_backup/minecraft_java_$selected_backup.tar.gz" ]]; then
            echo -e "${YELLOW}Stopping Docker containers...${NC}"
            docker compose down
            
            echo -e "${YELLOW}Restoring Minecraft Java world...${NC}"
            rm -rf data/minecraft-java/*
            tar -xzf "$BACKUP_DIR/$selected_backup/minecraft_java_$selected_backup.tar.gz" -C data/minecraft-java
            
            if [[ "$USE_BEDROCK" == "true" && -f "$BACKUP_DIR/$selected_backup/minecraft_bedrock_$selected_backup.tar.gz" ]]; then
                echo -e "${YELLOW}Restoring Minecraft Bedrock world...${NC}"
                rm -rf data/minecraft-bedrock/*
                tar -xzf "$BACKUP_DIR/$selected_backup/minecraft_bedrock_$selected_backup.tar.gz" -C data/minecraft-bedrock
            fi
            
            echo -e "${YELLOW}Starting Docker containers...${NC}"
            docker compose up -d
        else
            # Older backup format
            if [[ -f "$BACKUP_DIR/minecraft_java_$selected_backup.tar.gz" ]]; then
                echo -e "${YELLOW}Stopping Docker containers...${NC}"
                docker compose down
                
                echo -e "${YELLOW}Restoring Minecraft Java world...${NC}"
                rm -rf data/minecraft-java/*
                tar -xzf "$BACKUP_DIR/minecraft_java_$selected_backup.tar.gz" -C data/minecraft-java
                
                if [[ "$USE_BEDROCK" == "true" && -f "$BACKUP_DIR/minecraft_bedrock_$selected_backup.tar.gz" ]]; then
                    echo -e "${YELLOW}Restoring Minecraft Bedrock world...${NC}"
                    rm -rf data/minecraft-bedrock/*
                    tar -xzf "$BACKUP_DIR/minecraft_bedrock_$selected_backup.tar.gz" -C data/minecraft-bedrock
                fi
                
                echo -e "${YELLOW}Starting Docker containers...${NC}"
                docker compose up -d
            else
                handle_error "Backup files not found in selected backup" "restore"
            fi
        fi
        
    elif [[ "$ORCHESTRATION" == "swarm" ]]; then
        # Restore remote Docker Swarm volumes
        if [[ ! -f "static_ip.ini" ]]; then
            handle_error "Inventory file static_ip.ini not found" "restore"
        fi
        
        # Get manager node from inventory
        MANAGER_IP=$(grep -A1 '\[instance1\]' static_ip.ini | tail -n1 | awk '{print $1}')
        
        if [[ -n "$MANAGER_IP" ]]; then
            echo -e "${YELLOW}Connecting to manager node $MANAGER_IP for restore...${NC}"
            
            # Create a temporary directory for selected backup
            ssh $SSH_OPTS -i ssh_keys/instance1.pem ubuntu@$MANAGER_IP "mkdir -p /tmp/minecraft-restore" || handle_error "Failed to create temp directory on remote server" "restore"
            
            # Copy backup to remote server
            echo -e "${YELLOW}Uploading backup to remote server...${NC}"
            if [[ -d "$BACKUP_DIR/$selected_backup" ]]; then
                scp $SSH_OPTS -i ssh_keys/instance1.pem "$BACKUP_DIR/$selected_backup/"*.tar.gz "ubuntu@$MANAGER_IP:/tmp/minecraft-restore/" || handle_error "Failed to upload backup" "restore"
            else
                scp $SSH_OPTS -i ssh_keys/instance1.pem "$BACKUP_DIR/minecraft_java_$selected_backup.tar.gz" "ubuntu@$MANAGER_IP:/tmp/minecraft-restore/" || handle_error "Failed to upload backup" "restore"
                
                if [[ "$USE_BEDROCK" == "true" && -f "$BACKUP_DIR/minecraft_bedrock_$selected_backup.tar.gz" ]]; then
                    scp $SSH_OPTS -i ssh_keys/instance1.pem "$BACKUP_DIR/minecraft_bedrock_$selected_backup.tar.gz" "ubuntu@$MANAGER_IP:/tmp/minecraft-restore/" || handle_error "Failed to upload Bedrock backup" "restore"
                fi
            fi
            
            # Create and execute a restore script on the remote server
            cat > /tmp/remote-restore.sh << EOF
#!/bin/bash
# Stop Minecraft services
docker service scale Mineclifford_minecraft-java=0
if docker service ls | grep -q Mineclifford_minecraft-bedrock; then
    docker service scale Mineclifford_minecraft-bedrock=0
fi

# Wait for services to stop
echo "Waiting for services to stop..."
sleep 10

# Backup current world just in case
timestamp=\$(date +%Y%m%d_%H%M%S)
mkdir -p /home/ubuntu/minecraft-backups
docker run --rm -v mineclifford_minecraft_java_data:/data -v /home/ubuntu/minecraft-backups:/backup \
    alpine tar -czf /backup/minecraft_java_pre_restore_\$timestamp.tar.gz -C /data .

if docker volume ls | grep -q mineclifford_minecraft_bedrock_data; then
    docker run --rm -v mineclifford_minecraft_bedrock_data:/data -v /home/ubuntu/minecraft-backups:/backup \
        alpine tar -czf /backup/minecraft_bedrock_pre_restore_\$timestamp.tar.gz -C /data .
fi

# Clear current world data
echo "Clearing current world data..."
docker run --rm -v mineclifford_minecraft_java_data:/data alpine sh -c "rm -rf /data/*"

if docker volume ls | grep -q mineclifford_minecraft_bedrock_data; then
    docker run --rm -v mineclifford_minecraft_bedrock_data:/data alpine sh -c "rm -rf /data/*"
fi

# Restore from backup
echo "Restoring from backup..."
for f in /tmp/minecraft-restore/minecraft_java_*.tar.gz; do
    if [[ -f "\$f" ]]; then
        docker run --rm -v mineclifford_minecraft_java_data:/data -v /tmp/minecraft-restore:/backup \
            alpine tar -xzf "/backup/\$(basename \$f)" -C /data
        break  # Only use the first file found
    fi
done

for f in /tmp/minecraft-restore/minecraft_bedrock_*.tar.gz; do
    if [[ -f "\$f" && -n "\$(docker volume ls | grep mineclifford_minecraft_bedrock_data)" ]]; then
        docker run --rm -v mineclifford_minecraft_bedrock_data:/data -v /tmp/minecraft-restore:/backup \
            alpine tar -xzf "/backup/\$(basename \$f)" -C /data
        break  # Only use the first file found
    fi
done

# Restart services
echo "Restarting services..."
docker service scale Mineclifford_minecraft-java=1
if docker service ls | grep -q Mineclifford_minecraft-bedrock; then
    docker service scale Mineclifford_minecraft-bedrock=1
fi

# Clean up
rm -rf /tmp/minecraft-restore
EOF
            
            # Upload and execute the restore script
            scp $SSH_OPTS -i ssh_keys/instance1.pem /tmp/remote-restore.sh "ubuntu@$MANAGER_IP:/tmp/remote-restore.sh" || handle_error "Failed to upload restore script" "restore"
            ssh $SSH_OPTS -i ssh_keys/instance1.pem ubuntu@$MANAGER_IP "chmod +x /tmp/remote-restore.sh && /tmp/remote-restore.sh" || handle_error "Remote restore failed" "restore"
            
        else
            handle_error "Could not find manager IP in inventory" "restore"
        fi
        
    elif [[ "$ORCHESTRATION" == "kubernetes" ]]; then
        # Restore Kubernetes volumes
        echo -e "${YELLOW}Restoring Kubernetes volumes...${NC}"
        
        # Create restore script
        cat > /tmp/k8s-restore.sh << EOF
#!/bin/bash
# Scale down deployments
kubectl scale deployment minecraft-java --replicas=0 -n $NAMESPACE
if kubectl get deployment minecraft-bedrock -n $NAMESPACE &>/dev/null; then
    kubectl scale deployment minecraft-bedrock --replicas=0 -n $NAMESPACE
fi

# Wait for pods to terminate
echo "Waiting for pods to terminate..."
kubectl wait --for=delete pod --selector=app=minecraft-java -n $NAMESPACE --timeout=120s || true

# Create temporary pod for Java restore
cat << 'EOL' | kubectl apply -n $NAMESPACE -f -
apiVersion: v1
kind: Pod
metadata:
  name: minecraft-restore-java
  namespace: $NAMESPACE
spec:
  volumes:
  - name: minecraft-data
    persistentVolumeClaim:
      claimName: minecraft-java-pvc
  containers:
  - name: restore
    image: alpine:latest
    command: ["sh", "-c", "rm -rf /data/* && sleep 3600"]
    volumeMounts:
    - mountPath: /data
      name: minecraft-data
EOL

# Wait for restoration pod to be ready
echo "Waiting for restoration pod to be ready..."
kubectl wait --for=condition=Ready pod/minecraft-restore-java -n $NAMESPACE --timeout=60s || true

# Copy backup to the pod
echo "Copying Java backup to pod..."
backup_file=""
if [[ -d "$BACKUP_DIR/$selected_backup" ]]; then
    backup_file=\$(ls -1 "$BACKUP_DIR/$selected_backup"/minecraft_java_*.tar.gz 2>/dev/null | head -n 1)
else
    backup_file="$BACKUP_DIR/minecraft_java_$selected_backup.tar.gz"
fi

if [[ -f "\$backup_file" ]]; then
    kubectl cp "\$backup_file" $NAMESPACE/minecraft-restore-java:/tmp/backup.tar.gz
    kubectl exec -n $NAMESPACE minecraft-restore-java -- tar -xzf /tmp/backup.tar.gz -C /data
    echo "Java backup restored successfully"
else
    echo "ERROR: Java backup file not found"
    exit 1
fi

# Delete the temporary pod
kubectl delete pod minecraft-restore-java -n $NAMESPACE

# If Bedrock is enabled, restore it too
if kubectl get deployment minecraft-bedrock -n $NAMESPACE &>/dev/null; then
    # Create temporary pod for Bedrock restore
    cat << 'EOL' | kubectl apply -n $NAMESPACE -f -
apiVersion: v1
kind: Pod
metadata:
  name: minecraft-restore-bedrock
  namespace: $NAMESPACE
spec:
  volumes:
  - name: minecraft-data
    persistentVolumeClaim:
      claimName: minecraft-bedrock-pvc
  containers:
  - name: restore
    image: alpine:latest
    command: ["sh", "-c", "rm -rf /data/* && sleep 3600"]
    volumeMounts:
    - mountPath: /data
      name: minecraft-data
EOL

    # Wait for restoration pod to be ready
    echo "Waiting for Bedrock restoration pod to be ready..."
    kubectl wait --for=condition=Ready pod/minecraft-restore-bedrock -n $NAMESPACE --timeout=60s || true

    # Copy backup to the pod
    echo "Copying Bedrock backup to pod..."
    bedrock_backup_file=""
    if [[ -d "$BACKUP_DIR/$selected_backup" ]]; then
        bedrock_backup_file=\$(ls -1 "$BACKUP_DIR/$selected_backup"/minecraft_bedrock_*.tar.gz 2>/dev/null | head -n 1)
    else
        bedrock_backup_file="$BACKUP_DIR/minecraft_bedrock_$selected_backup.tar.gz"
    fi

    if [[ -f "\$bedrock_backup_file" ]]; then
        kubectl cp "\$bedrock_backup_file" $NAMESPACE/minecraft-restore-bedrock:/tmp/backup.tar.gz
        kubectl exec -n $NAMESPACE minecraft-restore-bedrock -- tar -xzf /tmp/backup.tar.gz -C /data
        echo "Bedrock backup restored successfully"
    else
        echo "WARNING: Bedrock backup file not found, skipping Bedrock restore"
    fi

    # Delete the temporary pod
    kubectl delete pod minecraft-restore-bedrock -n $NAMESPACE
fi

# Scale up deployments again
kubectl scale deployment minecraft-java --replicas=1 -n $NAMESPACE
if kubectl get deployment minecraft-bedrock -n $NAMESPACE &>/dev/null; then
    kubectl scale deployment minecraft-bedrock --replicas=1 -n $NAMESPACE
fi

echo "Restoration complete. Waiting for pods to start..."
kubectl get pods -n $NAMESPACE -w
EOF
        
        # Make the script executable
        chmod +x /tmp/k8s-restore.sh
        
        # Run the restore script
        /tmp/k8s-restore.sh || handle_error "Kubernetes restore failed" "restore"
        
        # Clean up
        rm /tmp/k8s-restore.sh
    fi
    
    echo -e "${GREEN}Restore completed successfully.${NC}"
}

# Check deployed infrastructure status
function check_status {
    echo -e "${BLUE}Checking deployment status...${NC}"
    
    if [[ "$ORCHESTRATION" == "compose" ]]; then
        if [[ "$SKIP_TERRAFORM" == "true" ]]; then
            # Check local Docker Compose services
            if command -v docker &> /dev/null; then
                echo -e "${YELLOW}Checking local Docker Compose services:${NC}"
                docker compose -f docker-compose.yml ps || handle_error "Failed to check local Docker Compose services" "status"
                echo -e "RCON Web Admin: http://127.0.0.1:4326"
            else
                handle_error "Docker is not installed" "status"
            fi
        else
            # Check remote Docker Compose services
            if [[ -f "static_ip.ini" ]]; then
                MANAGER_IP=$(grep -A1 '\[instance1\]' static_ip.ini | tail -n1 | awk '{print $1}')

                if [[ -n "$MANAGER_IP" ]]; then
                    echo -e "${YELLOW}Checking remote Docker Compose services on $MANAGER_IP:${NC}"
                    ssh $SSH_OPTS -i ssh_keys/instance1.pem ubuntu@$MANAGER_IP "docker compose -f /home/ubuntu/mineclifford-compose/docker-compose.yml ps" || handle_error "Failed to check remote Docker Compose services" "status"

                    # Get connection information
                    echo -e "${YELLOW}Connection Information:${NC}"
                    echo -e "Java Server: $MANAGER_IP:25565"
                    if [[ "$USE_BEDROCK" == "true" ]]; then
                        echo -e "Bedrock Server: $MANAGER_IP:19132 (UDP)"
                    fi
                    echo -e "RCON Web Admin (SSH tunnel): ssh -L 4326:127.0.0.1:4326 ubuntu@$MANAGER_IP"
                else
                    handle_error "Could not find manager IP in inventory" "status"
                fi
            else
                handle_error "Inventory file static_ip.ini not found" "status"
            fi
        fi
        
    elif [[ "$ORCHESTRATION" == "swarm" ]]; then
        # Check Docker Swarm services
        if [[ -f "static_ip.ini" ]]; then
            MANAGER_IP=$(grep -A1 '\[instance1\]' static_ip.ini | tail -n1 | awk '{print $1}')
            
            if [[ -n "$MANAGER_IP" ]]; then
                echo -e "${YELLOW}Checking Docker Swarm services on $MANAGER_IP:${NC}"
                ssh $SSH_OPTS -i ssh_keys/instance1.pem ubuntu@$MANAGER_IP "docker service ls" || handle_error "Failed to check Docker Swarm services" "status"
                
                # Check logs
                echo -e "${YELLOW}Checking Java server logs (last 10 lines):${NC}"
                ssh $SSH_OPTS -i ssh_keys/instance1.pem ubuntu@$MANAGER_IP "docker service logs Mineclifford_minecraft-java --tail 10" || echo -e "${YELLOW}Could not fetch Java server logs${NC}"
                
                if [[ "$USE_BEDROCK" == "true" ]]; then
                    echo -e "${YELLOW}Checking Bedrock server logs (last 10 lines):${NC}"
                    ssh $SSH_OPTS -i ssh_keys/instance1.pem ubuntu@$MANAGER_IP "docker service logs Mineclifford_minecraft-bedrock --tail 10" || echo -e "${YELLOW}Could not fetch Bedrock server logs${NC}"
                fi
                
                # Check node status
                echo -e "${YELLOW}Checking Docker Swarm node status:${NC}"
                ssh $SSH_OPTS -i ssh_keys/instance1.pem ubuntu@$MANAGER_IP "docker node ls" || echo -e "${YELLOW}Could not fetch node status${NC}"
                
                # Get connection information
                echo -e "${YELLOW}Connection Information:${NC}"
                echo -e "Java Server: $MANAGER_IP:25565"
                if [[ "$USE_BEDROCK" == "true" ]]; then
                    echo -e "Bedrock Server: $MANAGER_IP:19132 (UDP)"
                fi
                echo -e "Grafana Dashboard: http://$MANAGER_IP:3000 (admin/admin)"
                echo -e "Prometheus: http://$MANAGER_IP:9090"
                echo -e "RCON Web Admin: http://$MANAGER_IP:4326 (admin/minecraft)"
            else
                handle_error "Could not find manager IP in inventory" "status"
            fi
        else
            handle_error "Inventory file static_ip.ini not found" "status"
        fi
        
    elif [[ "$ORCHESTRATION" == "kubernetes" ]]; then
        # Check Kubernetes deployments
        if command -v kubectl &> /dev/null; then
            echo -e "${YELLOW}Checking Kubernetes deployments in namespace $NAMESPACE:${NC}"
            kubectl get deployments --namespace=$NAMESPACE || handle_error "Failed to check Kubernetes deployments" "status"
            
            echo -e "${YELLOW}Checking Kubernetes services in namespace $NAMESPACE:${NC}"
            kubectl get services --namespace=$NAMESPACE || handle_error "Failed to check Kubernetes services" "status"
            
            echo -e "${YELLOW}Checking Kubernetes pods in namespace $NAMESPACE:${NC}"
            kubectl get pods --namespace=$NAMESPACE || handle_error "Failed to check Kubernetes pods" "status"
            
            # Check logs
            echo -e "${YELLOW}Checking Java server logs (last 10 lines):${NC}"
            JAVA_POD=$(kubectl get pod -l app=minecraft-java -n $NAMESPACE -o jsonpath="{.items[0].metadata.name}" 2>/dev/null)
            if [[ -n "$JAVA_POD" ]]; then
                kubectl logs -n $NAMESPACE $JAVA_POD --tail=10 || echo -e "${YELLOW}Could not fetch Java server logs${NC}"
            else
                echo -e "${YELLOW}Java server pod not found${NC}"
            fi
            
            if [[ "$USE_BEDROCK" == "true" ]]; then
                echo -e "${YELLOW}Checking Bedrock server logs (last 10 lines):${NC}"
                BEDROCK_POD=$(kubectl get pod -l app=minecraft-bedrock -n $NAMESPACE -o jsonpath="{.items[0].metadata.name}" 2>/dev/null)
                if [[ -n "$BEDROCK_POD" ]]; then
                    kubectl logs -n $NAMESPACE $BEDROCK_POD --tail=10 || echo -e "${YELLOW}Could not fetch Bedrock server logs${NC}"
                else
                    echo -e "${YELLOW}Bedrock server pod not found${NC}"
                fi
            fi
            
            # Get connection information
            echo -e "${YELLOW}Connection Information:${NC}"
            JAVA_IP=$(kubectl get service minecraft-java -n $NAMESPACE -o jsonpath="{.status.loadBalancer.ingress[0].ip}" 2>/dev/null)
            JAVA_HOSTNAME=$(kubectl get service minecraft-java -n $NAMESPACE -o jsonpath="{.status.loadBalancer.ingress[0].hostname}" 2>/dev/null)
            
            if [[ -n "$JAVA_IP" ]]; then
                echo -e "Java Server: $JAVA_IP:25565"
            elif [[ -n "$JAVA_HOSTNAME" ]]; then
                echo -e "Java Server: $JAVA_HOSTNAME:25565"
            else
                echo -e "Java Server: Could not determine address, service may still be provisioning"
            fi
            
            if [[ "$USE_BEDROCK" == "true" ]]; then
                BEDROCK_IP=$(kubectl get service minecraft-bedrock -n $NAMESPACE -o jsonpath="{.status.loadBalancer.ingress[0].ip}" 2>/dev/null)
                BEDROCK_HOSTNAME=$(kubectl get service minecraft-bedrock -n $NAMESPACE -o jsonpath="{.status.loadBalancer.ingress[0].hostname}" 2>/dev/null)
                
                if [[ -n "$BEDROCK_IP" ]]; then
                    echo -e "Bedrock Server: $BEDROCK_IP:19132 (UDP)"
                elif [[ -n "$BEDROCK_HOSTNAME" ]]; then
                    echo -e "Bedrock Server: $BEDROCK_HOSTNAME:19132 (UDP)"
                else
                    echo -e "Bedrock Server: Could not determine address, service may still be provisioning"
                fi
            fi
            
            # Get dashboard information
            echo -e "RCON Web Admin: kubectl -n $NAMESPACE port-forward svc/rcon-web-admin 4326:4326"

            GRAFANA_URL=$(kubectl get ingress -n $NAMESPACE -o jsonpath="{.items[?(@.metadata.name=='grafana')].spec.rules[0].host}" 2>/dev/null)
            if [[ -n "$GRAFANA_URL" ]]; then
                echo -e "Grafana Dashboard: https://$GRAFANA_URL (admin/admin)"
            else
                echo -e "Grafana Dashboard: Not exposed via Ingress"
            fi
            
            PROMETHEUS_URL=$(kubectl get ingress -n $NAMESPACE -o jsonpath="{.items[?(@.metadata.name=='prometheus')].spec.rules[0].host}" 2>/dev/null)
            if [[ -n "$PROMETHEUS_URL" ]]; then
                echo -e "Prometheus: https://$PROMETHEUS_URL"
            else
                echo -e "Prometheus: Not exposed via Ingress"
            fi
        else
            handle_error "kubectl is not installed" "status"
        fi
    fi
    
    echo -e "${GREEN}Status check completed.${NC}"
}

# Destroy infrastructure
function destroy_infrastructure {
    echo -e "${BLUE}Destroying Minecraft infrastructure...${NC}"
    
    if [[ "$INTERACTIVE" == "true" && "$FORCE_CLEANUP" != "true" ]]; then
        echo -e "${RED}WARNING: This will destroy all resources. There is NO UNDO.${NC}"
        echo -e "${YELLOW}Do you really want to destroy all resources? Type 'yes' to confirm.${NC}"
        read -r confirm
        if [[ "$confirm" != "yes" ]]; then
            echo -e "${YELLOW}Destruction aborted.${NC}"
            exit 0
        fi
    fi
    
    if [[ "$ORCHESTRATION" == "compose" && "$SKIP_TERRAFORM" == "true" ]]; then
        # Destroy local Docker Compose containers
        echo -e "${YELLOW}Stopping and removing Docker Compose containers...${NC}"
        docker compose -f docker-compose.yml down -v || handle_error "Failed to stop Docker containers" "destroy"
        
        # Remove data directories if forced
        if [[ "$FORCE_CLEANUP" == "true" ]]; then
            echo -e "${YELLOW}Removing data directories...${NC}"
            rm -rf data/
        fi
        
    elif [[ "$ORCHESTRATION" == "swarm" || "$ORCHESTRATION" == "kubernetes" || "$ORCHESTRATION" == "compose" ]]; then
        # Based on provider, call the right terraform destroy
        if [[ "$PROVIDER" == "aws" ]]; then
            tf_dir="terraform/aws"
            if [[ "$ORCHESTRATION" == "kubernetes" ]]; then
                tf_dir="${tf_dir}/kubernetes"
            fi
        elif [[ "$PROVIDER" == "azure" ]]; then
            tf_dir="terraform/azure"
            if [[ "$ORCHESTRATION" == "kubernetes" ]]; then
                tf_dir="${tf_dir}/kubernetes"
            fi
        fi
        
        # For Swarm, first remove the Docker stack
        if [[ "$ORCHESTRATION" == "swarm" && -f "static_ip.ini" ]]; then
            MANAGER_IP=$(grep -A1 '\[instance1\]' static_ip.ini | tail -n1 | awk '{print $1}')
            if [[ -n "$MANAGER_IP" ]]; then
                echo -e "${YELLOW}Removing Docker stack from $MANAGER_IP...${NC}"
                ssh $SSH_OPTS -i ssh_keys/instance1.pem ubuntu@$MANAGER_IP "docker stack rm Mineclifford" || echo -e "${YELLOW}Failed to remove Docker stack, continuing with destroy...${NC}"
            fi
        fi

        # For cloud compose, stop compose before Terraform destroy
        if [[ "$ORCHESTRATION" == "compose" && -f "static_ip.ini" ]]; then
            MANAGER_IP=$(grep -A1 '\[instance1\]' static_ip.ini | tail -n1 | awk '{print $1}')
            if [[ -n "$MANAGER_IP" ]]; then
                echo -e "${YELLOW}Removing Docker Compose services from $MANAGER_IP...${NC}"
                ssh $SSH_OPTS -i ssh_keys/instance1.pem ubuntu@$MANAGER_IP "docker compose -f /home/ubuntu/mineclifford-compose/docker-compose.yml down -v" || echo -e "${YELLOW}Failed to remove Docker Compose services, continuing with destroy...${NC}"
            fi
        fi
        
        # For Kubernetes, remove the namespace
        if [[ "$ORCHESTRATION" == "kubernetes" ]]; then
            echo -e "${YELLOW}Removing Kubernetes namespace $NAMESPACE...${NC}"
            kubectl delete namespace $NAMESPACE || echo -e "${YELLOW}Failed to remove Kubernetes namespace, continuing with destroy...${NC}"
        fi
        
        # Run Terraform destroy
        echo -e "${YELLOW}Destroying infrastructure with Terraform...${NC}"
        cd "$tf_dir" || handle_error "Failed to change to directory $tf_dir" "destroy"
        terraform destroy -auto-approve || handle_error "Terraform destroy failed" "destroy"
        cd - > /dev/null
        
        # Run the verify-destruction.sh script
        echo -e "${YELLOW}Verifying destruction...${NC}"
        $SCRIPT_DIR/scripts/verify-destruction.sh --provider $PROVIDER ${FORCE_CLEANUP:+--force} || handle_error "Failed to verify destruction" "destroy"
    fi
    
    echo -e "${GREEN}Infrastructure destroyed successfully.${NC}"
    
    # Remove success marker files
    rm -f .minecraft_deployment .minecraft_k8s_deployment
}

# Function to deploy Minecraft infrastructure
function deploy_infrastructure {
    echo -e "${BLUE}Starting Minecraft deployment with the following configuration:${NC}"
    echo -e "Provider: ${BLUE}$PROVIDER${NC}"
    echo -e "Orchestration: ${BLUE}$ORCHESTRATION${NC}"

    initialize_runtime_config

    # Ensure RCON/Grafana passwords are loaded or generated
    ensure_passwords

    # In cloud modes we derive default Kubernetes provider from cloud provider
    if [[ "$ORCHESTRATION" != "compose" || "$SKIP_TERRAFORM" != "true" ]]; then
        if [[ "$PROVIDER" == "aws" ]]; then
            KUBERNETES_PROVIDER="eks"
        elif [[ "$PROVIDER" == "azure" ]]; then
            KUBERNETES_PROVIDER="aks"
        fi
    fi
    
    echo -e "Server Names: ${BLUE}${SERVER_NAMES[*]}${NC}"
    echo -e "Version: ${BLUE}$MINECRAFT_VERSION${NC}"
    echo -e "Mode: ${BLUE}$MINECRAFT_MODE${NC}"
    echo -e "Difficulty: ${BLUE}$MINECRAFT_DIFFICULTY${NC}"
    echo -e "Log file: ${BLUE}$DEPLOYMENT_LOG${NC}"


    if [[ ${#SERVER_NAMES[@]} -eq 1 ]]; then
        echo -e "${YELLOW}Deploying with a single node. Configuring single-node swarm.${NC}"
        SINGLE_NODE_SWARM=true
    else
        echo -e "${YELLOW}Deploying with multiple nodes. Configuring multi-node swarm.${NC}"
        SINGLE_NODE_SWARM=false
    fi

    ANSIBLE_EXTRA_VARS="single_node_swarm=$SINGLE_NODE_SWARM"
    
    # Handle world importing preparation if specified
    if [[ -n "$WORLD_IMPORT" && -f "$WORLD_IMPORT" ]]; then
        echo -e "World Import: ${BLUE}$WORLD_IMPORT${NC}"
        
        # Prepare the world import (extraction only)
        TIMESTAMP=$(date +%Y%m%d_%H%M%S)
        IMPORT_DIR="world_imports/$TIMESTAMP"
        mkdir -p "$IMPORT_DIR"
        
        echo -e "${YELLOW}Extracting world data...${NC}"
        unzip "$WORLD_IMPORT" -d "$IMPORT_DIR"
        
        # Create a tarball for remote deployment methods
        tar -czf "world_imports/import_${TIMESTAMP}.tar.gz" -C "$IMPORT_DIR" .
        
        # Store as absolute paths — run_ansible() later changes into deployment/ansible/
        # and relative paths would silently break the Ansible copy task
        export MINECRAFT_WORLD_IMPORT_DIR="$(realpath "$IMPORT_DIR")"
        export MINECRAFT_WORLD_IMPORT_TAR="$(realpath "world_imports/import_${TIMESTAMP}.tar.gz")"
        export MINECRAFT_WORLD_IMPORT_READY="true"
    fi
    
    echo -e "${GREEN}==========================================${NC}"
    
    if [[ "$ORCHESTRATION" == "compose" && "$SKIP_TERRAFORM" == "true" ]]; then
        echo -e "${YELLOW}Compose local mode selected. Skipping Terraform and Ansible.${NC}"
        deploy_local_compose
    else
        # Try to reuse previously saved state before planning/applying changes.
        # This prevents duplicate infrastructure when running from another machine/workspace.
        if [[ "$SAVE_STATE" == "true" ]]; then
            load_terraform_state || true
        fi

        run_terraform

        if [[ "$SAVE_STATE" == "true" ]]; then
            save_terraform_state || true
        fi

        if [[ "$ORCHESTRATION" == "kubernetes" ]]; then
            echo -e "${YELLOW}Skipping Ansible for Kubernetes deployment and proceeding directly to Kubernetes setup...${NC}"
            deploy_to_kubernetes
        elif [[ "$ORCHESTRATION" == "compose" ]]; then
            echo -e "${YELLOW}Preparing Docker Compose template for cloud deployment...${NC}"
            generate_docker_compose_file "$SCRIPT_DIR/docker-compose.generated.yml" "./data"
            run_ansible
        else
            run_ansible
        fi
    fi

    # Show connection information
    check_status
}                       

# Parse command line arguments
# First parameter is the action
if [[ $# -gt 0 && "$1" =~ ^(deploy|destroy|status|save-state|load-state|backup|restore)$ ]]; then
    ACTION="$1"
    shift
fi

# Parse remaining parameters
while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--provider)
            PROVIDER="$2"
            shift 2
            ;;
        -o|--orchestration)
            ORCHESTRATION="$2"
            shift 2
            ;;
        -s|--skip-terraform)
            SKIP_TERRAFORM=true
            shift
            ;;
        -v|--minecraft-version)
            MINECRAFT_VERSION="$2"
            shift 2
            ;;
        -m|--mode)
            MINECRAFT_MODE="$2"
            shift 2
            ;;
        -d|--difficulty)
            MINECRAFT_DIFFICULTY="$2"
            shift 2
            ;;
        --bedrock|--use-bedrock)
            USE_BEDROCK=true
            shift
            ;;
        -b|--no-bedrock)
            USE_BEDROCK=false
            shift
            ;;
        -w|--world-import)
            WORLD_IMPORT="$2"
            shift 2
            ;;
        -k|--k8s)
            KUBERNETES_PROVIDER="$2"
            shift 2
            ;;
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -mem|--memory)
            MEMORY="$2"
            shift 2
            ;;
        -sn|--server-names)
            IFS=',' read -r -a SERVER_NAMES <<< "$2"
            shift 2
            ;;
        -f|--force)
            FORCE_CLEANUP=true
            shift
            ;;
        --no-interactive)
            INTERACTIVE=false
            shift
            ;;
        --no-rollback)
            ROLLBACK_ENABLED=false
            shift
            ;;
        --no-save-state)
            SAVE_STATE=false
            shift
            ;;
        --storage-type)
            STORAGE_TYPE="$2"
            shift 2
            ;;
        --project-name)
            PROJECT_NAME="$2"
            shift 2
            ;;
        --environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        --owner)
            OWNER="$2"
            shift 2
            ;;
        --region)
            REGION_OVERRIDE="$2"
            shift 2
            ;;
        --instance-type)
            INSTANCE_TYPE="$2"
            shift 2
            ;;
        --disk-size)
            DISK_SIZE_GB="$2"
            shift 2
            ;;
        --server-type)
            SERVER_TYPE="$(echo "$2" | tr '[:lower:]' '[:upper:]')"
            shift 2
            ;;
        --mods)
            MODRINTH_PROJECTS="$2"
            shift 2
            ;;
        --mod-deps)
            MODRINTH_DOWNLOAD_DEPS="$2"
            shift 2
            ;;
        --mod-loader-version)
            MOD_LOADER_VERSION="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            show_help
            ;;
    esac
done

# Backward-compatible alias: local => compose --skip-terraform
if [[ "$ORCHESTRATION" == "local" ]]; then
    ORCHESTRATION="compose"
    SKIP_TERRAFORM=true
fi

# Validate environment
validate_environment

# Execute action
case "$ACTION" in
    deploy)
        deploy_infrastructure
        ;;
    destroy)
        destroy_infrastructure
        ;;
    status)
        check_status
        ;;
    save-state)
        save_terraform_state
        ;;
    load-state)
        load_terraform_state
        ;;
    backup)
        backup_worlds
        ;;
    restore)
        restore_worlds
        ;;
    *)
        echo -e "${RED}Unknown action: $ACTION${NC}"
        show_help
        ;;
esac

exit 0