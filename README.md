# notifly

A minimal macOS notifier app for Claude Code sessions. Reads Claude Code hook payloads from stdin and posts native macOS notifications via `UNUserNotificationCenter`.

Built as a proper `.app` bundle so notifications appear with a real icon and are attributed correctly in System Settings > Notifications — not as "terminal-notifier" or "Script Editor".

## Usage

```bash
echo '{"hook_event_name":"Stop","cwd":"/path/to/project"}' | /Applications/notifly.app/Contents/MacOS/notifly --name "Vault"
```

## Notification format

| Event | Title | Body | Sound |
|---|---|---|---|
| `Notification` | `⚠️ {name}` | message from payload | Default |
| `Stop` | `✅ {name}` | Finished | Tink |
| `StopFailure` | `❌ {name}` | error_type from payload or "Failed" | Default |

## Integration

Used by `~/.claude/hooks/notify.sh` in the Claude Code workflow setup. The hook script resolves the session name from the matching `.code-workspace` file and passes it via `--name`.
