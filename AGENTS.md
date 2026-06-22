# Clarion — Agent Instructions

You are building Clarion: a minimal macOS Swift command-line tool packaged as a `.app` bundle that posts native notifications via `UNUserNotificationCenter`. Read SPEC.md fully before writing any code.

## What you are building

A generic notification tool — a Swift executable that:
1. Accepts `--title`, `--message`, `--sound` CLI flags
2. Optionally reads a JSON object from stdin with the same fields
3. Posts a macOS notification and exits immediately
4. Has no knowledge of Claude Code or any specific caller

## Project structure to create

```
clarion/
  Package.swift
  Sources/
    ClarionKit/         — shared runtime + packaging logic
    clarion/            — CLI entry point
    ClarionPackage/     — Swift-based bundle/sign/install tool
  Clarion.app/
    Contents/
      Info.plist        — already provided
      MacOS/            — built binary goes here
      Resources/        — AppIcon.icns goes here (placeholder for now)
```

## Technical decisions

- **Language:** Swift 5.9+
- **Notification API:** `UNUserNotificationCenter` — do NOT use `NSUserNotification` (deprecated, removed in macOS 14)
- **No SwiftUI, no AppKit** — command-line tool only
- **Requesting permission:** call `requestAuthorization(options: [.alert, .sound])` on first run; handle the async response before proceeding
- **Synchronous exit pattern:** use a `DispatchSemaphore` to wait for async notification delivery before calling `exit(0)` — do not exit before the notification is posted
- **CLI parsing:** use `CommandLine.arguments` directly — no third-party dependencies
- **Stdin reading:** check `isatty(STDIN_FILENO)` to detect piped input; if stdin is a TTY, skip stdin reading
- **Info.plist fields (already written):**
  - `CFBundleIdentifier = com.axelcollardbovy.clarion`
  - `CFBundleName = Clarion`
  - `LSUIElement = true`

## Supported flags

| Flag | Type | Description |
|---|---|---|
| `--title` | String | Notification title |
| `--message` | String | Notification body |
| `--subtitle` | String | Secondary line below title |
| `--sound` | String | Sound name (`Tink`, `Glass`, `default`, etc.) |
| `--group` | String | Thread/group identifier — replaces previous notification with same ID |
| `--attachment` | String | Absolute path to `.png` or `.jpg` shown as thumbnail in notification body |

## Input priority

CLI flags take precedence over stdin JSON. If `--title` is provided as a flag, ignore any `title` field in stdin JSON. Apply the same rule for all other flags.

## Sound handling

Pass the sound name string directly to `UNNotificationSound(named:)`. Special case: if sound is `"default"` or empty, use `UNNotificationSound.default`. If the sound name is unrecognised by macOS, it will fall back silently — that's fine, don't validate sound names.

## Group handling

If `--group` is provided, set `content.threadIdentifier` to that value. macOS uses this to replace/group notifications with the same thread ID in Notification Centre — prevents stacking when the same session fires multiple events.

## Attachment handling

If `--attachment` is provided, load the file as a `UNNotificationAttachment` and attach it to the notification content. If the file doesn't exist or can't be loaded, skip the attachment silently — don't fail the notification.

## Packaging commands

- `swift run --disable-sandbox clarion-package bundle` — builds and assembles `Clarion.app/Contents/MacOS/clarion`
- `swift run --disable-sandbox clarion-package sign` — ad-hoc signs: `codesign --force --deep --sign - Clarion.app`
- `swift run --disable-sandbox clarion-package install` — copies `Clarion.app` to `/Applications/`
- `swift run --disable-sandbox clarion-package all` — bundle + sign (default command)
- `swift run --disable-sandbox clarion-package clean` — removes built binary and SwiftPM artifacts

## Error handling rules

- Never crash or print to stderr in a way that could break a calling shell script
- If required fields (`title`, `message`) are missing after checking both flags and stdin → exit 0 silently
- If stdin JSON is malformed → ignore stdin, use flags only
- If notification permission is denied → exit 0 silently
- On success → exit 0 with no output to stdout or stderr

## Testing

After building, verify with:

```bash
# Test direct flags
/Applications/Clarion.app/Contents/MacOS/clarion \
  --title "✅ Vault" --message "Finished" --sound "Tink"

# Test subtitle
/Applications/Clarion.app/Contents/MacOS/clarion \
  --title "⚠️ App Dev" --message "needs permission: run xcodebuild" --subtitle "skyscanner-vault"

# Test group (run twice — second should replace first in Notification Centre)
/Applications/Clarion.app/Contents/MacOS/clarion \
  --title "✅ Vault" --message "Finished" --group "test-group"
/Applications/Clarion.app/Contents/MacOS/clarion \
  --title "✅ Vault" --message "Finished again" --group "test-group"

# Test stdin JSON
echo '{"title":"⚠️ App Dev","message":"needs permission: run xcodebuild","sound":"default","subtitle":"ios-app"}' \
  | /Applications/Clarion.app/Contents/MacOS/clarion

# Test flags override stdin
echo '{"title":"ignored","message":"also ignored"}' \
  | /Applications/Clarion.app/Contents/MacOS/clarion \
    --title "✅ Override" --message "Flags win"

# Test missing input (should exit silently, no notification)
/Applications/Clarion.app/Contents/MacOS/clarion
```

Expected: all produce correct notifications except the last which exits silently with no output.

## What NOT to do

- Do not add any Claude Code-specific logic — Clarion is generic
- Do not add a `-sender` flag or app identity borrowing
- Do not add click handlers, action buttons, or URLs
- Do not add a persistent background process or daemon
- Do not use `NSUserNotification` (deprecated)
- Do not add SwiftUI or AppKit dependencies
- Do not add third-party Swift packages
- Do not print anything to stdout or stderr on success
- Do not add features beyond the spec
