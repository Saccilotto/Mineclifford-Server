#!/usr/bin/env python3
"""
Examples of using the Mineclifford Version Manager API.

Run with: python3 examples/version-manager-examples.py
"""

import asyncio
import sys
from pathlib import Path

# Add src to path
sys.path.insert(0, str(Path(__file__).parent.parent / "src"))

from version_manager import MinecraftVersionManager
from version_manager.base import ServerType


async def example_1_list_versions():
    """Example 1: List available versions for Paper."""
    print("=" * 60)
    print("Example 1: List Paper versions for Minecraft 1.20.1")
    print("=" * 60)

    manager = MinecraftVersionManager()
    versions = await manager.list_versions(ServerType.PAPER, "1.20.1")

    print(f"\nFound {len(versions)} versions:")
    for v in versions[:5]:  # Show first 5
        print(f"  - {v.version} (MC: {v.minecraft_version}, Build: {v.build_number})")

    if len(versions) > 5:
        print(f"  ... and {len(versions) - 5} more")

    print()


async def example_2_get_latest():
    """Example 2: Get the latest version for different server types."""
    print("=" * 60)
    print("Example 2: Get latest versions")
    print("=" * 60)

    manager = MinecraftVersionManager()

    server_types = [ServerType.VANILLA, ServerType.PAPER, ServerType.FABRIC]

    for server_type in server_types:
        try:
            latest = await manager.get_latest_version(server_type)
            print(f"\n{server_type.value.upper()}:")
            print(f"  Version: {latest.version}")
            print(f"  Minecraft: {latest.minecraft_version}")
            print(f"  Stable: {latest.stable}")
        except Exception as e:
            print(f"\n{server_type.value.upper()}: Error - {e}")

    print()


async def example_3_get_download_url():
    """Example 3: Get download URLs for specific versions."""
    print("=" * 60)
    print("Example 3: Get download URLs")
    print("=" * 60)

    manager = MinecraftVersionManager()

    # Get latest Paper version first
    latest_paper = await manager.get_latest_version(ServerType.PAPER)

    # Get download URL
    url = await manager.get_download_url(ServerType.PAPER, latest_paper.version)

    print(f"\nPaper {latest_paper.version}:")
    print(f"  URL: {url}")

    # Get Vanilla URL
    latest_vanilla = await manager.get_latest_version(ServerType.VANILLA)
    url = await manager.get_download_url(ServerType.VANILLA, latest_vanilla.version)

    print(f"\nVanilla {latest_vanilla.version}:")
    print(f"  URL: {url}")

    print()


async def example_4_validate_version():
    """Example 4: Validate if versions exist."""
    print("=" * 60)
    print("Example 4: Validate versions")
    print("=" * 60)

    manager = MinecraftVersionManager()

    # Test versions
    test_cases = [
        (ServerType.PAPER, "1.20.1-196"),
        (ServerType.VANILLA, "1.21.4"),
        (ServerType.PAPER, "invalid-version-999"),
    ]

    for server_type, version in test_cases:
        is_valid = await manager.validate_version(server_type, version)
        status = "✓ Valid" if is_valid else "✗ Invalid"
        print(f"\n{server_type.value.upper()} {version}: {status}")

    print()


async def example_5_compare_versions():
    """Example 5: Compare versions across server types."""
    print("=" * 60)
    print("Example 5: Compare versions for Minecraft 1.20.1")
    print("=" * 60)

    manager = MinecraftVersionManager()

    comparison = await manager.compare_versions("1.20.1")

    print("\nAvailable server types for Minecraft 1.20.1:")
    for server_type, version_info in comparison.items():
        print(f"\n{server_type.value.upper()}:")
        print(f"  Version: {version_info.version}")
        print(f"  Stable: {version_info.stable}")
        if version_info.build_number:
            print(f"  Build: {version_info.build_number}")

    print()


async def example_6_search_versions():
    """Example 6: Search for versions matching a query."""
    print("=" * 60)
    print("Example 6: Search for versions matching '1.20'")
    print("=" * 60)

    manager = MinecraftVersionManager()

    # Search across all server types
    results = await manager.search_versions("1.20")

    print(f"\nFound {len(results)} results:")

    # Group by server type
    by_type = {}
    for result in results:
        if result.server_type not in by_type:
            by_type[result.server_type] = []
        by_type[result.server_type].append(result)

    for server_type, versions in by_type.items():
        print(f"\n{server_type.value.upper()} ({len(versions)} versions):")
        for v in versions[:3]:  # Show first 3
            print(f"  - {v.version}")
        if len(versions) > 3:
            print(f"  ... and {len(versions) - 3} more")

    print()


async def example_7_practical_deployment():
    """Example 7: Practical deployment scenario."""
    print("=" * 60)
    print("Example 7: Practical deployment scenario")
    print("=" * 60)

    manager = MinecraftVersionManager()

    # Scenario: Deploy a Paper server with latest version
    print("\n1. Getting latest Paper version...")
    latest = await manager.get_latest_version(ServerType.PAPER)
    print(f"   Latest: {latest.version}")

    print("\n2. Validating version...")
    is_valid = await manager.validate_version(ServerType.PAPER, latest.version)
    print(f"   Valid: {is_valid}")

    if is_valid:
        print("\n3. Getting download URL...")
        url = await manager.get_download_url(ServerType.PAPER, latest.version)
        print(f"   URL: {url}")

        print("\n4. Deployment configuration:")
        print(f"   Server Type: Paper")
        print(f"   Version: {latest.version}")
        print(f"   Minecraft: {latest.minecraft_version}")
        print(f"   Build: {latest.build_number}")
        print(f"   Download: {url}")

        print("\n5. Ready to deploy!")
        print("   Use this configuration in your Ansible vars:")
        print(f"""
   minecraft_java_type: paper
   minecraft_java_version: {latest.version}
   minecraft_java_download_url: {url}
        """)

    print()


async def main():
    """Run all examples."""
    print("\n")
    print("╔══════════════════════════════════════════════════════════╗")
    print("║     Mineclifford Version Manager - Examples             ║")
    print("╚══════════════════════════════════════════════════════════╝")
    print()

    try:
        await example_1_list_versions()
        await example_2_get_latest()
        await example_3_get_download_url()
        await example_4_validate_version()
        await example_5_compare_versions()
        await example_6_search_versions()
        await example_7_practical_deployment()

        print("=" * 60)
        print("All examples completed successfully!")
        print("=" * 60)
        print()

    except KeyboardInterrupt:
        print("\n\nExamples interrupted by user.")
    except Exception as e:
        print(f"\n\nError running examples: {e}")
        import traceback
        traceback.print_exc()


if __name__ == "__main__":
    asyncio.run(main())
