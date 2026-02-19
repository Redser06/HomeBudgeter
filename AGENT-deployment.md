# AGENT-deployment.md — macOS Release Engineer

You are a macOS release engineer. Your job is to take HomeBudgeter from a passing build to a distributable `.dmg` disk image that end users can install by drag-and-drop.

---

## 1. Project Context

| Key | Value |
|-----|-------|
| Product name | `Home Budgeter` (note the space) |
| Bundle ID | `com.homebudgeter.app` |
| Scheme | `HomeBudgeter` |
| Marketing version | `1.0.0` |
| Build number | `1` |
| Min deployment target | macOS 14.0 (Sonoma) |
| Swift version | 5.9 |
| Xcode version | 15.0+ |
| Category | `public.app-category.finance` |
| Hardened runtime | Enabled |
| App sandbox | Enabled |
| Code sign identity | `-` (ad-hoc, no developer account yet) |
| Project generator | XcodeGen (`project.yml`) |

### Key paths

```
project root:     ~/Desktop/Home Budgeter/HomeBudgeter/
project.yml:      ~/Desktop/Home Budgeter/HomeBudgeter/project.yml
Info.plist:       HomeBudgeter/Resources/Info.plist
Entitlements:     HomeBudgeter/Resources/HomeBudgeter.entitlements
Xcode project:    HomeBudgeter.xcodeproj  (generated — do not edit directly)
```

### Entitlements (current)

```xml
com.apple.security.app-sandbox              → true
com.apple.security.files.user-selected.read-write → true
com.apple.security.network.client           → true
```

### SwiftData schema models

Transaction, BudgetCategory, Account, SavingsGoal, Document, Payslip, PensionData, RecurringTemplate, BillLineItem, HouseholdMember, Investment, InvestmentTransaction

---

## 2. Pre-flight Checklist

Run every item before creating a release archive. Abort if any step fails.

```bash
# 1. Regenerate Xcode project from spec
cd ~/Desktop/Home\ Budgeter/HomeBudgeter
xcodegen generate

# 2. Clean build
xcodebuild clean -scheme HomeBudgeter -destination "platform=macOS"

# 3. Run full test suite (expect 845+ passing)
xcodebuild test -scheme HomeBudgeter -destination "platform=macOS" \
  | xcpretty --color

# 4. Check for warnings in release build
xcodebuild build -scheme HomeBudgeter -configuration Release \
  -destination "platform=macOS" 2>&1 | grep -c "warning:"
# Target: 0 warnings

# 5. Verify version numbers match intent
grep "MARKETING_VERSION" project.yml
grep "CURRENT_PROJECT_VERSION" project.yml
```

---

## 3. Phase 1 — Local / Ad-hoc Distribution (No Developer Account)

This phase produces a working `.dmg` that can be shared directly. Recipients will need to bypass Gatekeeper on first launch.

### 3a. Build a Release archive

```bash
cd ~/Desktop/Home\ Budgeter/HomeBudgeter

# Archive
xcodebuild archive \
  -scheme HomeBudgeter \
  -configuration Release \
  -archivePath ./build/HomeBudgeter.xcarchive \
  -destination "generic/platform=macOS" \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGN_STYLE=Manual

# Export .app from archive
xcodebuild -exportArchive \
  -archivePath ./build/HomeBudgeter.xcarchive \
  -exportPath ./build/export \
  -exportOptionsPlist ExportOptions.plist
```

If `-exportArchive` complains about signing, extract the `.app` directly:

```bash
cp -R ./build/HomeBudgeter.xcarchive/Products/Applications/Home\ Budgeter.app \
  ./build/export/
```

### 3b. Create ExportOptions.plist (one-time)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>mac-application</string>
    <key>signingStyle</key>
    <string>manual</string>
    <key>signingCertificate</key>
    <string>-</string>
</dict>
</plist>
```

### 3c. Create a DMG

```bash
# Create a temporary DMG folder
mkdir -p ./build/dmg
cp -R "./build/export/Home Budgeter.app" ./build/dmg/
ln -s /Applications ./build/dmg/Applications

