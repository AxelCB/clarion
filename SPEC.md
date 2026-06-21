# notifly — Product Specification

## Purpose

notifly is a macOS command-line notification tool built as a proper `.app` bundle. It is designed specifically to deliver native macOS notifications from Claude Code hook events, with correct app attribution, icon, and sound — without the hanging and attribution issues of `terminal-notifier`.

## Background

Claude Code fires hook events (Stop, StopFailure, Notification) at the end of each session or when attention is needed. A shell script reads these events and needs to surface them as macOS notifications. Existing tools:

- `osascript` — no custom icon, attributed to Script Editor
- `terminal-notifier` — `-sender` flag hangs indefinitely on modern macOS when target app isn't running (confirmed unfixed bug)

notifly solves this by being a real `.app` bundle using `UNUserNotificationCenter` directly.

## Functional Requirements

### Input

Reads a JSON payload from stdin. Schema matches Claude Code hook event payloads:

```json
{
  "hook_event_name": "Stop | StopFailure | Notification",
  "cwd": "/path/to/project",
  "message": "optional message text",
  "error_type": "optional error type for StopFailure"
}
```

### Arguments

- `--name <string>` — session label shown in notification title (e.g. "Vault", "App Dev"). Required.

### Notification mapping

| `hook_event_name` | Title | Body | Sound |
|---|---|---|---|
| `Notification` | `⚠️ {name}` | `message` field from payload | Default alert |
| `Stop` | `✅ {name}` | "Finished" (hardcoded) | Tink |
| `StopFailure` | `❌ {name}` | `error_type` field, fallback "Failed" | Default alert |
| anything else | exit 0 silently | — | — |

### Behaviour

- Posts the notification and exits immediately
- No Dock icon, no menu bar presence (`LSUIElement = true` in Info.plist)
- No interactive elements (no action buttons, no click handlers)
- If `--name` is missing, falls back to basename of `cwd` from payload
- If stdin is empty or unparseable, exits 0 silently (never crash the hook script)

## Non-Functional Requirements

- Must work on macOS 13+ (Ventura and later)
- Ad-hoc code signed (`codesign --sign -`) — no Apple Developer account required
- Delivered as a self-contained `.app` bundle
- The app bundle icon (`AppIcon.icns`) is provided separately and placed in `Resources/` — build process must reference it
- Callable from a bash script with no extra setup beyond placing the `.app` somewhere on disk

## Out of Scope

- No `-sender` flag or app identity borrowing
- No click-to-open URL or shell command execution on notification click
- No persistent background process or daemon
- No menu bar UI
- No macOS 12 or earlier support

## Delivery

- `notifly.app` — the built app bundle, ad-hoc signed
- `Makefile` — targets: `build`, `sign`, `install` (copies to `/Applications`)
- The app must appear in System Settings > Notifications as "notifly" and allow the user to customise notification style

## Example shell integration

```bash
input=$(cat)
name="Vault"

echo "$input" | /Applications/notifly.app/Contents/MacOS/notifly --name "$name"
```
