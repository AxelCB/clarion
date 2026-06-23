<p align="center">
  <img src="clarion-logo-dark-1024.png" width="160" alt="Clarion" />
</p>

<h1 align="center">Clarion</h1>

<p align="center">
  A minimal macOS notification tool built as a proper <code>.app</code> bundle.<br>
  Posts native notifications via <code>UNUserNotificationCenter</code> with a custom icon<br>
  and correct app attribution in System Settings → Notifications.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%2013%2B-lightgrey?style=flat-square" alt="macOS 13+" />
  <img src="https://img.shields.io/badge/swift-6.2-orange?style=flat-square&logo=swift" alt="Swift 6.2" />
  <img src="https://img.shields.io/github/license/AxelCB/clarion?style=flat-square" alt="MIT License" />
</p>

---

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

<p align="center">
  <img src="clarion-logo-dark-1024.png" width="80" alt="Dark" />
  &nbsp;&nbsp;
  <img src="clarion-logo-light-1024.png" width="80" alt="Light" />
  &nbsp;&nbsp;
  <img src="clarion-logo-tinted-1024.png" width="80" alt="Tinted" />
</p>
<p align="center"><sub>dark &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; light &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; tinted</sub></p>

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
  --bundle-id com.example.clarion-vscode \
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

## Integrations

### Claude Code hooks

Clarion pairs well with [Claude Code hooks](https://docs.anthropic.com/en/docs/claude-code/hooks) to get native notifications when a session finishes, fails, or needs your attention.

Create `~/.claude/hooks/notify.sh`:

```bash
#!/bin/bash
set -euo pipefail

input=$(cat)
event=$(jq -r '.hook_event_name' <<<"$input")
message=$(jq -r '.message // ""' <<<"$input")
name=$(basename "$(jq -r '.cwd' <<<"$input")")

case "$event" in
  Notification)  icon="⚠️";  sound="default" ;;
  Stop)          icon="✅";  message="Finished"; sound="Tink" ;;
  StopFailure)   icon="❌";  message=$(jq -r '.error_type // "Failed"' <<<"$input"); sound="default" ;;
  *)             exit 0 ;;
esac

/Applications/Clarion.app/Contents/MacOS/clarion \
  --title "$icon $name" \
  --message "$message" \
  --sound "$sound" \
  --group "claude-$name"
```

Then register the hook in `~/.claude/settings.json`:

```json
{
  "hooks": {
    "Stop":        [{"hooks": [{"type": "command", "command": "bash ~/.claude/hooks/notify.sh"}]}],
    "StopFailure": [{"hooks": [{"type": "command", "command": "bash ~/.claude/hooks/notify.sh"}]}],
    "Notification":[{"hooks": [{"type": "command", "command": "bash ~/.claude/hooks/notify.sh"}]}]
  }
}
```

Each session fires a notification attributed to `Clarion` with the folder name as the title — distinguishable from other system notifications at a glance, and configurable via System Settings → Notifications.

### Any shell script or automation tool

Because Clarion is just a CLI binary, it works anywhere a shell command runs — `make` targets, CI scripts, Raycast script commands, launchd jobs, or any tool that supports shell hooks.

```bash
# Long-running task with completion notification
make build && /Applications/Clarion.app/Contents/MacOS/clarion \
  --title "✅ Build done" --message "Ready to test" --sound "Tink"
```

## Why

- `osascript` notifications are attributed to Script Editor — no custom icon
- `terminal-notifier -sender` hangs indefinitely on modern macOS when the target app isn't running (confirmed unfixed bug)
- Clarion is a real `.app` bundle using the proper modern notification API — no hacks, no hanging

## Identity

A modern heraldic insignia emerging from noise and darkness, symbolizing important information becoming clear, visible, and worthy of attention.

See [DESIGN.md](DESIGN.md) for the full design rationale and asset reference.

## License

MIT © [Axel Collard Bovy](https://github.com/AxelCB)
