"""
Concrete implementations of version providers for different Minecraft server types.
"""

import aiohttp
import re
from typing import List, Optional
from .base import BaseProvider, VersionInfo, ServerType


class VanillaProvider(BaseProvider):
    """Provider for vanilla Minecraft servers from Mojang."""

    MANIFEST_URL = "https://launchermeta.mojang.com/mc/game/version_manifest.json"

    def __init__(self):
        super().__init__()
        self.server_type = ServerType.VANILLA

    async def list_versions(self, minecraft_version: Optional[str] = None) -> List[VersionInfo]:
        """List available vanilla Minecraft versions."""
        async with aiohttp.ClientSession() as session:
            async with session.get(self.MANIFEST_URL) as response:
                data = await response.json()

                versions = []
                for version in data['versions']:
                    if minecraft_version and version['id'] != minecraft_version:
                        continue

                    versions.append(VersionInfo(
                        version=version['id'],
                        server_type=self.server_type,
                        minecraft_version=version['id'],
                        release_date=version['releaseTime'],
                        stable=version['type'] == 'release',
                        experimental=version['type'] == 'snapshot'
                    ))

                return versions

    async def get_latest_version(self, minecraft_version: Optional[str] = None) -> VersionInfo:
        """Get the latest vanilla version."""
        async with aiohttp.ClientSession() as session:
            async with session.get(self.MANIFEST_URL) as response:
                data = await response.json()
                latest = data['latest']['release']

                for version in data['versions']:
                    if version['id'] == latest:
                        return VersionInfo(
                            version=latest,
                            server_type=self.server_type,
                            minecraft_version=latest,
                            release_date=version['releaseTime'],
                            stable=True
                        )

    async def get_download_url(self, version: str) -> str:
        """Get download URL for a specific vanilla version."""
        async with aiohttp.ClientSession() as session:
            async with session.get(self.MANIFEST_URL) as response:
                data = await response.json()

                for v in data['versions']:
                    if v['id'] == version:
                        async with session.get(v['url']) as version_response:
                            version_data = await version_response.json()
                            return version_data['downloads']['server']['url']

                raise ValueError(f"Version {version} not found")

    async def validate_version(self, version: str) -> bool:
        """Validate if a vanilla version exists."""
        versions = await self.list_versions()
        return any(v.version == version for v in versions)


