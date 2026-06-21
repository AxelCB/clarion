# Clarion — Product Specification

## Purpose

Clarion is a generic macOS command-line notification tool built as a proper `.app` bundle. It posts native macOS notifications via `UNUserNotificationCenter` with correct app attribution and a custom icon — without the hanging and attribution issues of `terminal-notifier`.

It is intentionally generic: callers provide all notification content via arguments or stdin JSON. Clarion knows nothing about Claude Code or any specific application.

## Background

Existing tools fall short on modern macOS:

- `osascript` — no custom icon, attributed to Script Editor
- `terminal-notifier` — `-sender` flag hangs indefinitely on modern macOS when the target app isn't running (confirmed unfixed bug, unmerged fix PR)

Clarion solves this by being a real `.app` bundle using `UNUserNotificationCenter` directly.

## Functional Requirements

### Input modes

**Mode 1 — CLI flags (primary):**

```bash
clarion --title "✅ Vault" --message "Finished" --sound "Tink"
```

**Mode 2 — JSON from stdin:**

```json
{
  "title": "✅ Vault",
  "message": "Finished",
  "sound": "Tink",
  "subtitle": "skyscanner-vault",
  "group": "claude-sessions"
}
```

If both are provided, CLI flags take precedence over stdin JSON.

### Arguments

| Flag | Required | Description |
|---|---|---|
| `--title` | Yes (or via stdin) | Notification title |
| `--message` | Yes (or via stdin) | Notification body |
| `--subtitle` | No | Secondary line below title |
| `--sound` | No | Sound name (e.g. `Tink`, `Glass`, `default`). Defaults to `default`. |
| `--group` | No | Notification group ID — replaces any previous notification with the same group, preventing stacking |
| `--attachment` | No | Absolute path to an image file (.png/.jpg) shown as a small thumbnail in the notification body |

### Behaviour

- Posts the notification and exits immediately
- No Dock icon, no menu bar presence (`LSUIElement = true`)
- No interactive elements (no action buttons, no click handlers)
- If required fields are missing and stdin is empty → exit 0 silently
- If stdin JSON is malformed → fall back to CLI flags; if those are also missing → exit 0 silently
- Never print to stdout or stderr on success

## Non-Functional Requirements

- macOS 13+ (Ventura and later)
- Ad-hoc code signed (`codesign --sign -`) — no Apple Developer account required
- Delivered as a self-contained `.app` bundle
- Must appear in System Settings > Notifications as "Clarion"
- Callable from any shell script with no extra setup beyond placing the `.app` on disk

## Out of Scope

- No `-sender` flag or app identity borrowing
- No click-to-open URL or shell command execution on notification click
- No persistent background process or daemon
- No menu bar UI
- No Claude Code-specific logic — all caller-specific behaviour lives in the calling script
- No runtime icon override (macOS does not support this via `UNUserNotificationCenter`)

## Delivery

- `Clarion.app` — built app bundle, ad-hoc signed
- `Makefile` — targets: `build`, `sign`, `install`, `clean`
- The app must appear in System Settings > Notifications as "Clarion"

## Customising the icon

The app icon is baked into the bundle at build time. macOS does not support overriding the main notification icon at runtime — it always uses the app bundle's own icon.

To use a custom icon:

1. Replace `Clarion.app/Contents/Resources/AppIcon.icns` with your own `.icns` file
2. Optionally update `CFBundleName`, `CFBundleDisplayName`, and `CFBundleIdentifier` in `Info.plist` to match your use case
3. Run `make sign` to re-sign the bundle
4. Run `make install` to reinstall

To generate an `.icns` from a `.png`:

```bash
# Using sips and iconutil (built into macOS)
mkdir AppIcon.iconset
sips -z 16 16     icon.png --out AppIcon.iconset/icon_16x16.png
sips -z 32 32     icon.png --out AppIcon.iconset/icon_16x16@2x.png
sips -z 32 32     icon.png --out AppIcon.iconset/icon_32x32.png
sips -z 64 64     icon.png --out AppIcon.iconset/icon_32x32@2x.png
sips -z 128 128   icon.png --out AppIcon.iconset/icon_128x128.png
sips -z 256 256   icon.png --out AppIcon.iconset/icon_128x128@2x.png
sips -z 256 256   icon.png --out AppIcon.iconset/icon_256x256.png
sips -z 512 512   icon.png --out AppIcon.iconset/icon_256x256@2x.png
sips -z 512 512   icon.png --out AppIcon.iconset/icon_512x512.png
sips -z 1024 1024 icon.png --out AppIcon.iconset/icon_512x512@2x.png
iconutil -c icns AppIcon.iconset -o Clarion.app/Contents/Resources/AppIcon.icns
```

For different use cases (e.g. one build attributed to Claude, one to a different tool), fork the project, update `CFBundleIdentifier` to something unique (e.g. `com.yourname.clarion-claude`), replace the icon, and build — each fork appears as a separate app in System Settings > Notifications.

## Example: Claude Code hook integration

The caller (hook script) owns all Claude-specific logic:

```bash
input=$(cat)
event=$(jq -r '.hook_event_name' <<<"$input")
message=$(jq -r '.message // ""' <<<"$input")
cwd=$(jq -r '.cwd' <<<"$input")
name="Vault"  # resolved from workspace file

case "$event" in
  Notification)  title="⚠️ $name"; sound="default" ;;
  Stop)          title="✅ $name"; message="Finished"; sound="Tink" ;;
  StopFailure)   title="❌ $name"; message=$(jq -r '.error_type // "Failed"' <<<"$input"); sound="default" ;;
  *)             exit 0 ;;
esac

/Applications/Clarion.app/Contents/MacOS/clarion \
  --title "$title" \
  --message "$message" \
  --sound "$sound" \
  --group "claude-$name"
```
