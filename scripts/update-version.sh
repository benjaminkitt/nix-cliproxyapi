#!/usr/bin/env bash
# Script to update CLIProxyAPI version and compute new hashes
set -euo pipefail

NEW_VERSION="${1:-}"

if [ -z "$NEW_VERSION" ]; then
    echo "Usage: $0 <version>"
    echo "Example: $0 6.6.109"
    exit 1
fi

echo "Updating to version: $NEW_VERSION"

# Define platforms
declare -A PLATFORMS=(
    ["x86_64-linux"]="linux_amd64"
    ["aarch64-linux"]="linux_arm64"
    ["x86_64-darwin"]="darwin_amd64"
    ["aarch64-darwin"]="darwin_arm64"
)

# Compute hashes for each platform
declare -A HASHES

for nixSystem in "${!PLATFORMS[@]}"; do
    asset="${PLATFORMS[$nixSystem]}"
    url="https://github.com/router-for-me/CLIProxyAPI/releases/download/v${NEW_VERSION}/CLIProxyAPI_${NEW_VERSION}_${asset}.tar.gz"

    echo "Fetching hash for $nixSystem ($asset)..."

    # Use nix-prefetch-url to get the hash
    rawHash=$(nix-prefetch-url --type sha256 "$url" 2>/dev/null)
    hash=$(nix hash convert --hash-algo sha256 --to sri "$rawHash" 2>/dev/null || nix hash to-sri --type sha256 "$rawHash" 2>/dev/null)

    if [ -z "$hash" ]; then
        echo "Error: Failed to fetch hash for $nixSystem"
        exit 1
    fi

    HASHES["$nixSystem"]="$hash"
    echo "  $nixSystem: $hash"
done

echo ""
echo "Updating flake.nix..."

# Update version
sed -i 's/version = "[^"]*"/version = "'"${NEW_VERSION}"'"/' flake.nix

# Update hashes using a different approach - use | as delimiter and escape properly
for nixSystem in "${!HASHES[@]}"; do
    hash="${HASHES[$nixSystem]}"
    # Use perl for more reliable replacement
    perl -i -pe "s|\"${nixSystem}\" = \"sha256-[^\"]*\"|\"${nixSystem}\" = \"${hash}\"|" flake.nix
done

echo "Done! Updated flake.nix to version $NEW_VERSION"
echo ""
echo "Changes:"
grep -A 6 "hashes = {" flake.nix
