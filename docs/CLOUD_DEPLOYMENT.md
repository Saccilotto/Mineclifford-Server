# Cloud Deployment Guide

## Overview

Mineclifford supports deploying Minecraft servers to both local Docker containers and cloud providers (AWS, Azure) using Terraform for infrastructure provisioning and Ansible for configuration management.

## Architecture

### Local Deployment (Docker)
- **Provider**: `local`
- **Container Engine**: Docker
- **Management**: Direct Docker API via httpx
- **Benefits**: Fast, cost-effective, easy testing

### Cloud Deployment (AWS/Azure)
- **Provider**: `aws` or `azure`
- **Infrastructure**: Terraform
- **Configuration**: Ansible
- **Benefits**: Scalable, production-ready, multi-region support

## Current Implementation Status

### ✅ Completed
- Local Docker deployment with full container lifecycle management
- Docker socket communication via httpx
- Container monitoring and metrics
- Automatic backups
- WebSocket console with real-time logs

### ⏳ Partially Implemented
- Cloud deployment structure in [deployment.py](../src/web/backend/services/deployment.py)
- Terraform configuration templates
- Ansible integration scripts

### 🔜 To Be Implemented
- Full Terraform execution for AWS/Azure
- Multi-region support
- Cloud resource cleanup
- Cloud-specific monitoring

## Setting Up Cloud Deployments

### Prerequisites

#### For AWS
```bash
# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Configure credentials
aws configure
# Enter: AWS Access Key ID, Secret Access Key, Region, Output format
```

#### For Azure
```bash
# Install Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Login
az login

# Set subscription
az account set --subscription "YOUR_SUBSCRIPTION_ID"
```

#### Install Terraform
```bash
# Download and install Terraform
wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
unzip terraform_1.6.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/

# Verify installation
terraform --version
```

#### Install Ansible
```bash
# Install Ansible
sudo apt update
sudo apt install -y ansible

# Verify installation
ansible --version
```

## Cloud Deployment Workflow

### 1. Infrastructure Provisioning (Terraform)

The Terraform configuration creates:
- Compute instances (EC2 for AWS, VM for Azure)
- Security groups/Network security rules
- Public IP addresses
- Storage volumes
- SSH key pairs

#### AWS Example Configuration

```hcl
# infrastructure/terraform/aws/main.tf

provider "aws" {
  region = var.region
}

resource "aws_instance" "minecraft_server" {
  ami           = var.ami_id
  instance_type = var.instance_type
  key_name      = aws_key_pair.minecraft.key_name

  vpc_security_group_ids = [aws_security_group.minecraft.id]

  tags = {
    Name = "minecraft-${var.server_id}"
    ManagedBy = "Mineclifford"
  }

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }
}

resource "aws_security_group" "minecraft" {
  name        = "minecraft-${var.server_id}"
  description = "Security group for Minecraft server"

  ingress {
    from_port   = 25565
    to_port     = 25565
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["YOUR_IP/32"]  # Restrict SSH access
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_key_pair" "minecraft" {
  key_name   = "minecraft-${var.server_id}"
  public_key = file(var.public_key_path)
}

output "public_ip" {
  value = aws_instance.minecraft_server.public_ip
}

output "instance_id" {
  value = aws_instance.minecraft_server.id
}
```

#### Azure Example Configuration