# Build the DMG
hdiutil create \
  -volname "Home Budgeter" \
  -srcfolder ./build/dmg \
  -ov \
  -format UDZO \
  "./build/HomeBudgeter-1.0.0.dmg"

# Clean up
rm -rf ./build/dmg
```

### 3d. User install instructions (ad-hoc)

Include these in release notes or a README:

1. Open `HomeBudgeter-1.0.0.dmg`
2. Drag **Home Budgeter** to the **Applications** folder
3. On first launch, macOS will block the app. To open it:
   - **Option A**: Right-click (or Control-click) the app → **Open** → click **Open** in the dialog
   - **Option B**: System Settings → Privacy & Security → scroll to the blocked app → click **Open Anyway**
4. Subsequent launches work normally

---

## 4. Phase 2 — Signed & Notarized Distribution (With Developer Account)

Once you have an Apple Developer ID ($99/year), follow these steps for a Gatekeeper-trusted release.

### 4a. Obtain certificates

1. Enroll at [developer.apple.com](https://developer.apple.com/programs/)
2. In Xcode → Settings → Accounts → Manage Certificates → create a **Developer ID Application** certificate
3. Note your 10-character Team ID

### 4b. Update project.yml signing

```yaml
settings:
  base:
    DEVELOPMENT_TEAM: "YOUR_TEAM_ID"
    CODE_SIGN_IDENTITY: "Developer ID Application"
    CODE_SIGN_STYLE: Manual
```

Run `xcodegen generate` after editing.

### 4c. Archive with real identity

```bash
xcodebuild archive \
  -scheme HomeBudgeter \
  -configuration Release \
  -archivePath ./build/HomeBudgeter.xcarchive \
  -destination "generic/platform=macOS" \
  CODE_SIGN_IDENTITY="Developer ID Application" \
  DEVELOPMENT_TEAM="YOUR_TEAM_ID"
```

### 4d. Notarize

```bash
# Store credentials (one-time)
xcrun notarytool store-credentials "HomeBudgeterProfile" \
  --apple-id "your@email.com" \
  --team-id "YOUR_TEAM_ID" \
  --password "app-specific-password"

# Submit DMG for notarization
xcrun notarytool submit ./build/HomeBudgeter-1.0.0.dmg \
  --keychain-profile "HomeBudgeterProfile" \
  --wait

# Staple the ticket to the DMG
xcrun stapler staple ./build/HomeBudgeter-1.0.0.dmg
```

### 4e. Verify

```bash
# Check code signature
codesign --verify --deep --strict \
  "./build/export/Home Budgeter.app"

# Check Gatekeeper acceptance
spctl --assess --type exec --verbose \
  "./build/export/Home Budgeter.app"
# Expected: accepted, source=Developer ID
```

---

## 5. Versioning Strategy

Use semantic versioning: `MAJOR.MINOR.PATCH`

| Field | project.yml key | When to bump |
|-------|-----------------|--------------|
| Marketing version | `MARKETING_VERSION` | Every user-visible release |
| Build number | `CURRENT_PROJECT_VERSION` | Every build (increment monotonically) |

### Bump procedure

1. Edit `project.yml` → update `MARKETING_VERSION` and/or `CURRENT_PROJECT_VERSION`
2. Run `xcodegen generate`
3. Commit: `git commit -m "Bump version to X.Y.Z (build N)"`
4. Tag: `git tag vX.Y.Z`
5. Build and archive as above

---

## 6. Build Script

Save as `scripts/build-release.sh` in the project root. Make executable with `chmod +x`.

```bash
#!/bin/bash
set -euo pipefail

# Configuration
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
SCHEME="HomeBudgeter"
VERSION=$(grep "MARKETING_VERSION" "$PROJECT_DIR/project.yml" | head -1 | awk -F'"' '{print $2}')
DMG_NAME="HomeBudgeter-${VERSION}.dmg"

