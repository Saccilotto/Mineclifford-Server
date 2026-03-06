# Mod Support

Deploy modded Minecraft servers using Forge, Fabric, or NeoForge mod loaders. Mods are auto-downloaded from [Modrinth](https://modrinth.com) at container startup.

## How It Works

The `itzg/minecraft-server` Docker image handles mod loading natively:

1. `--server-type` sets `TYPE` (e.g. `FABRIC`) — the image installs the mod loader automatically
2. `--mods` sets `MODRINTH_PROJECTS` — the image downloads matching mod versions from Modrinth on startup
3. `--mod-deps` sets `MODRINTH_DOWNLOAD_DEPENDENCIES` — auto-fetches transitive dependencies like Fabric API
4. On container restart, mods removed from the list are auto-cleaned from the `mods/` directory

No manual jar downloads, no volume-mounting mod files — just declare what you want.

## CLI Flags

| Flag | Description | Default |
| ---- | ----------- | ------- |
| `--server-type TYPE` | `VANILLA`, `FORGE`, `FABRIC`, `NEOFORGE`, `PAPER` | `VANILLA` |
| `--mods PROJECTS` | Comma-separated [Modrinth](https://modrinth.com) project slugs | — |
| `--mod-deps LEVEL` | `none`, `required`, `optional` | `required` |
| `--mod-loader-version VER` | Pin a specific loader version | latest |

## Mod Loaders

| Loader | `--server-type` | Use when |
| ------ | --------------- | -------- |
| **Fabric** | `FABRIC` | Lightweight, fast startup. Most modern mods target Fabric. |
| **Forge** | `FORGE` | Legacy ecosystem, largest mod library historically. |
| **NeoForge** | `NEOFORGE` | Community fork of Forge (1.20.1+), growing ecosystem. |
| **Paper** | `PAPER` | Plugin server (Bukkit/Spigot plugins, not mods). Not for Fabric/Forge mods. |

## Create Mod

[Create](https://modrinth.com/mod/create) is a mechanical/automation mod for building conveyor belts, gearboxes, trains, and industrial contraptions.

### Compatibility Matrix

| Variant | Loaders | Mod Slug | Latest MC Version | Mod Version |
| ------- | ------- | -------- | ----------------- | ----------- |
| Create (original) | Forge, NeoForge | `create` | **1.20.1** | 6.0.8 |
| Create Fabric (port) | Fabric, Quilt | `create-fabric` | **1.20.1** | 6.0.8.1 |

**Version constraint**: Create does **not** support Minecraft 1.21.x. You must pin `--minecraft-version 1.20.1`.

### Dependencies

- **Fabric path**: `fabric-api` is required (auto-resolved with `--mod-deps required`)
- **Forge path**: No external dependencies (Flywheel is bundled since 0.5.1)
- **Recommended**: A recipe viewer mod (`jei`, `rei`, or `emi`) for browsing Create recipes in-game

### Deploy Create (Fabric) — Local

```bash
./minecraft-ops.sh deploy --orchestration local \
  --server-type FABRIC \
  --mods "create-fabric,fabric-api" \
  --minecraft-version 1.20.1
```

### Deploy Create (Fabric) — AWS Kubernetes

```bash
./minecraft-ops.sh deploy --provider aws --orchestration kubernetes \
  --server-type FABRIC \
  --mods "create-fabric,fabric-api" \
  --minecraft-version 1.20.1 \
  --memory 4G --region sa-east-2
```

### Deploy Create (Forge) — AWS Swarm

```bash
./minecraft-ops.sh deploy --provider aws --orchestration swarm \
  --server-type FORGE \
  --mods "create" \
  --minecraft-version 1.20.1 \
  --memory 4G
```

### Deploy Create with Recipe Viewer

```bash
./minecraft-ops.sh deploy --orchestration local \
  --server-type FABRIC \
  --mods "create-fabric,fabric-api,roughly-enough-items" \
  --minecraft-version 1.20.1
```

## More Examples

### Multiple Mods

Comma-separate Modrinth project slugs:

```bash
./minecraft-ops.sh deploy --orchestration local \
  --server-type FABRIC \
  --mods "create-fabric,fabric-api,sodium,lithium,iris" \
  --minecraft-version 1.20.1
```

### Pin Loader Version

```bash
./minecraft-ops.sh deploy --orchestration local \
  --server-type FABRIC \
  --mods "create-fabric,fabric-api" \
  --minecraft-version 1.20.1 \
  --mod-loader-version 0.16.10
```

### Forge Server

```bash
./minecraft-ops.sh deploy --orchestration local \
  --server-type FORGE \
  --mods "create,jei" \
  --minecraft-version 1.20.1
```

### NeoForge Server

```bash
./minecraft-ops.sh deploy --orchestration local \
  --server-type NEOFORGE \
  --mods "create" \
  --minecraft-version 1.20.1
```

## Modrinth Project Slugs

The `--mods` flag accepts Modrinth **project slugs** — the URL-friendly name from the mod's Modrinth page. For example:

| Mod | Modrinth URL | Slug |
| --- | ------------ | ---- |
| Create Fabric | `modrinth.com/mod/create-fabric` | `create-fabric` |
| Create (Forge) | `modrinth.com/mod/create` | `create` |
| Fabric API | `modrinth.com/mod/fabric-api` | `fabric-api` |
| Sodium | `modrinth.com/mod/sodium` | `sodium` |
| JEI | `modrinth.com/mod/jei` | `jei` |
| REI | `modrinth.com/mod/roughly-enough-items` | `roughly-enough-items` |

You can also use Modrinth project IDs instead of slugs.

### Version Pinning

Append a colon and version to pin a specific mod version:

```text
create-fabric:6.0.8.1,fabric-api:0.92.2+1.20.1
```

Or use release channels:

```text
create-fabric:release,fabric-api:release
```

## Helm Chart

When deploying via Helm, configure mods in `values.yaml`:

```yaml
javaEdition:
  server:
    type: FABRIC
  mods:
    modrinthProjects: "create-fabric,fabric-api"
    modrinthDownloadDeps: required
    modLoaderVersion: ""  # empty = latest
```

Or pass as overrides:

```bash
helm install minecraft deployment/helm/minecraft/ \
  --set javaEdition.server.type=FABRIC \
  --set javaEdition.mods.modrinthProjects="create-fabric,fabric-api"
```

## Ansible Variables

For Swarm deployments, mod settings are written to `deployment/ansible/minecraft_vars.yml`:

```yaml
minecraft_java_type: "FABRIC"
minecraft_java_version: "1.20.1"
minecraft_modrinth_projects: "create-fabric,fabric-api"
minecraft_modrinth_download_deps: "required"
minecraft_mod_loader_version: ""
```

These are passed through to the `stack.yml` Jinja2 template as Docker environment variables.

## Resource Recommendations

Modded servers use more RAM and CPU than vanilla. Adjust `--memory` and `--instance-type` accordingly:

| Setup | `--memory` | AWS `--instance-type` | Azure `--instance-type` |
| ----- | ---------- | --------------------- | ----------------------- |
| Vanilla (1-10 players) | 2G | t3.medium | Standard_B2s |
| Create + a few mods (1-10 players) | 4G | t3.large | Standard_B4ms |
| Heavy modpack (10+ mods, 10+ players) | 6-8G | t3.xlarge | Standard_B8ms |

## Troubleshooting

### Mod download fails at startup

Check the container logs for Modrinth API errors. Common causes:

- Typo in the project slug
- Mod doesn't have a version for your `--minecraft-version` + `--server-type` combination
- Modrinth API rate limiting (transient, retries on restart)

### Server crashes on startup with mods

- Verify mod compatibility with your Minecraft version. Create requires **1.20.1**.
- Check for missing dependencies — set `--mod-deps required` (default)
- Some mods are client-only and crash on dedicated servers. Check the mod's Modrinth page for "server" environment support.

### Fabric server but mods not loading

Ensure `fabric-api` is included in `--mods`. Most Fabric mods require it.

### Forge version mismatch

If a mod requires a specific Forge version, pin it:

```bash
--mod-loader-version 47.3.12
```