```hcl
# infrastructure/terraform/azure/main.tf

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "minecraft" {
  name     = "minecraft-${var.server_id}-rg"
  location = var.location
}

resource "azurerm_virtual_network" "minecraft" {
  name                = "minecraft-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.minecraft.location
  resource_group_name = azurerm_resource_group.minecraft.name
}

resource "azurerm_subnet" "minecraft" {
  name                 = "minecraft-subnet"
  resource_group_name  = azurerm_resource_group.minecraft.name
  virtual_network_name = azurerm_virtual_network.minecraft.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_public_ip" "minecraft" {
  name                = "minecraft-${var.server_id}-ip"
  location            = azurerm_resource_group.minecraft.location
  resource_group_name = azurerm_resource_group.minecraft.name
  allocation_method   = "Static"
}

resource "azurerm_network_interface" "minecraft" {
  name                = "minecraft-${var.server_id}-nic"
  location            = azurerm_resource_group.minecraft.location
  resource_group_name = azurerm_resource_group.minecraft.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.minecraft.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.minecraft.id
  }
}

resource "azurerm_linux_virtual_machine" "minecraft" {
  name                = "minecraft-${var.server_id}"
  resource_group_name = azurerm_resource_group.minecraft.name
  location            = azurerm_resource_group.minecraft.location
  size                = var.vm_size
  admin_username      = "minecraftadmin"

  network_interface_ids = [
    azurerm_network_interface.minecraft.id,
  ]

  admin_ssh_key {
    username   = "minecraftadmin"
    public_key = file(var.public_key_path)
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
}

output "public_ip" {
  value = azurerm_public_ip.minecraft.ip_address
}
```

### 2. Server Configuration (Ansible)

Ansible playbooks configure the provisioned instances:
- Install Docker
- Pull Minecraft server image
- Configure server properties
- Set up auto-start
- Configure backups

#### Ansible Playbook Example

```yaml
# ansible/playbooks/minecraft_setup.yml

---
- name: Configure Minecraft Server
  hosts: minecraft_servers
  become: yes
  vars_files:
    - vars/server_config.yml

  tasks:
    - name: Update apt cache
      apt:
        update_cache: yes
        cache_valid_time: 3600

    - name: Install required packages
      apt:
        name:
          - docker.io
          - python3-pip
        state: present

    - name: Start and enable Docker
      systemd:
        name: docker
        state: started
        enabled: yes

    - name: Pull Minecraft server image
      docker_image:
        name: "itzg/minecraft-server:latest"
        source: pull

    - name: Create Minecraft data directory
      file:
        path: /opt/minecraft/data
        state: directory
        mode: '0755'

    - name: Run Minecraft server container
      docker_container:
        name: "minecraft_{{ server_id }}"
        image: "itzg/minecraft-server:latest"
        state: started
        restart_policy: unless-stopped
        env:
          EULA: "TRUE"
          TYPE: "{{ server_type }}"
          VERSION: "{{ version }}"
          MEMORY: "{{ memory }}"
          MAX_PLAYERS: "{{ max_players }}"
          MODE: "{{ gamemode }}"
          DIFFICULTY: "{{ difficulty }}"
        ports:
          - "25565:25565"
        volumes:
          - "/opt/minecraft/data:/data"

    - name: Configure firewall
      ufw:
        rule: allow
        port: "25565"
        proto: tcp

    - name: Enable firewall
      ufw:
        state: enabled
```

### 3. Integration in DeploymentService

The current structure in [deployment.py](../src/web/backend/services/deployment.py:63-89) provides the framework for cloud deployment:

```python
async def deploy_server(self, server_config: Dict[str, Any]) -> Dict[str, Any]:
    provider = server_config.get('provider', 'local')

    if provider == 'local':
        # Docker deployment (fully implemented)
        result = await self.docker_service.create_minecraft_container(server_config)
        return result
    else:
        # Cloud deployment (structure in place)
        # 1. Generate Ansible vars
        vars_file = await self.generate_vars(server_config)

        # 2. Execute terraform apply
        terraform_result = await self._run_terraform(server_config)

        # 3. Execute ansible-playbook
        ansible_result = await self._run_ansible(vars_file, terraform_result['ip'])

        return {
            "status": "success",
            "ip_address": terraform_result['ip'],
            "port": 25565,
            "deployment_type": "cloud"
        }
```

## Completing Cloud Deployment Implementation

### Step 1: Implement Terraform Execution

Add method to `DeploymentService`:

