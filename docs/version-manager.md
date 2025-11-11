# Mineclifford Version Manager

## Overview

The Version Manager is a dynamic system for managing Minecraft server versions across multiple server types (Vanilla, Paper, Spigot, Forge, Fabric, and more). It replaces hardcoded version strings with API-driven version resolution, making it easy to:

- Query available versions for any server type
- Automatically get the latest version
- Validate version compatibility
- Get download URLs for specific versions
- Compare versions across server types

## Features

### Supported Server Types

- **Vanilla**: Official Minecraft servers from Mojang
- **Paper**: High-performance Paper servers (PaperMC)
- **Spigot**: Spigot servers (requires BuildTools)
- **Forge**: Modded servers with Forge
- **Fabric**: Modded servers with Fabric
- **Purpur**: Enhanced Paper fork (planned)
- **Velocity**: Modern proxy server (planned)
- **BungeeCord**: Classic proxy server (planned)

### Key Capabilities

1. **Dynamic Version Resolution**: Query real-time version information from official APIs
2. **Version Validation**: Verify that a version exists before deploying
3. **Ansible Integration**: Generate Ansible variables automatically
4. **CLI Tool**: Command-line interface for version management
5. **Caching**: Built-in caching to reduce API calls

## Installation

### Prerequisites

```bash
# Python 3.8 or higher
python3 --version

# Install dependencies
pip install -r requirements.txt

# Or install in development mode
pip install -e .
```

### Ansible Collections

```bash
# Install required Ansible collections
ansible-galaxy collection install -r deployment/ansible/requirements.yml
```

## Usage

### Command Line Interface

The Version Manager provides a `mineclifford-version` command:

#### List Available Versions

```bash
# List Paper versions for Minecraft 1.20.1
mineclifford-version list paper --mc-version 1.20.1

# List all available Vanilla versions
mineclifford-version list vanilla

# List Fabric versions
mineclifford-version list fabric
```

#### Get Latest Version

```bash
# Get latest Paper version
mineclifford-version latest paper

# Get latest Vanilla for specific MC version
mineclifford-version latest vanilla --mc-version 1.20.1
```

#### Get Download URL (CLI)

```bash
# Get download URL for Paper 1.20.1-196
mineclifford-version download paper 1.20.1-196

# Get download URL for Vanilla 1.21.4
mineclifford-version download vanilla 1.21.4
```

#### Validate Version

```bash
# Validate that a version exists
mineclifford-version validate paper 1.20.1-196

# Check if version is valid
mineclifford-version validate vanilla 1.21.4
```

#### Compare Versions

```bash
# Compare versions across all server types for MC 1.20.1
mineclifford-version compare 1.20.1
```

#### Search Versions

```bash
# Search for versions matching "1.20"
mineclifford-version search 1.20

# Search only in Paper
mineclifford-version search 1.20 --type paper
```

#### List Server Types

```bash
# Show all supported server types
mineclifford-version types
```

### Ansible Integration

The Ansible integration script generates Ansible-compatible variable files:

#### Generate Ansible Variables

```bash
# Generate vars for latest Paper
python3 src/ansible_integration.py generate \
  --java-type paper \
  --output deployment/ansible/minecraft_vars.yml

# Generate with specific version
python3 src/ansible_integration.py generate \
  --java-type paper \
  --java-version 1.20.1-196 \
  --java-memory 4G \
  --java-gamemode survival \
  --java-difficulty hard \
  -o deployment/ansible/minecraft_vars.yml

# Generate with Bedrock enabled
python3 src/ansible_integration.py generate \
  --java-type paper \
  --bedrock \
  --bedrock-version latest \
  -o deployment/ansible/minecraft_vars.yml
```

#### List Versions (Ansible-friendly)

```bash
# List available Paper versions
python3 src/ansible_integration.py list paper

# List with custom limit
python3 src/ansible_integration.py list fabric --limit 20
```

#### Resolve Version

```bash
# Resolve "latest" to concrete version
python3 src/ansible_integration.py resolve paper latest

# Validate specific version
python3 src/ansible_integration.py resolve vanilla 1.21.4
```

#### Get Download URL

```bash
# Get download URL for Ansible
python3 src/ansible_integration.py url paper 1.20.1-196
```

### Python API

You can also use the Version Manager in your own Python scripts:

```python
import asyncio
from version_manager import MinecraftVersionManager
from version_manager.base import ServerType

async def main():
    manager = MinecraftVersionManager()

    # List versions
    versions = await manager.list_versions(ServerType.PAPER, "1.20.1")
    for v in versions:
        print(f"{v.version} - {v.minecraft_version}")

    # Get latest version
    latest = await manager.get_latest_version(ServerType.PAPER)
    print(f"Latest Paper: {latest.version}")

    # Get download URL
    url = await manager.get_download_url(ServerType.PAPER, "1.20.1-196")
    print(f"Download from: {url}")

    # Validate version
    is_valid = await manager.validate_version(ServerType.PAPER, "1.20.1-196")
    print(f"Valid: {is_valid}")

    # Compare versions across server types
    comparison = await manager.compare_versions("1.20.1")
    for server_type, version_info in comparison.items():
        print(f"{server_type.value}: {version_info.version}")

if __name__ == "__main__":
    asyncio.run(main())
```

## Integration with Existing Workflow

### Updating `minecraft_vars.yml`

Instead of manually editing `deployment/ansible/minecraft_vars.yml`, use the generator:

```bash
# Old way (manual edit)
# minecraft_java_version: "latest"

# New way (generated)
python3 src/ansible_integration.py generate \
  --java-type paper \
  --java-version latest \
  -o deployment/ansible/minecraft_vars.yml
```

