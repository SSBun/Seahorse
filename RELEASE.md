# Seahorse Release Checklist

## Pre-Release Checklist

### Build Verification
- [ ] Run a clean build: `xcodebuild -scheme Seahorse -configuration Release clean build`
- [ ] Verify the build succeeds without warnings
- [ ] Test the app launches correctly

### Version Update
- [ ] Update `MARKETING_VERSION` in `Seahorse.xcodeproj/project.pbxproj`
- [ ] Update `CURRENT_PROJECT_VERSION` in `Seahorse.xcodeproj/project.pbxproj`
- [ ] Update version in `AGENTS.md` if applicable

### Code Quality
- [ ] No TODO/FIXME comments in release code
- [ ] No debug print statements
- [ ] No hardcoded test data

### Testing
- [ ] Test on macOS 13.0+ (minimum supported version)
- [ ] Test all major features:
  - [ ] Add bookmark (URL)
  - [ ] Add image
  - [ ] Add text snippet
  - [ ] Category management
  - [ ] Tag management
  - [ ] Search functionality
  - [ ] Copy detection
  - [ ] Settings persistence

### Localization
- [ ] Verify all UI strings are localized (check `Localizable.xcstrings`)
- [ ] Test with different system languages

## Release Steps

### 1. Create Release Build
```bash
# Clean and build release
xcodebuild -scheme Seahorse -configuration Release clean build

# Or use Xcode:
# Product > Archive
```

### 2. Code Signing
- [ ] Ensure code signing is configured (Developer ID Application for distribution)
- [ ] Verify the app is signed correctly

### 3. Create DMG
```bash
# Create DMG using the app
hdiutil create -volname "Seahorse" -srcfolder "/path/to/Seahorse.app" -ov -format UDZO "Seahorse-vVERSION.dmg"

# Sign the DMG (if distributing outside App Store)
codesign --sign "Developer ID Application: Your Name" "Seahorse-vVERSION.dmg"

# Verify signature
codesign -vvv "Seahorse-vVERSION.dmg"
```

### 4. GitHub Release
1. Go to https://github.com/SSBun/Seahorse/releases
2. Click "Draft a new release"
3. Tag version: `vX.X.X` (e.g., `v1.0.0`)
4. Release title: `Seahorse vX.X.X`
5. Description: Include release notes and changes
6. Attach DMG file
7. Click "Publish release"

### 5. Post-Release
- [ ] Verify GitHub release is published
- [ ] Test download link works
- [ ] Update README if needed
- [ ] Announce to users (if applicable)

## Version Numbering

Follow [Semantic Versioning](https://semver.org/):
- **MAJOR**: Incompatible API changes
- **MINOR**: New functionality (backward compatible)
- **PATCH**: Bug fixes (backward compatible)

Example: `v1.2.3` (Major: 1, Minor: 2, Patch: 3)

## Release Notes Template

```markdown
## What's New in Seahorse vX.X.X

### New Features
- Feature 1
- Feature 2

### Improvements
- Improvement 1
- Improvement 2

### Bug Fixes
- Fix 1
- Fix 2

### Known Issues
- Issue 1 (workaround: ...)

## Download

Download the DMG from the [GitHub Releases](https://github.com/SSBun/Seahorse/releases) page.
```

## Troubleshooting

### Build Errors
- Clean build folder: `Cmd+Shift+K` in Xcode
- Delete DerivedData: `rm -rf ~/Library/Developer/Xcode/DerivedData`

### Code Signing Issues
- Check signing certificate is valid
- Ensure App ID matches the certificate
- Check entitlements file

### DMG Issues
- Verify DMG is not corrupted
- Check file permissions
- Test on a clean macOS installation