class PaperProvider(BaseProvider):
    """Provider for Paper (PaperMC) servers."""

    BASE_URL = "https://papermc.io/api/v2"
    PROJECT = "paper"

    def __init__(self):
        super().__init__()
        self.server_type = ServerType.PAPER

    async def list_versions(self, minecraft_version: Optional[str] = None) -> List[VersionInfo]:
        """List available Paper versions."""
        async with aiohttp.ClientSession() as session:
            url = f"{self.BASE_URL}/projects/{self.PROJECT}"
            async with session.get(url) as response:
                data = await response.json()

                versions = []
                for version in data['versions']:
                    if minecraft_version and version != minecraft_version:
                        continue

                    # Get builds for this version
                    builds_url = f"{self.BASE_URL}/projects/{self.PROJECT}/versions/{version}"
                    async with session.get(builds_url) as builds_response:
                        builds_data = await builds_response.json()
                        latest_build = builds_data['builds'][-1] if builds_data['builds'] else None

                        if latest_build:
                            versions.append(VersionInfo(
                                version=f"{version}-{latest_build}",
                                server_type=self.server_type,
                                minecraft_version=version,
                                build_number=latest_build,
                                stable=True
                            ))

                return versions

    async def get_latest_version(self, minecraft_version: Optional[str] = None) -> VersionInfo:
        """Get the latest Paper version."""
        async with aiohttp.ClientSession() as session:
            url = f"{self.BASE_URL}/projects/{self.PROJECT}"
            async with session.get(url) as response:
                data = await response.json()

                if minecraft_version:
                    latest_mc_version = minecraft_version
                else:
                    latest_mc_version = data['versions'][-1]

                # Get latest build for this version
                builds_url = f"{self.BASE_URL}/projects/{self.PROJECT}/versions/{latest_mc_version}"
                async with session.get(builds_url) as builds_response:
                    builds_data = await builds_response.json()
                    latest_build = builds_data['builds'][-1]

                    return VersionInfo(
                        version=f"{latest_mc_version}-{latest_build}",
                        server_type=self.server_type,
                        minecraft_version=latest_mc_version,
                        build_number=latest_build,
                        stable=True
                    )

    async def get_download_url(self, version: str) -> str:
        """Get download URL for a specific Paper version."""
        # Parse version string (format: 1.20.1-123)
        match = re.match(r"(.+)-(\d+)", version)
        if not match:
            raise ValueError(f"Invalid Paper version format: {version}")

        mc_version, build_num = match.groups()

        async with aiohttp.ClientSession() as session:
            builds_url = f"{self.BASE_URL}/projects/{self.PROJECT}/versions/{mc_version}/builds/{build_num}"
            async with session.get(builds_url) as response:
                data = await response.json()
                download_name = data['downloads']['application']['name']

                return f"{self.BASE_URL}/projects/{self.PROJECT}/versions/{mc_version}/builds/{build_num}/downloads/{download_name}"

    async def validate_version(self, version: str) -> bool:
        """Validate if a Paper version exists."""
        try:
            await self.get_download_url(version)
            return True
        except (ValueError, aiohttp.ClientError):
            return False


class SpigotProvider(BaseProvider):
    """Provider for Spigot servers."""

    def __init__(self):
        super().__init__()
        self.server_type = ServerType.SPIGOT

    async def list_versions(self, minecraft_version: Optional[str] = None) -> List[VersionInfo]:
        """
        List available Spigot versions.
        Note: Spigot requires building from source, so we return common versions.
        """
        # Common stable Minecraft versions that work with Spigot
        common_versions = [
            "1.20.4", "1.20.3", "1.20.2", "1.20.1", "1.20",
            "1.19.4", "1.19.3", "1.19.2", "1.19.1", "1.19",
            "1.18.2", "1.18.1", "1.18",
            "1.17.1", "1.17",
            "1.16.5", "1.16.4", "1.16.3", "1.16.2", "1.16.1",
            "1.15.2", "1.14.4", "1.13.2", "1.12.2", "1.8.8"
        ]

        versions = []
        for version in common_versions:
            if minecraft_version and version != minecraft_version:
                continue

            versions.append(VersionInfo(
                version=version,
                server_type=self.server_type,
                minecraft_version=version,
                stable=True
            ))

        return versions

    async def get_latest_version(self, minecraft_version: Optional[str] = None) -> VersionInfo:
        """Get the latest Spigot version."""
        versions = await self.list_versions(minecraft_version)
        return versions[0] if versions else None

    async def get_download_url(self, version: str) -> str:
        """
        Spigot requires building from source.
        Returns the BuildTools URL instead.
        """
        return "https://hub.spigotmc.org/jenkins/job/BuildTools/lastSuccessfulBuild/artifact/target/BuildTools.jar"

    async def validate_version(self, version: str) -> bool:
        """Validate if a Spigot version is supported."""
        versions = await self.list_versions()
        return any(v.version == version for v in versions)


