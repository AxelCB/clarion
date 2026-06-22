# Clarion

A minimal macOS notification tool built as a proper `.app` bundle. Posts native macOS notifications via `UNUserNotificationCenter` with a custom icon and correct app attribution in System Settings > Notifications.

Designed to be called from shell scripts — accepts arguments directly or reads structured JSON from stdin.

## Build

```bash
swift test --disable-sandbox
swift run --disable-sandbox clarion-package bundle
swift run --disable-sandbox clarion-package sign
```

For a local install:

```bash
swift run --disable-sandbox clarion-package install
```

## Icon Variants

Shipped icon families live under [`Clarion.app/Contents/Resources`](/Users/axel.collardbovy/Developer/personal/clarion/Clarion.app/Contents/Resources):

- `AppIcon-dark.*`
- `AppIcon-light.*`
- `AppIcon-tinted.*`

To rebuild the bundle using one of the shipped variants:

```bash
swift run --disable-sandbox clarion-package all --icon-variant dark
swift run --disable-sandbox clarion-package all --icon-variant light
swift run --disable-sandbox clarion-package all --icon-variant tinted
```

To rebuild using a custom PNG source instead of the default icon:

```bash
swift run --disable-sandbox clarion-package all \
  --icon-source claude-vscode-dark-1024.png
```

If the source image is a square render with non-transparent corners, apply a rounded alpha mask during generation:

```bash
swift run --disable-sandbox clarion-package all \
  --icon-source clarion-logo-tinted-1024.png \
  --rounded-mask 216
```

To produce a separately installable bundle with a different app name and bundle identifier:

```bash
swift run --disable-sandbox clarion-package all \
  --icon-source claude-vscode-dark-icon-source.png \
  --bundle-id com.axelcollardbovy.clarion-vscode \
  --app-name ClarionVSCode
```

That produces `ClarionVSCode.app` in the package root with a patched `Info.plist`, while keeping the executable name `clarion`.

## Usage

### Direct flags

```bash
/Applications/Clarion.app/Contents/MacOS/clarion \
  --title "✅ Vault" \
  --message "Finished" \
  --sound "Tink"
```

### JSON from stdin

```bash
echo '{"title":"⚠️ App Dev","message":"needs permission: run xcodebuild","sound":"default"}' \
  | /Applications/Clarion.app/Contents/MacOS/clarion
```

## Why

- `osascript` notifications are attributed to Script Editor — no custom icon
- `terminal-notifier -sender` hangs indefinitely on modern macOS when the target app isn't running (confirmed unfixed bug)
- Clarion is a real `.app` bundle using the proper modern notification API — no hacks, no hanging

## Identity

A modern heraldic insignia emerging from noise and darkness, symbolizing important information becoming clear, visible, and worthy of attention.

See [DESIGN.md](DESIGN.md) for the full design rationale and asset reference.
