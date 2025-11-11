"""
Mineclifford Version Manager
Manages Minecraft server versions dynamically across multiple server types.
"""

from .manager import MinecraftVersionManager
from .providers import (
    VanillaProvider,
    PaperProvider,
    SpigotProvider,
    ForgeProvider,
    FabricProvider
)

__version__ = "1.0.0"
__all__ = [
    "MinecraftVersionManager",
    "VanillaProvider",
    "PaperProvider",
    "SpigotProvider",
    "ForgeProvider",
    "FabricProvider"
]