```python
async def _run_terraform(self, server_config: Dict[str, Any]) -> Dict[str, Any]:
    """Execute Terraform to provision infrastructure"""
    provider = server_config.get('provider')
    region = server_config.get('region', 'us-east-1')
    server_id = server_config['id']

    # Set up Terraform working directory
    tf_dir = self.terraform_dir / provider

    # Initialize Terraform
    init_cmd = ["terraform", "init"]
    subprocess.run(init_cmd, cwd=tf_dir, check=True)

    # Apply Terraform with variables
    apply_cmd = [
        "terraform", "apply",
        "-auto-approve",
        f"-var=server_id={server_id}",
        f"-var=region={region}",
        f"-var=instance_type={server_config.get('instance_type', 't3.medium')}"
    ]

    result = subprocess.run(apply_cmd, cwd=tf_dir, capture_output=True, text=True)

    if result.returncode != 0:
        raise Exception(f"Terraform failed: {result.stderr}")

    # Get outputs
    output_cmd = ["terraform", "output", "-json"]
    output_result = subprocess.run(output_cmd, cwd=tf_dir, capture_output=True, text=True)
    outputs = json.loads(output_result.stdout)

    return {
        "ip": outputs['public_ip']['value'],
        "instance_id": outputs['instance_id']['value']
    }
```

### Step 2: Implement Ansible Execution

Add method to `DeploymentService`:

```python
async def _run_ansible(self, vars_file: Path, target_ip: str) -> Dict[str, Any]:
    """Execute Ansible playbook to configure server"""
    playbook = Path(__file__).parent.parent.parent.parent / "ansible" / "playbooks" / "minecraft_setup.yml"

    # Create temporary inventory file
    inventory = f"{target_ip} ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/minecraft.pem"
    inventory_file = Path(f"/tmp/inventory_{uuid.uuid4()}.ini")
    inventory_file.write_text(inventory)

    try:
        # Run playbook
        cmd = [
            "ansible-playbook",
            str(playbook),
            "-i", str(inventory_file),
            "--extra-vars", f"@{vars_file}"
        ]

        result = subprocess.run(cmd, capture_output=True, text=True)

        if result.returncode != 0:
            raise Exception(f"Ansible failed: {result.stderr}")

        return {
            "status": "success",
            "output": result.stdout
        }
    finally:
        # Cleanup
        inventory_file.unlink(missing_ok=True)
```

### Step 3: Implement Resource Cleanup

Add method for destroying cloud resources:

```python
async def destroy_cloud_server(self, server_id: str, provider: str) -> Dict[str, Any]:
    """Destroy cloud resources using Terraform"""
    tf_dir = self.terraform_dir / provider

    destroy_cmd = [
        "terraform", "destroy",
        "-auto-approve",
        f"-var=server_id={server_id}"
    ]

    result = subprocess.run(destroy_cmd, cwd=tf_dir, capture_output=True, text=True)

    if result.returncode != 0:
        raise Exception(f"Terraform destroy failed: {result.stderr}")

    return {"status": "success"}
```

## Multi-Region Support

### Configuration

Add region options in [server.py model](../src/web/backend/models/server.py:28):

```python
class ServerCreate(BaseModel):
    # ... other fields ...
    provider: str = Field(default="local", pattern="^(aws|azure|local)$")
    region: str = "us-east-1"  # Already exists

    # Add region validators
    @validator('region')
    def validate_region(cls, v, values):
        provider = values.get('provider')

        aws_regions = ['us-east-1', 'us-west-2', 'eu-west-1', 'ap-southeast-1']
        azure_locations = ['eastus', 'westus2', 'northeurope', 'southeastasia']

        if provider == 'aws' and v not in aws_regions:
            raise ValueError(f'Invalid AWS region: {v}')
        elif provider == 'azure' and v not in azure_locations:
            raise ValueError(f'Invalid Azure location: {v}')

        return v
```

### Frontend Integration

Update [dashboard.js](../src/web/frontend/js/dashboard.js) to include provider and region selection:

