#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Building Seahorse...${NC}"

./scripts/build-mcp-helper.sh

# Optional: disable code signing (for CI)
NO_SIGN=${NO_SIGN:-0}
if [ "$NO_SIGN" = "1" ]; then
  echo -e "${YELLOW}Code signing disabled (NO_SIGN=1).${NC}"
  SIGNING_FLAGS=(CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" DEVELOPMENT_TEAM="")
else
  SIGNING_FLAGS=()
fi

# Build the app
xcodebuild \
  -scheme Seahorse \
  -configuration Release \
  -derivedDataPath build \
  -destination 'platform=macOS' \
  "${SIGNING_FLAGS[@]}" \
  clean build

# Find the built app
APP_PATH=$(find build -name "Seahorse.app" -type d | head -n 1)

if [ -z "$APP_PATH" ]; then
  echo -e "${RED}Error: Could not find built app${NC}"
  exit 1
fi

echo -e "${GREEN}App built at: $APP_PATH${NC}"

# Bundle the production MCP helper before copying and packaging the app.
HELPER_PATH="$APP_PATH/Contents/Resources/MCPHelper"
mkdir -p "$HELPER_PATH"
cp MCPHelper/package.json MCPHelper/package-lock.json "$HELPER_PATH/"
cp MCPHelper/PI_LICENSE "$HELPER_PATH/"
cp -R MCPHelper/dist "$HELPER_PATH/"

node -e '
const [major, minor] = process.versions.node.split(".").map(Number);
if (major < 22 || (major === 22 && minor < 19)) {
  console.error(`Node >=22.19.0 is required, found ${process.versions.node}`);
  process.exit(1);
}
'
NODE_RUNTIME=$(node -p 'process.execPath')
NODE_LICENSE="$(dirname "$NODE_RUNTIME")/../LICENSE"
if [ ! -f "$NODE_LICENSE" ]; then
  echo -e "${RED}Error: Node license was not found next to the runtime.${NC}"
  exit 1
fi
while IFS= read -r dependency; do
  case "$dependency" in
    /System/Library/*|/usr/lib/*) ;;
    *)
      echo -e "${RED}Error: Node runtime has a non-system dependency: $dependency${NC}"
      echo -e "${YELLOW}Use the standalone Node.js distribution to create a portable DMG.${NC}"
      exit 1
      ;;
  esac
done < <(otool -L "$NODE_RUNTIME" | tail -n +2 | awk '{print $1}')
cp "$NODE_RUNTIME" "$HELPER_PATH/node"
cp "$NODE_LICENSE" "$HELPER_PATH/NODE_LICENSE"
chmod +x "$HELPER_PATH/node"

npm ci --omit=dev --ignore-scripts --prefix "$HELPER_PATH"

if [ "$NO_SIGN" != "1" ]; then
  SIGNING_IDENTITY=$(codesign -dv --verbose=4 "$APP_PATH" 2>&1 | sed -n 's/^Authority=//p' | head -n 1)
  if [ -z "$SIGNING_IDENTITY" ]; then
    echo -e "${RED}Error: Could not determine app signing identity${NC}"
    exit 1
  fi
  codesign --force --sign "$SIGNING_IDENTITY" --timestamp=none "$HELPER_PATH/node"
  codesign \
    --force \
    --sign "$SIGNING_IDENTITY" \
    --preserve-metadata=identifier,entitlements,requirements,flags,runtime \
    --timestamp=none \
    "$APP_PATH"
  codesign --verify --deep --strict "$APP_PATH"
fi

# Get version from tag or use default
VERSION=${1:-"dev"}
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DIST_DIR="dist/Seahorse-${VERSION}_${TIMESTAMP}"
mkdir -p "$DIST_DIR"

# Copy build product to dist
cp -R "$APP_PATH" "$DIST_DIR/"
echo -e "${GREEN}Build product saved to: $DIST_DIR/Seahorse.app${NC}"

DMG_NAME="$DIST_DIR/Seahorse-${VERSION}.dmg"

echo -e "${GREEN}Creating DMG: $DMG_NAME${NC}"

# Create temporary directory
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT
cp -R "$APP_PATH" "$TMP_DIR/"

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
    "$TMP_DIR/"
else
  echo -e "${YELLOW}create-dmg not found, using hdiutil...${NC}"
  echo -e "${YELLOW}Install create-dmg with: brew install create-dmg${NC}"
  ln -s /Applications "$TMP_DIR/Applications"
  hdiutil create -volname "Seahorse" -srcfolder "$TMP_DIR" -ov -format UDZO "$DMG_NAME"
fi

if [ ! -f "$DMG_NAME" ]; then
  echo -e "${RED}Error: DMG was not created: $DMG_NAME${NC}"
  exit 1
fi

# Calculate checksum
shasum -a 256 "$DMG_NAME" > "${DIST_DIR}/${DMG_NAME##*/}.sha256"

echo -e "${GREEN}✓ DMG created: $DMG_NAME${NC}"
echo -e "${GREEN}✓ Checksum: ${NC}"
cat "${DIST_DIR}/${DMG_NAME##*/}.sha256"

echo ""
echo -e "${GREEN}To test the DMG:${NC}"
echo -e "  1. Open $DMG_NAME"
echo -e "  2. Drag Seahorse to Applications"
echo -e "  3. Launch from Applications folder"
