# notifly — Agent Instructions

You are building notifly: a minimal macOS Swift command-line tool packaged as a `.app` bundle that posts native notifications via `UNUserNotificationCenter`. Read SPEC.md fully before writing any code.

## What you are building

A Swift executable that:
1. Reads JSON from stdin (Claude Code hook payload)
2. Parses `hook_event_name`, `message`, `error_type` fields
3. Accepts `--name <string>` CLI argument
4. Posts a macOS notification with correct title, body, and sound based on event type
5. Exits immediately after posting

Packaged as a proper `.app` bundle so it appears correctly in System Settings > Notifications.

## Project structure to create

```
notifly/
  Sources/
    main.swift          — entry point, argument parsing, stdin reading
    Notifier.swift      — UNUserNotificationCenter logic
    PayloadParser.swift — JSON parsing
  notifly.app/
    Contents/
      Info.plist
      MacOS/            — built binary goes here
      Resources/        — AppIcon.icns goes here (placeholder for now)
  Makefile
```

## Technical decisions

- **Language:** Swift 5.9+
- **Notification API:** `UNUserNotificationCenter` — do NOT use `NSUserNotification` (deprecated)
- **No SwiftUI, no AppKit** — this is a command-line tool, not a GUI app
- **Requesting permission:** call `requestAuthorization(options:)` on first run; subsequent runs skip this if already granted
- **Synchronous exit pattern:** use a `DispatchSemaphore` or `RunLoop.main.run(until:)` to wait for the async notification delivery before exiting — do not exit before the notification is posted
- **Info.plist must include:**
  - `LSUIElement = true` (no Dock icon)
  - `NSUserNotificationAlertStyle = alert` (banner vs alert style preference)
  - `CFBundleIdentifier = com.axelcb.notifly`
  - `CFBundleName = notifly`
  - Correct `CFBundleIconFile` pointing to `AppIcon`

## Makefile targets

- `make build` — compiles with `swiftc`, outputs binary to `notifly.app/Contents/MacOS/notifly`
- `make sign` — ad-hoc signs: `codesign --force --deep --sign - notifly.app`
- `make install` — copies `notifly.app` to `/Applications/`
- `make all` — build + sign (default target)

## Error handling rules

- Never crash or print to stderr in a way that would break the calling hook script
- If stdin is empty or JSON is malformed → exit 0 silently
- If `--name` is missing → derive from `cwd` field in payload using `URL(fileURLWithPath:).lastPathComponent`, fallback to "Claude"
- If notification permission is denied → exit 0 silently (don't block the hook)
- Unknown `hook_event_name` values → exit 0 silently

## Testing

After building, verify with:

```bash
# Test Stop event
echo '{"hook_event_name":"Stop","cwd":"/Users/test/skyscanner-vault"}' \
  | ./notifly.app/Contents/MacOS/notifly --name "Vault"

# Test Notification event  
echo '{"hook_event_name":"Notification","cwd":"/Users/test/ios-app","message":"needs permission: run xcodebuild"}' \
  | ./notifly.app/Contents/MacOS/notifly --name "App Dev"

# Test StopFailure
echo '{"hook_event_name":"StopFailure","cwd":"/Users/test/ios-app","error_type":"rate_limit"}' \
  | ./notifly.app/Contents/MacOS/notifly --name "App Dev"

# Test fallback (no --name)
echo '{"hook_event_name":"Stop","cwd":"/Users/test/skyscanner-vault"}' \
  | ./notifly.app/Contents/MacOS/notifly
```

Expected: each produces a macOS notification with correct title, body, and sound. No terminal output, no errors.

## What NOT to do

- Do not add a `-sender` flag or any app identity borrowing
- Do not add click handlers or action buttons
- Do not add a persistent background process or daemon
- Do not use `NSUserNotification` (deprecated, removed in macOS 14)
- Do not add SwiftUI or AppKit dependencies
- Do not print anything to stdout or stderr on success
- Do not add features beyond the spec — this must stay minimal
