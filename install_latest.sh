#!/bin/bash
# Seahorse Installer - Downloads the latest Seahorse DMG from GitHub

set -e

REPO_OWNER="SSBun"
REPO_NAME="Seahorse"
APP_NAME="Seahorse"

echo "Fetching latest release from GitHub..."

# Try GitHub API first
RELEASE_JSON=$(curl -sL "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/releases/latest" 2>/dev/null)

if echo "$RELEASE_JSON" | grep -q "browser_download_url"; then
    # API worked - extract DMG URL
    DMG_URL=$(echo "$RELEASE_JSON" | grep -o '"browser_download_url" *: *"[^"]*\.dmg"' | grep -v sha256 | head -1 | sed 's/.*"browser_download_url" *: *"\([^"]*\)".*/\1/')
else
    # Fallback: Use GitHub redirect to get latest tag
    LATEST_URL=$(curl -sL "https://github.com/$REPO_OWNER/$REPO_NAME/releases/latest" -w "%{url_effective}" -o /dev/null)
    TAG=$(echo "$LATEST_URL" | sed 's/.*\/tag\///')
    VERSION=$(echo "$TAG" | sed 's/^v//')
    DMG_URL="https://github.com/$REPO_OWNER/$REPO_NAME/releases/download/$TAG/$APP_NAME-$VERSION.dmg"
fi

if [ -z "$DMG_URL" ]; then
    echo "Error: Could not find DMG file"
    echo "Please download manually from: https://github.com/$REPO_OWNER/$REPO_NAME/releases"
    exit 1
fi

# Extract version from URL
DMG_VERSION=$(echo "$DMG_URL" | sed 's/.*\(Seahorse-[0-9.]*\.dmg\).*/\1/')

# Download to Downloads folder
DOWNLOADS_DIR="$HOME/Downloads"
DMG_PATH="$DOWNLOADS_DIR/$DMG_VERSION"

echo "Downloading: $DMG_URL"
curl -sL "$DMG_URL" -o "$DMG_PATH"

echo "Opening DMG file..."
open "$DMG_PATH"

echo ""
echo "Installation Steps:"
echo "1. Drag Seahorse.app to your Applications folder"
echo "2. If macOS shows 'Seahorse is damaged' error, run:"
echo "   xattr -rd com.apple.quarantine /Applications/Seahorse.app"
echo ""
echo "Download complete: $DMG_PATH"
