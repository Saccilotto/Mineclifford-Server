# Changelog

All notable changes to Mineclifford will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2025-11-11

### Added

#### Version Manager System

- **Dynamic Version Management**: New Python-based system for managing Minecraft server versions
  - Support for Vanilla, Paper, Spigot, Forge, and Fabric server types
  - Real-time version queries from official APIs
  - Version validation and comparison across server types
  - Download URL resolution for all server types

- **CLI Tool**: `mineclifford-version` command-line interface
  - List available versions for any server type
  - Get latest versions automatically
  - Validate version compatibility
  - Search and compare versions
  - Get download URLs

- **Ansible Integration**: `ansible_integration.py` script
  - Generate Ansible variables from Version Manager
  - Automatic version resolution
  - Configurable server settings
  - Support for both Java and Bedrock editions

- **Version Lock File**: `versions.lock`
  - Centralized dependency management
  - Locked versions for reproducible deployments
  - Clear update policy and schedule
  - Includes Terraform, Ansible, Python, Docker, and Kubernetes versions

#### Infrastructure Updates

- **Terraform Version**: Updated to 1.10.3
  - AWS Provider: Updated to 5.x (from 3.x)
  - Azure Provider: Updated to 4.x (from 2.x)
  - TLS Provider: Updated to 4.x (from 3.x)
  - Required Terraform version: >= 1.10.0

- **Ansible Improvements**
  - Replaced shell commands with native Ansible modules
  - Added `community.docker` collection for Docker operations
  - Improved portability across target systems
  - Better idempotency and error handling

- **Python Dependencies**
  - Added `aiohttp` for async HTTP operations
  - Added `tabulate` for CLI formatting
  - Added `PyYAML` for YAML processing
  - Added `typing-extensions` for type hints

### Changed

- **Deployment Process**: Version selection now happens via Version Manager instead of hardcoded values
- **Ansible Playbook**: Refactored to use native Docker modules instead of shell commands
- **Docker Setup**: Improved using `ansible.builtin.get_url` and `ansible.builtin.apt_repository`
- **Swarm Management**: Migrated to `community.docker.docker_swarm` module
- **IP Address Resolution**: Using `ansible_default_ipv4.address` instead of shell commands

### Fixed

- **Ansible Portability**: Removed hardcoded shell commands that could fail on different systems
- **Version Specification**: No longer limited to "latest" for Minecraft versions
- **Terraform Compatibility**: Updated syntax for latest Terraform and provider versions

### Deprecated

- **Hardcoded Versions**: Direct version specification in `minecraft_vars.yml` (use Version Manager instead)
- **Shell Commands in Ansible**: Raw shell commands for Docker/Swarm operations (use native modules)

### Documentation

- Added comprehensive [Version Manager Guide](docs/version-manager.md)
- Created [CHANGELOG.md](CHANGELOG.md) for version tracking
- Updated README with Version Manager usage
- Added inline documentation in all Python modules

## [1.0.0] - 2024-XX-XX

### Changed features

- Initial release
- Multi-cloud support (AWS and Azure)
- Multiple orchestration options (Docker Swarm, Kubernetes, local Docker)
- Support for Java and Bedrock Minecraft servers
- Terraform-based infrastructure provisioning
- Ansible-based configuration management
- Integrated monitoring with Prometheus and Grafana
- Automated backup system
- State management across providers
- Comprehensive documentation

---

## Migration Guide: 1.x to 2.0

### Prerequisites

1. Install Python dependencies:

   ```bash
   pip install -r requirements.txt
   ```

2. Install Ansible collections:

   ```bash
   ansible-galaxy collection install -r deployment/ansible/requirements.yml
   ```

3. Update Terraform:

   ```bash
   # Install Terraform 1.10.3 or later
   terraform version
   ```

### Breaking Changes

#### 1. Terraform Provider Versions

**Before (1.x)**:

```hcl
terraform {
  required_version = ">= 0.13"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.0"
    }
  }
}
```

**After (2.0)**:

```hcl
terraform {
  required_version = ">= 1.10.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```

**Action Required**:

- Update to Terraform 1.10+
- Run `terraform init -upgrade` to update providers

#### 2. Minecraft Version Specification

**Before (1.x)**:

```yaml
# deployment/ansible/minecraft_vars.yml
minecraft_java_version: "latest"
```

**After (2.0)**:

```bash
# Generate vars using Version Manager
python3 src/ansible_integration.py generate \
  --java-type paper \
  --java-version latest \
  -o deployment/ansible/minecraft_vars.yml
```

**Action Required**:

- Use Version Manager to generate variable files
- Replace manual edits with generated configs

#### 3. Ansible Collections

**New Requirement**:

```yaml
# deployment/ansible/requirements.yml
collections:
  - name: community.docker
    version: ">=3.4.0"
```

**Action Required**:

```bash
ansible-galaxy collection install -r deployment/ansible/requirements.yml
```

### Recommended Upgrade Steps

1. **Backup existing infrastructure**:

   ```bash
   terraform state pull > terraform-state-backup.json
   ```

2. **Update Terraform**:

   ```bash
   cd terraform/aws  # or terraform/azure
   terraform init -upgrade
   terraform plan  # Review changes
   ```

3. **Install Python dependencies**:

   ```bash
   pip install -r requirements.txt
   pip install -e .  # Install Version Manager
   ```

4. **Install Ansible collections**:

   ```bash
   ansible-galaxy collection install -r deployment/ansible/requirements.yml
   ```

5. **Test Version Manager**:

   ```bash
   mineclifford-version types
   mineclifford-version latest paper
   ```

6. **Generate new Ansible variables**:

   ```bash
   python3 src/ansible_integration.py generate \
     --java-type paper \
     --java-version latest \
     -o deployment/ansible/minecraft_vars.yml
   ```

7. **Test deployment in staging**:

   ```bash
   ./minecraft-ops.sh deploy --provider aws --orchestration swarm
   ```

8. **Verify everything works**:

   ```bash
   ./minecraft-ops.sh status --provider aws
   ```

### Rollback Plan

If you need to rollback to 1.x:

1. **Restore Terraform state**:

   ```bash
   terraform state push terraform-state-backup.json
   ```

2. **Checkout 1.x branch**:

   ```bash
   git checkout v1.x
   ```

3. **Downgrade Terraform providers** (if needed):

   ```bash
   terraform init -upgrade
   ```

---

## Future Roadmap

### Version 2.1 (Q1 2025)

- Web UI for server management
- Plugin marketplace integration
- Automated performance tuning
- Multi-server proxy support (Velocity/BungeeCord)

### Version 2.2 (Q2 2025)

- Disaster recovery automation
- Multi-region failover
- Player analytics dashboard
- Cost optimization recommendations

### Version 3.0 (Q3-Q4 2025)

- Community marketplace
- White-label options
- Advanced scheduling
- Machine learning for resource optimization

---

For detailed information about any version, see the corresponding release notes on GitHub.
