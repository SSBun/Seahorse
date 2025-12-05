#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Building Seahorse...${NC}"

# Build the app
xcodebuild \
  -scheme Seahorse \
  -configuration Release \
  -derivedDataPath build \
  -destination 'platform=macOS' \
  clean build

# Find the built app
APP_PATH=$(find build -name "Seahorse.app" -type d | head -n 1)

if [ -z "$APP_PATH" ]; then
  echo -e "${RED}Error: Could not find built app${NC}"
  exit 1
fi

echo -e "${GREEN}App built at: $APP_PATH${NC}"

# Get version from tag or use default
VERSION=${1:-"dev"}
DMG_NAME="Seahorse-${VERSION}.dmg"

echo -e "${GREEN}Creating DMG: $DMG_NAME${NC}"

# Create temporary directory
TMP_DIR=$(mktemp -d)
cp -R "$APP_PATH" "$TMP_DIR/"

# Create Applications symlink for easy installation
ln -s /Applications "$TMP_DIR/Applications"

# Check if create-dmg is installed
if command -v create-dmg &> /dev/null; then
  echo -e "${GREEN}Using create-dmg...${NC}"
  create-dmg \
    --volname "Seahorse" \
    --window-pos 200 120 \
    --window-size 600 400 \
    --icon-size 100 \
    --icon "Seahorse.app" 175 190 \
    --hide-extension "Seahorse.app" \
    --app-drop-link 425 190 \
    --no-internet-enable \
    "$DMG_NAME" \
    "$TMP_DIR/" 2>/dev/null || true
else
  echo -e "${YELLOW}create-dmg not found, using hdiutil...${NC}"
  echo -e "${YELLOW}Install create-dmg with: brew install create-dmg${NC}"
  hdiutil create -volname "Seahorse" -srcfolder "$TMP_DIR" -ov -format UDZO "$DMG_NAME"
fi

# Clean up
rm -rf "$TMP_DIR"

# Calculate checksum
shasum -a 256 "$DMG_NAME" > "${DMG_NAME}.sha256"

echo -e "${GREEN}✓ DMG created: $DMG_NAME${NC}"
echo -e "${GREEN}✓ Checksum: ${NC}"
cat "${DMG_NAME}.sha256"

echo ""
echo -e "${GREEN}To test the DMG:${NC}"
echo -e "  1. Open $DMG_NAME"
echo -e "  2. Drag Seahorse to Applications"
echo -e "  3. Launch from Applications folder"

