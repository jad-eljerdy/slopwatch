# Slopwatch

Slopwatch tracks Codex and Claude Code usage in the macOS menu bar. Select the dial to see usage for the last 24 hours, 7 days, or 30 days. Select a provider to see its totals. The information button shows its login state and last quota reading.

## Build and run

Use macOS 26 or later and Swift 6.4 or later. The project uses Swift Package Manager and the macOS SDK. Run these commands from the repository.

```sh
swift test
zsh scripts/build.sh
open dist/Slopwatch.app
```

Copy the built app to a stable location before you enable Claude limit capture. To inspect the same readings in Terminal, run the command below.

```sh
dist/Slopwatch.app/Contents/MacOS/Slopwatch --summary
```

## Sources and privacy

Slopwatch calls `codex login status` and `claude auth status --json` to check local credentials. It reads usage from local session files. The app has no backend, network client, telemetry SDK, or automatic updater. It never sends a prompt to refresh usage.

Codex reports quotas in session records. Claude Code can cache quotas when you open `/usage`. For automatic Claude readings, open Claude source details and enable local limit capture. The helper receives the values from Claude Code after a model response. It stores only the observation time, percentages, and reset times. Slopwatch preserves an existing custom status line. Disable capture in the same panel before moving or removing the app.

CLI sign-in and all provider activity still belong to their respective tools. Expired readings remain available in source details. Usage from another device appears only if its logs exist on this Mac.
