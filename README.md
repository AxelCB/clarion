# Clarion

A minimal macOS notification tool built as a proper `.app` bundle. Posts native macOS notifications via `UNUserNotificationCenter` with a custom icon and correct app attribution in System Settings > Notifications.

Designed to be called from shell scripts — accepts arguments directly or reads structured JSON from stdin.

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

## Name

A clarion is the instrument heralds used to make announcements. Fitting.
