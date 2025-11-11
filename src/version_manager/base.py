"""
Base classes for Minecraft server version providers.
"""

from abc import ABC, abstractmethod
from typing import List, Dict, Optional
from dataclasses import dataclass
from enum import Enum


class ServerType(Enum):
    """Supported Minecraft server types."""
    VANILLA = "vanilla"
    PAPER = "paper"
    SPIGOT = "spigot"
    FORGE = "forge"
    FABRIC = "fabric"
    PURPUR = "purpur"
    VELOCITY = "velocity"
    BUNGEECORD = "bungeecord"


@dataclass
class VersionInfo:
    """Information about a Minecraft server version."""
    version: str
    server_type: ServerType
    minecraft_version: str
    download_url: Optional[str] = None
    build_number: Optional[int] = None
    release_date: Optional[str] = None
    stable: bool = True
    experimental: bool = False

    def __str__(self) -> str:
        return f"{self.server_type.value}-{self.minecraft_version}"


class BaseProvider(ABC):
    """Base class for all Minecraft server version providers."""

    def __init__(self):
        self.server_type: ServerType = None
        self._cache: Dict[str, List[VersionInfo]] = {}

    @abstractmethod
    async def list_versions(self, minecraft_version: Optional[str] = None) -> List[VersionInfo]:
        """
        List available versions for this server type.

        Args:
            minecraft_version: Optional specific Minecraft version to filter by

        Returns:
            List of VersionInfo objects
        """
        pass

    @abstractmethod
    async def get_latest_version(self, minecraft_version: Optional[str] = None) -> VersionInfo:
        """
        Get the latest version for this server type.

        Args:
            minecraft_version: Optional specific Minecraft version

        Returns:
            VersionInfo for the latest version
        """
        pass

    @abstractmethod
    async def get_download_url(self, version: str) -> str:
        """
        Get the download URL for a specific version.

        Args:
            version: The version string or build number

        Returns:
            Download URL as a string
        """
        pass

    @abstractmethod
    async def validate_version(self, version: str) -> bool:
        """
        Validate if a version exists and is available.

        Args:
            version: The version string to validate

        Returns:
            True if version is valid, False otherwise
        """
        pass

    def clear_cache(self):
        """Clear the internal cache."""
        self._cache.clear()
