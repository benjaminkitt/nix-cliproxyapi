#!/usr/bin/env bash
# Script to update CLIProxyAPI edition version and compute new hashes
set -euo pipefail

EDITION="${1:-}"
NEW_VERSION="${2:-}"

# Edition metadata (must match flake.nix editions attrset)
declare -A REPOS=(
    ["cliproxyapi"]="router-for-me/CLIProxyAPI"
    ["cliproxyapi-plus"]="router-for-me/CLIProxyAPIPlus"
    ["cliproxyapi-business"]="router-for-me/CLIProxyAPIBusiness"
)

declare -A ARCHIVE_PREFIXES=(
    ["cliproxyapi"]="CLIProxyAPI"
    ["cliproxyapi-plus"]="CLIProxyAPIPlus"
    ["cliproxyapi-business"]="cpab"
)

# Usage help
if [ -z "$EDITION" ] || [ -z "$NEW_VERSION" ]; then
    echo "Usage: $0 <edition> <version>"
    echo ""
    echo "Editions:"
    echo "  cliproxyapi          - Base CLIProxyAPI"
    echo "  cliproxyapi-plus     - CLIProxyAPI Plus edition"
    echo "  cliproxyapi-business - CLIProxyAPI Business edition"
    echo ""
    echo "Example: $0 cliproxyapi-plus 6.6.68-0"
    exit 1
fi

# Validate edition
if [[ ! -v "REPOS[$EDITION]" ]]; then
    echo "Error: Unknown edition '$EDITION'"
    echo "Valid editions: ${!REPOS[*]}"
    exit 1
fi

REPO="${REPOS[$EDITION]}"
ARCHIVE_PREFIX="${ARCHIVE_PREFIXES[$EDITION]}"

echo "Updating $EDITION to version: $NEW_VERSION"

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
    url="https://github.com/${REPO}/releases/download/v${NEW_VERSION}/${ARCHIVE_PREFIX}_${NEW_VERSION}_${asset}.tar.gz"

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

# Update version within the specific edition block using multiline perl
# The /s modifier allows . to match newlines
# Use environment variables to avoid shell escaping issues with version strings
export EDITION NEW_VERSION
perl -i -0pe 's/($ENV{EDITION} = \{[^}]*?)version = "[^"]*"/$1version = "$ENV{NEW_VERSION}"/s' flake.nix

# Update each hash within the specific edition block
# Match both quoted strings ("sha256-...") and Nix expressions (nixpkgs.lib.fakeHash)
for nixSystem in "${!HASHES[@]}"; do
    hash="${HASHES[$nixSystem]}"
    export nixSystem hash
    perl -i -0pe 's/($ENV{EDITION} = \{.*?hashes = \{.*?)"$ENV{nixSystem}" = [^;]+;/$1"$ENV{nixSystem}" = "$ENV{hash}";/s' flake.nix
done

echo "Done! Updated flake.nix $EDITION to version $NEW_VERSION"
echo ""
echo "Changes for $EDITION:"
grep -A 10 "${EDITION} = {" flake.nix | head -11
