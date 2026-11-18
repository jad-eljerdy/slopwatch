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

## Local files

Slopwatch reads `~/.codex/sessions`, `~/.codex/archived_sessions`, and `~/.claude/projects`. It honors `CODEX_HOME` and `CLAUDE_CONFIG_DIR` when the app process receives those variables. Finder launches use the Finder environment. The app finds both CLIs in `~/.local/bin`, Homebrew directories, and the process search path. Compressed Codex logs use the local `zstd` executable. The panel reports missing archive support.

The usage index lives in `~/Library/Caches/local.slopwatch.app/`. It contains response identifiers, counts, timestamps, model names, quota readings, local paths, and file checkpoints. It excludes prompts and responses. Quit Slopwatch and remove that directory to rebuild the index. The optional Claude helper writes `slopwatch-limits.json` in the Claude configuration directory.

## Pricing

API value estimates the standard USD cost of the observed tokens. The bundled catalog is dated November 18, 2026. The estimate includes reported cache reads and writes. It uses the default retention rate when Codex omits the write duration. It excludes tools, service-tier adjustments, regional charges, and subscription fees. A plus sign marks a partial estimate. Unknown models still count toward tokens. Claude history can include API-key sessions because historical messages do not always identify the billing account.

Edit [rates.tsv](Sources/Slopwatch/Resources/rates.tsv) to change a model rate. Rebuild the app to apply it. Reference rates come from [OpenAI](https://developers.openai.com/api/docs/pricing) and [Anthropic](https://platform.claude.com/docs/en/about-claude/pricing).

## Code layout

| To change | Start here |
| --- | --- |
| Provider discovery and CLI authentication | `LocalPaths.swift`, `CLIStatus.swift` |
| Codex and Claude event formats | `CodexReader.swift`, `ClaudeReader.swift`, `TokenDecoder.swift` |
| Claude quota sources | `ClaudeQuota.swift`, `CaptureSetup.swift`, `Support/claude-statusline.sh` |
| File discovery, streaming, and cache reuse | `HistoryFiles.swift`, `HistoryReader.swift`, `UsageEngine.swift` |
| Time windows and pricing | `Accounting.swift`, `Pricing.swift` |
| Panel layout, colors, and menu bar behavior | `Dashboard.swift`, `Theme.swift`, `MenuController.swift` |

Swift sources are in `Sources/Slopwatch/`. The [product specification](SPEC.md) describes the acceptance checks.
