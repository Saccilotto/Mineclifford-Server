#!/usr/bin/env python3
"""
Command-line interface for Minecraft Version Manager.
"""

import asyncio
import sys
import argparse
from typing import Optional
from tabulate import tabulate
from .manager import MinecraftVersionManager
from .base import ServerType


class VersionManagerCLI:
    """CLI interface for the Version Manager."""

    def __init__(self):
        self.manager = MinecraftVersionManager()

    async def list_versions(self, server_type: str, minecraft_version: Optional[str] = None):
        """List available versions for a server type."""
        try:
            st = ServerType(server_type.lower())
            versions = await self.manager.list_versions(st, minecraft_version)

            if not versions:
                print(f"No versions found for {server_type}")
                return

            table_data = []
            for v in versions[:20]:  # Limit to 20 results
                table_data.append([
                    v.version,
                    v.minecraft_version,
                    "Yes" if v.stable else "No",
                    "Yes" if v.experimental else "No",
                    v.release_date or "N/A"
                ])

            headers = ["Version", "MC Version", "Stable", "Experimental", "Release Date"]
            print(f"\nAvailable versions for {server_type.upper()}:")
            print(tabulate(table_data, headers=headers, tablefmt="grid"))

            if len(versions) > 20:
                print(f"\n... and {len(versions) - 20} more versions")

        except ValueError as e:
            print(f"Error: {e}")
            sys.exit(1)

    async def get_latest(self, server_type: str, minecraft_version: Optional[str] = None):
        """Get the latest version for a server type."""
        try:
            st = ServerType(server_type.lower())
            version = await self.manager.get_latest_version(st, minecraft_version)

            if not version:
                print(f"No version found for {server_type}")
                return

            print(f"\nLatest {server_type.upper()} version:")
            print(f"  Version: {version.version}")
            print(f"  Minecraft: {version.minecraft_version}")
            print(f"  Stable: {'Yes' if version.stable else 'No'}")
            if version.build_number:
                print(f"  Build: {version.build_number}")
            if version.release_date:
                print(f"  Released: {version.release_date}")

        except ValueError as e:
            print(f"Error: {e}")
            sys.exit(1)

    async def get_download_url(self, server_type: str, version: str):
        """Get the download URL for a specific version."""
        try:
            st = ServerType(server_type.lower())
            url = await self.manager.get_download_url(st, version)

            print(f"\nDownload URL for {server_type.upper()} {version}:")
            print(f"  {url}")

        except ValueError as e:
            print(f"Error: {e}")
            sys.exit(1)

    async def validate_version(self, server_type: str, version: str):
        """Validate if a version exists."""
        try:
            st = ServerType(server_type.lower())
            is_valid = await self.manager.validate_version(st, version)

            if is_valid:
                print(f"✓ Version {version} is valid for {server_type.upper()}")
            else:
                print(f"✗ Version {version} is NOT valid for {server_type.upper()}")
                sys.exit(1)

        except ValueError as e:
            print(f"Error: {e}")
            sys.exit(1)

    async def compare_versions(self, minecraft_version: str):
        """Compare versions across all server types."""
        comparison = await self.manager.compare_versions(minecraft_version)

        if not comparison:
            print(f"No versions found for Minecraft {minecraft_version}")
            return

        table_data = []
        for server_type, version_info in comparison.items():
            table_data.append([
                server_type.value.upper(),
                version_info.version,
                "Yes" if version_info.stable else "No",
                version_info.build_number or "N/A"
            ])

        headers = ["Server Type", "Version", "Stable", "Build"]
        print(f"\nVersion comparison for Minecraft {minecraft_version}:")
        print(tabulate(table_data, headers=headers, tablefmt="grid"))

    async def search_versions(self, query: str, server_type: Optional[str] = None):
        """Search for versions matching a query."""
        st = None
        if server_type:
            try:
                st = ServerType(server_type.lower())
            except ValueError:
                print(f"Error: Invalid server type '{server_type}'")
                sys.exit(1)

        results = await self.manager.search_versions(query, st)

        if not results:
            print(f"No versions found matching '{query}'")
            return

        table_data = []
        for v in results[:20]:
            table_data.append([
                v.server_type.value.upper(),
                v.version,
                v.minecraft_version,
                "Yes" if v.stable else "No"
            ])

        headers = ["Server Type", "Version", "MC Version", "Stable"]
        print(f"\nSearch results for '{query}':")
        print(tabulate(table_data, headers=headers, tablefmt="grid"))

        if len(results) > 20:
            print(f"\n... and {len(results) - 20} more results")

    def list_server_types(self):
        """List all supported server types."""
        print("\nSupported server types:")
        for server_type in ServerType:
            print(f"  - {server_type.value}")


def main():
    """Main CLI entry point."""
    parser = argparse.ArgumentParser(
        description="Minecraft Version Manager - Manage Minecraft server versions dynamically",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # List available Paper versions for MC 1.20.1
  %(prog)s list paper --mc-version 1.20.1

  # Get latest Paper version
  %(prog)s latest paper

  # Get download URL
  %(prog)s download paper 1.20.1-196

  # Validate a version
  %(prog)s validate paper 1.20.1-196

  # Compare versions across server types
  %(prog)s compare 1.20.1

  # Search for versions
  %(prog)s search 1.20 --type paper

  # List supported server types
  %(prog)s types
        """
    )

    subparsers = parser.add_subparsers(dest="command", help="Command to execute")

    # List command
    list_parser = subparsers.add_parser("list", help="List available versions")
    list_parser.add_argument("type", help="Server type (paper, vanilla, spigot, forge, fabric)")
    list_parser.add_argument("--mc-version", help="Specific Minecraft version")

    # Latest command
    latest_parser = subparsers.add_parser("latest", help="Get latest version")
    latest_parser.add_argument("type", help="Server type")
    latest_parser.add_argument("--mc-version", help="Specific Minecraft version")

    # Download command
    download_parser = subparsers.add_parser("download", help="Get download URL")
    download_parser.add_argument("type", help="Server type")
    download_parser.add_argument("version", help="Version string")

    # Validate command
    validate_parser = subparsers.add_parser("validate", help="Validate a version")
    validate_parser.add_argument("type", help="Server type")
    validate_parser.add_argument("version", help="Version string")

    # Compare command
    compare_parser = subparsers.add_parser("compare", help="Compare versions across server types")
    compare_parser.add_argument("mc_version", help="Minecraft version to compare")

    # Search command
    search_parser = subparsers.add_parser("search", help="Search for versions")
    search_parser.add_argument("query", help="Search query")
    search_parser.add_argument("--type", help="Limit to specific server type")

    # Types command
    subparsers.add_parser("types", help="List supported server types")

    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        sys.exit(1)

    cli = VersionManagerCLI()

    # Execute command
    if args.command == "list":
        asyncio.run(cli.list_versions(args.type, args.mc_version))
    elif args.command == "latest":
        asyncio.run(cli.get_latest(args.type, args.mc_version))
    elif args.command == "download":
        asyncio.run(cli.get_download_url(args.type, args.version))
    elif args.command == "validate":
        asyncio.run(cli.validate_version(args.type, args.version))
    elif args.command == "compare":
        asyncio.run(cli.compare_versions(args.mc_version))
    elif args.command == "search":
        asyncio.run(cli.search_versions(args.query, args.type))
    elif args.command == "types":
        cli.list_server_types()


if __name__ == "__main__":
    main()