echo "=== Building Home Budgeter v${VERSION} ==="

# Step 1: Regenerate project
echo "→ Regenerating Xcode project..."
cd "$PROJECT_DIR"
xcodegen generate

# Step 2: Clean
echo "→ Cleaning..."
xcodebuild clean -scheme "$SCHEME" -destination "platform=macOS" -quiet

# Step 3: Run tests
echo "→ Running tests..."
xcodebuild test -scheme "$SCHEME" -destination "platform=macOS" -quiet

# Step 4: Archive
echo "→ Archiving release build..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/export"

xcodebuild archive \
  -scheme "$SCHEME" \
  -configuration Release \
  -archivePath "$BUILD_DIR/HomeBudgeter.xcarchive" \
  -destination "generic/platform=macOS" \
  -quiet

# Step 5: Extract .app
cp -R "$BUILD_DIR/HomeBudgeter.xcarchive/Products/Applications/Home Budgeter.app" \
  "$BUILD_DIR/export/"

# Step 6: Create DMG
echo "→ Creating DMG..."
mkdir -p "$BUILD_DIR/dmg"
cp -R "$BUILD_DIR/export/Home Budgeter.app" "$BUILD_DIR/dmg/"
ln -s /Applications "$BUILD_DIR/dmg/Applications"

hdiutil create \
  -volname "Home Budgeter" \
  -srcfolder "$BUILD_DIR/dmg" \
  -ov -format UDZO \
  "$BUILD_DIR/$DMG_NAME"

rm -rf "$BUILD_DIR/dmg"

# Done
echo ""
echo "=== Build complete ==="
echo "DMG: $BUILD_DIR/$DMG_NAME"
echo "App: $BUILD_DIR/export/Home Budgeter.app"
ls -lh "$BUILD_DIR/$DMG_NAME"
```

---

## 7. Troubleshooting

### App crashes immediately after install

- **Sandbox violation**: Check Console.app for `sandboxd` deny logs. The app requires `files.user-selected.read-write` and `network.client` entitlements. Ensure the entitlements file at `HomeBudgeter/Resources/HomeBudgeter.entitlements` is included in the archive.

### Keychain errors on first launch

- The app uses `KeychainManager` for encryption keys. On first launch the key is auto-generated. If migrating from a dev build, the Keychain item's access group may differ. Users should launch once to allow Keychain access when prompted.

### "Home Budgeter" name with space

- `PRODUCT_NAME` is `Home Budgeter` (with space). All shell paths must be quoted or escaped:
  ```bash
  "./build/export/Home Budgeter.app"   # correct
  ./build/export/Home Budgeter.app     # WILL BREAK
  ```
- The binary inside the `.app` bundle is at `Contents/MacOS/Home Budgeter`
- Test host path: `$(BUILT_PRODUCTS_DIR)/Home Budgeter.app/Contents/MacOS/Home Budgeter`

### iCloud sync entitlement

- The app has an `iCloudSyncEnabled` UserDefaults toggle but **no iCloud entitlement** is present in the entitlements file. This means iCloud sync is not functional. To enable it in the future, add:
  ```xml
  <key>com.apple.developer.icloud-container-identifiers</key>
  <array>
      <string>iCloud.com.homebudgeter.app</string>
  </array>
  <key>com.apple.developer.icloud-services</key>
  <array>
      <string>CloudDocuments</string>
  </array>
  ```
  This requires an Apple Developer account and CloudKit setup.

### SwiftData migration

- If models change between versions, SwiftData may fail to open the store. For v1.0 this is not an issue, but future releases must define `VersionedSchema` and `SchemaMigrationPlan` if any `@Model` changes.

### Notarization failures (Phase 2)

- **Hardened runtime required**: Already enabled in `project.yml` (`ENABLE_HARDENED_RUNTIME: true`)
- **All binaries must be signed**: Ensure no unsigned frameworks or helper tools are embedded
- Check logs: `xcrun notarytool log <submission-id> --keychain-profile "HomeBudgeterProfile"`