### Use in Deployment Scripts

Update your deployment scripts to use the Version Manager:

```bash
#!/bin/bash

# Generate fresh Ansible vars with latest versions
python3 src/ansible_integration.py generate \
  --java-type paper \
  --java-memory 4G \
  -o deployment/ansible/minecraft_vars.yml

# Run Ansible playbook
ansible-playbook -i inventory deployment/ansible/swarm_setup.yml
```

## Version Lock File

All dependencies are locked in [versions.lock](../versions.lock) to ensure reproducible deployments:

```toml
[terraform]
version = "1.10.3"

[terraform.providers.aws]
version = "5.82.2"

[python.packages]
aiohttp = "3.9.1"
tabulate = "0.9.0"

[minecraft.defaults.java]
vanilla = "1.21.4"
paper = "1.21.4"
```

### Updating Locked Versions

To update a locked version:

1. Test the new version in a staging environment
2. Update `versions.lock`
3. Run integration tests
4. Commit changes with clear message

```bash
# Example: Update Paper default version
# Edit versions.lock:
# [minecraft.defaults.java]
# paper = "1.21.5"

# Test deployment
./minecraft-ops.sh deploy --provider aws --orchestration swarm

# If successful, commit
git add versions.lock
git commit -m "chore: update Paper default to 1.21.5"
```

## API Endpoints

The Version Manager uses official APIs from each server type:

- **Vanilla**: `https://launchermeta.mojang.com/mc/game/version_manifest.json`
- **Paper**: `https://papermc.io/api/v2/projects/paper`
- **Forge**: `https://files.minecraftforge.net/net/minecraftforge/forge/promotions_slim.json`
- **Fabric**: `https://meta.fabricmc.net/v2/versions`
- **Spigot**: BuildTools (no direct API)

## Architecture

```plaintext
src/version_manager/
├── __init__.py          # Package initialization
├── base.py              # Base classes and types
├── providers.py         # Provider implementations
├── manager.py           # Main manager class
└── cli.py              # CLI interface

src/
└── ansible_integration.py  # Ansible integration script
```

### Provider Pattern

Each server type implements the `BaseProvider` interface:

```python
class BaseProvider(ABC):
    @abstractmethod
    async def list_versions(self, minecraft_version: Optional[str] = None) -> List[VersionInfo]:
        pass

    @abstractmethod
    async def get_latest_version(self, minecraft_version: Optional[str] = None) -> VersionInfo:
        pass

    @abstractmethod
    async def get_download_url(self, version: str) -> str:
        pass

    @abstractmethod
    async def validate_version(self, version: str) -> bool:
        pass
```

## Troubleshooting

### API Connection Issues

If you get connection errors:

```bash
# Test API connectivity
curl https://papermc.io/api/v2/projects/paper
curl https://launchermeta.mojang.com/mc/game/version_manifest.json
```

### Version Not Found

If a version is not found:

1. List available versions: `mineclifford-version list <type>`
2. Check the version format (e.g., Paper uses `1.20.1-196`)
3. Verify the version exists on the official API

### Import Errors

If you get import errors:

```bash
# Reinstall dependencies
pip install -r requirements.txt

# Or install in editable mode
pip install -e .
```

## Examples

### Example 1: Deploy Latest Paper

```bash
# Generate vars
python3 src/ansible_integration.py generate \
  --java-type paper \
  --java-version latest \
  -o deployment/ansible/minecraft_vars.yml

# Deploy
./minecraft-ops.sh deploy --provider aws --orchestration swarm
```

### Example 2: Deploy Specific Forge Version

```bash
# List Forge versions
mineclifford-version list forge --mc-version 1.20.1

# Generate vars with specific version
python3 src/ansible_integration.py generate \
  --java-type forge \
  --java-version 1.20.1-47.3.0 \
  -o deployment/ansible/minecraft_vars.yml
```

### Example 3: Compare Versions

```bash
# Compare all server types for MC 1.20.1
mineclifford-version compare 1.20.1
```

Output:

```plaintext
Version comparison for Minecraft 1.20.1:
╒═══════════════╤══════════════╤══════════╤═════════╕
│ Server Type   │ Version      │ Stable   │ Build   │
╞═══════════════╪══════════════╪══════════╪═════════╡
│ VANILLA       │ 1.20.1       │ Yes      │ N/A     │
├───────────────┼──────────────┼──────────┼─────────┤
│ PAPER         │ 1.20.1-196   │ Yes      │ 196     │
├───────────────┼──────────────┼──────────┼─────────┤
│ FABRIC        │ 1.20.1-0.15.0│ Yes      │ N/A     │
├───────────────┼──────────────┼──────────┼─────────┤
│ FORGE         │ 1.20.1-47.3.0│ Yes      │ N/A     │
╘═══════════════╧══════════════╧══════════╧═════════╛
```

## Contributing

When adding a new server type provider:

1. Create a new class inheriting from `BaseProvider`
2. Implement all abstract methods
3. Add to `providers.py`
4. Register in `MinecraftVersionManager.__init__()`
5. Add tests
6. Update documentation

## Future Enhancements

- [ ] Add Purpur support
- [ ] Add Velocity/BungeeCord support
- [ ] Add caching layer with TTL
- [ ] Add webhook notifications for new versions
- [ ] Add version comparison with changelogs
- [ ] Add GUI interface
- [ ] Add Docker integration
- [ ] Add automatic security patch detection

## References

- [Paper API Documentation](https://papermc.io/api/docs/)
- [Fabric Meta API](https://meta.fabricmc.net/)
- [Forge Downloads](https://files.minecraftforge.net/)
- [Mojang Version Manifest](https://launchermeta.mojang.com/mc/game/version_manifest.json)