```javascript
// Add to server creation form
const providerSelect = `
    <select name="provider">
        <option value="local">Local (Docker)</option>
        <option value="aws">AWS</option>
        <option value="azure">Azure</option>
    </select>
`;

const regionSelect = `
    <select name="region" id="regionSelect">
        <option value="us-east-1">US East (N. Virginia)</option>
        <option value="us-west-2">US West (Oregon)</option>
        <option value="eu-west-1">EU (Ireland)</option>
        <option value="ap-southeast-1">Asia Pacific (Singapore)</option>
    </select>
`;
```

## Security Considerations

### Credentials Management

1. **Never commit credentials to Git**
   ```bash
   # Add to .gitignore
   *.pem
   *.key
   terraform.tfvars
   secrets/
   ```

2. **Use environment variables**
   ```bash
   export AWS_ACCESS_KEY_ID="your-key"
   export AWS_SECRET_ACCESS_KEY="your-secret"
   export AZURE_SUBSCRIPTION_ID="your-subscription"
   ```

3. **Use secret managers for production**
   - AWS Secrets Manager
   - Azure Key Vault
   - HashiCorp Vault

### Network Security

1. **Restrict SSH access** to known IPs
2. **Use security groups** to limit Minecraft port (25565) exposure
3. **Enable VPC/VNet** for network isolation
4. **Use SSL/TLS** for management interfaces

## Cost Optimization

### Instance Sizing

| Players | AWS Instance | Azure VM | Monthly Cost (est.) |
|---------|--------------|----------|---------------------|
| 1-10    | t3.small     | B2s      | ~$15-20            |
| 10-20   | t3.medium    | B2ms     | ~$30-40            |
| 20-50   | t3.large     | B4ms     | ~$60-80            |
| 50+     | c5.xlarge    | F4s      | ~$120-150          |

### Cost-Saving Tips

1. **Use spot instances** for non-production servers
2. **Auto-shutdown** during off-peak hours
3. **Reserved instances** for long-term servers
4. **Storage optimization** - delete old backups
5. **Monitor usage** with CloudWatch/Azure Monitor

## Monitoring and Alerting

### Prometheus Integration

The metrics endpoint at `/metrics` provides:
- Active server count by provider
- Deployment success/failure rates
- Resource utilization
- Backup status

### Grafana Dashboard (Example)

```yaml
# grafana-dashboard.json (excerpt)
{
  "panels": [
    {
      "title": "Servers by Provider",
      "targets": [{
        "expr": "sum by (provider) (mineclifford_servers_by_status)"
      }]
    },
    {
      "title": "Cloud vs Local Deployments",
      "targets": [{
        "expr": "rate(mineclifford_server_operations_total[5m])"
      }]
    }
  ]
}
```

## Troubleshooting

### Common Issues

1. **Terraform fails to initialize**
   - Check provider credentials
   - Verify Terraform version compatibility

2. **Ansible connection timeout**
   - Verify SSH key permissions (chmod 600)
   - Check security group allows port 22
   - Confirm instance is running

3. **Server not accessible**
   - Check security group port 25565
   - Verify server is running: `docker ps`
   - Check server logs: `docker logs minecraft_<id>`

## References

- [Terraform AWS Provider Docs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Terraform Azure Provider Docs](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Ansible Docker Module](https://docs.ansible.com/ansible/latest/collections/community/docker/docker_container_module.html)
- [Minecraft Server Image (itzg)](https://github.com/itzg/docker-minecraft-server)
- [Current Implementation](../src/web/backend/services/deployment.py)

## Next Steps

To complete the cloud deployment implementation:

1. ✅ Review this documentation
2. ⬜ Implement `_run_terraform()` method
3. ⬜ Implement `_run_ansible()` method
4. ⬜ Create Terraform configurations for AWS/Azure
5. ⬜ Create Ansible playbooks
6. ⬜ Add frontend provider/region selection
7. ⬜ Test with AWS/Azure accounts
8. ⬜ Implement multi-region support
9. ⬜ Add cost estimation API
10. ⬜ Set up monitoring and alerting
