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
  "sound": "Tink"
}
```

If both are provided, CLI flags take precedence over stdin JSON.

### Arguments

| Flag | Required | Description |
|---|---|---|
| `--title` | Yes (or via stdin) | Notification title |
| `--message` | Yes (or via stdin) | Notification body |
| `--sound` | No | Sound name (e.g. `Tink`, `Glass`, `default`). Defaults to `default`. |

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
- App icon (`AppIcon.icns`) placed in `Resources/` — provided separately by the owner
- Must appear in System Settings > Notifications as "Clarion"
- Callable from any shell script with no extra setup beyond placing the `.app` on disk

## Out of Scope

- No `-sender` flag or app identity borrowing
- No click-to-open URL or shell command execution on notification click
- No persistent background process or daemon
- No menu bar UI
- No Claude Code-specific logic — all caller-specific behaviour lives in the calling script

## Delivery

- `Clarion.app` — built app bundle, ad-hoc signed
- `Makefile` — targets: `build`, `sign`, `install`, `clean`
- The app must appear in System Settings > Notifications as "Clarion"

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
  --sound "$sound"
```
