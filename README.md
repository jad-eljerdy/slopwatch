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