class ForgeProvider(BaseProvider):
    """Provider for Forge servers."""

    MAVEN_METADATA_URL = "https://files.minecraftforge.net/net/minecraftforge/forge/maven-metadata.json"
    PROMOTIONS_URL = "https://files.minecraftforge.net/net/minecraftforge/forge/promotions_slim.json"

    def __init__(self):
        super().__init__()
        self.server_type = ServerType.FORGE

    async def list_versions(self, minecraft_version: Optional[str] = None) -> List[VersionInfo]:
        """List available Forge versions."""
        async with aiohttp.ClientSession() as session:
            async with session.get(self.PROMOTIONS_URL) as response:
                data = await response.json()

                versions = []
                promos = data.get('promos', {})

                for key, value in promos.items():
                    if '-recommended' in key or '-latest' in key:
                        mc_version = key.replace('-recommended', '').replace('-latest', '')

                        if minecraft_version and mc_version != minecraft_version:
                            continue

                        versions.append(VersionInfo(
                            version=value,
                            server_type=self.server_type,
                            minecraft_version=mc_version,
                            stable='-recommended' in key
                        ))

                return versions

    async def get_latest_version(self, minecraft_version: Optional[str] = None) -> VersionInfo:
        """Get the latest Forge version."""
        versions = await self.list_versions(minecraft_version)
        # Prefer recommended versions
        recommended = [v for v in versions if v.stable]
        return recommended[0] if recommended else versions[0] if versions else None

    async def get_download_url(self, version: str) -> str:
        """Get download URL for a specific Forge version."""
        # Forge URL format: https://maven.minecraftforge.net/net/minecraftforge/forge/{version}/forge-{version}-installer.jar
        return f"https://maven.minecraftforge.net/net/minecraftforge/forge/{version}/forge-{version}-installer.jar"

    async def validate_version(self, version: str) -> bool:
        """Validate if a Forge version exists."""
        try:
            async with aiohttp.ClientSession() as session:
                url = await self.get_download_url(version)
                async with session.head(url) as response:
                    return response.status == 200
        except aiohttp.ClientError:
            return False


class FabricProvider(BaseProvider):
    """Provider for Fabric servers."""

    BASE_URL = "https://meta.fabricmc.net/v2"

    def __init__(self):
        super().__init__()
        self.server_type = ServerType.FABRIC

    async def list_versions(self, minecraft_version: Optional[str] = None) -> List[VersionInfo]:
        """List available Fabric versions."""
        async with aiohttp.ClientSession() as session:
            # Get Fabric loader versions
            async with session.get(f"{self.BASE_URL}/versions/loader") as loader_response:
                loader_data = await loader_response.json()
                latest_loader = loader_data[0]['version'] if loader_data else None

            # Get Minecraft versions
            async with session.get(f"{self.BASE_URL}/versions/game") as game_response:
                game_data = await game_response.json()

                versions = []
                for game in game_data:
                    if not game.get('stable', True):
                        continue

                    if minecraft_version and game['version'] != minecraft_version:
                        continue

                    versions.append(VersionInfo(
                        version=f"{game['version']}-{latest_loader}",
                        server_type=self.server_type,
                        minecraft_version=game['version'],
                        stable=game.get('stable', True)
                    ))

                return versions

    async def get_latest_version(self, minecraft_version: Optional[str] = None) -> VersionInfo:
        """Get the latest Fabric version."""
        versions = await self.list_versions(minecraft_version)
        return versions[0] if versions else None

    async def get_download_url(self, version: str) -> str:
        """Get download URL for Fabric."""
        # Parse version (format: 1.20.1-0.14.21)
        match = re.match(r"(.+)-(.+)", version)
        if not match:
            raise ValueError(f"Invalid Fabric version format: {version}")

        mc_version, loader_version = match.groups()

        # Get installer version
        async with aiohttp.ClientSession() as session:
            async with session.get(f"{self.BASE_URL}/versions/installer") as response:
                installer_data = await response.json()
                installer_version = installer_data[0]['version'] if installer_data else "latest"

        return f"https://meta.fabricmc.net/v2/versions/loader/{mc_version}/{loader_version}/{installer_version}/server/jar"

    async def validate_version(self, version: str) -> bool:
        """Validate if a Fabric version exists."""
        try:
            await self.get_download_url(version)
            return True
        except (ValueError, aiohttp.ClientError):
            return False
