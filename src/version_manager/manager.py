"""
Main manager class for Minecraft version operations.
"""

from typing import Optional, List, Dict
from .base import BaseProvider, VersionInfo, ServerType
from .providers import (
    VanillaProvider,
    PaperProvider,
    SpigotProvider,
    ForgeProvider,
    FabricProvider
)


class MinecraftVersionManager:
    """
    Central manager for all Minecraft server version operations.

    This class provides a unified interface to query, validate, and download
    different Minecraft server types and versions.

    Example:
        >>> manager = MinecraftVersionManager()
        >>> versions = await manager.list_versions(ServerType.PAPER, "1.20.1")
        >>> latest = await manager.get_latest_version(ServerType.PAPER)
        >>> url = await manager.get_download_url(ServerType.PAPER, "1.20.1-196")
    """

    def __init__(self):
        """Initialize the version manager with all providers."""
        self.providers: Dict[ServerType, BaseProvider] = {
            ServerType.VANILLA: VanillaProvider(),
            ServerType.PAPER: PaperProvider(),
            ServerType.SPIGOT: SpigotProvider(),
            ServerType.FORGE: ForgeProvider(),
            ServerType.FABRIC: FabricProvider(),
        }

    def get_provider(self, server_type: ServerType) -> BaseProvider:
        """
        Get the provider for a specific server type.

        Args:
            server_type: The server type to get the provider for

        Returns:
            BaseProvider instance for the server type

        Raises:
            ValueError: If server type is not supported
        """
        provider = self.providers.get(server_type)
        if not provider:
            raise ValueError(f"Unsupported server type: {server_type}")
        return provider

    async def list_versions(
        self,
        server_type: ServerType,
        minecraft_version: Optional[str] = None
    ) -> List[VersionInfo]:
        """
        List available versions for a server type.

        Args:
            server_type: The type of server to query
            minecraft_version: Optional specific Minecraft version to filter by

        Returns:
            List of VersionInfo objects

        Example:
            >>> versions = await manager.list_versions(ServerType.PAPER, "1.20.1")
        """
        provider = self.get_provider(server_type)
        return await provider.list_versions(minecraft_version)

    async def get_latest_version(
        self,
        server_type: ServerType,
        minecraft_version: Optional[str] = None
    ) -> VersionInfo:
        """
        Get the latest version for a server type.

        Args:
            server_type: The type of server to query
            minecraft_version: Optional specific Minecraft version

        Returns:
            VersionInfo for the latest version

        Example:
            >>> latest = await manager.get_latest_version(ServerType.PAPER)
            >>> print(f"Latest Paper: {latest.version}")
        """
        provider = self.get_provider(server_type)
        return await provider.get_latest_version(minecraft_version)

    async def get_download_url(
        self,
        server_type: ServerType,
        version: str
    ) -> str:
        """
        Get the download URL for a specific version.

        Args:
            server_type: The type of server
            version: The version string

        Returns:
            Download URL as a string

        Example:
            >>> url = await manager.get_download_url(ServerType.PAPER, "1.20.1-196")
            >>> print(f"Download from: {url}")
        """
        provider = self.get_provider(server_type)
        return await provider.get_download_url(version)

    async def validate_version(
        self,
        server_type: ServerType,
        version: str
    ) -> bool:
        """
        Validate if a version exists and is available.

        Args:
            server_type: The type of server
            version: The version string to validate

        Returns:
            True if version is valid, False otherwise

        Example:
            >>> is_valid = await manager.validate_version(ServerType.PAPER, "1.20.1-196")
        """
        provider = self.get_provider(server_type)
        return await provider.validate_version(version)

    async def get_all_server_types(self) -> List[ServerType]:
        """
        Get a list of all supported server types.

        Returns:
            List of ServerType enums
        """
        return list(self.providers.keys())

    def clear_cache(self, server_type: Optional[ServerType] = None):
        """
        Clear cached data for providers.

        Args:
            server_type: Optional specific server type to clear cache for.
                        If None, clears all caches.
        """
        if server_type:
            provider = self.get_provider(server_type)
            provider.clear_cache()
        else:
            for provider in self.providers.values():
                provider.clear_cache()

    async def search_versions(
        self,
        query: str,
        server_type: Optional[ServerType] = None
    ) -> List[VersionInfo]:
        """
        Search for versions matching a query string.

        Args:
            query: Search query (e.g., "1.20", "1.19.4")
            server_type: Optional server type to limit search to

        Returns:
            List of matching VersionInfo objects

        Example:
            >>> results = await manager.search_versions("1.20", ServerType.PAPER)
        """
        results = []

        if server_type:
            server_types = [server_type]
        else:
            server_types = list(self.providers.keys())

        for st in server_types:
            try:
                versions = await self.list_versions(st)
                matching = [
                    v for v in versions
                    if query.lower() in v.minecraft_version.lower()
                    or query.lower() in v.version.lower()
                ]
                results.extend(matching)
            except Exception:
                # Skip providers that fail
                continue

        return results

    async def compare_versions(
        self,
        minecraft_version: str
    ) -> Dict[ServerType, VersionInfo]:
        """
        Compare available versions across all server types for a Minecraft version.

        Args:
            minecraft_version: The Minecraft version to compare (e.g., "1.20.1")

        Returns:
            Dictionary mapping server types to their latest version info

        Example:
            >>> comparison = await manager.compare_versions("1.20.1")
            >>> for server_type, info in comparison.items():
            ...     print(f"{server_type.value}: {info.version}")
        """
        comparison = {}

        for server_type in self.providers.keys():
            try:
                version_info = await self.get_latest_version(
                    server_type,
                    minecraft_version
                )
                if version_info:
                    comparison[server_type] = version_info
            except Exception:
                # Skip providers that don't support this version
                continue

        return comparison
