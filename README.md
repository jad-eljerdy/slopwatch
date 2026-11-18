# Slopwatch

**[Download Slopwatch v1.1.1 for Mac (.dmg)](https://github.com/jad-eljerdy/slopwatch/releases/download/v1.1.1/Slopwatch-1.1.1.dmg)**

A native macOS menu bar app that tracks Codex and Claude Code subscription usage.

Requires macOS 26 or later on Apple silicon or Intel. Open the DMG, drag Slopwatch into Applications, then open the app. This release uses an ad hoc signature. Apple has not notarized it, so macOS may block the first launch. [Apple’s guide to first-launch alerts](https://support.apple.com/en-us/102445)

I tried the other usage trackers. They sucked. I wanted to know if Claude could finish one more code review before my limit reset. Somehow I ended up configuring a dashboard. I already pay two robots to overcomplicate things. That position is filled.

So I put the numbers next to the clock. Click the stopwatch. Read the numbers. Congratulations on completing onboarding.

## What you get

- **Subscription limits.** See how much of each reported five-hour or weekly limit you have used and when it resets. Slopwatch finds your signed-in CLIs automatically.
- **Token counts.** See the last 24 hours, 7 days, or 30 days. View both providers together or select one.
- **API value.** See what the tokens would cost at standard API prices. If a model has no published rate in the catalog, its tokens still count. A plus sign marks the partial estimate.

The app uses SwiftUI and AppKit. Usage history stays on your Mac. There is no Slopwatch account, backend, or telemetry.

## Updates

If you use v1.0, quit the app and install the current release once. From v1.1 onward, Slopwatch checks GitHub every three days while running. Sparkle verifies the signed update feed and download. It can install the update when you quit the app. Open the options menu to check immediately or turn off automatic updates. Update checks do not send your token counts, subscription readings, or a system profile.

If an older release shows two stopwatch icons, select **… → Quit Slopwatch** from each icon. Install the current release in Applications, eject the disk image, and open the installed copy.

## Build it

You need macOS 26 or later and Swift 6.4 or later. Sign in to the Codex or Claude Code CLI you want to track. Then run these commands.

```sh
git clone https://github.com/jad-eljerdy/slopwatch.git
cd slopwatch
swift test
zsh scripts/build.sh
open dist/Slopwatch.app
```

Click the stopwatch in the menu bar. If you prefer Terminal, the same app prints the same readings.

```sh
dist/Slopwatch.app/Contents/MacOS/Slopwatch --summary
```

## Where the numbers come from

| Reading | Source |
| --- | --- |
| Codex limits | Quota readings in local Codex session logs. |
| Claude limits | The signed-in Claude Code CLI can contact Anthropic for current limits. Slopwatch requests a fresh reading after five minutes or when you select **Refresh usage**. The request contains no model prompt. |
| Token totals | Local Codex session files and Claude project logs, including subagent logs. Activity on another Mac counts only if its logs are also on this Mac. |
| API value | A bundled table of USD rates for input, output, cache reads, and cache writes. Your subscription bill is a separate number. |

For older Claude CLI versions, Slopwatch can read the local `/usage` cache or use an optional status-line helper. Move the app to a stable location before enabling the helper in Claude source details. You can disable it there. An existing custom status line takes precedence.

<details>
<summary>Local paths and cache details</summary>

Slopwatch reads `~/.codex/sessions`, `~/.codex/archived_sessions`, and `~/.claude/projects`. Compressed Codex logs require a local `zstd` executable. The app finds executables in `~/.local/bin`, Homebrew directories, and its search path. It honors `CODEX_HOME` and `CLAUDE_CONFIG_DIR` when its process receives those variables. Apps opened from Finder use the Finder environment.

The local index lives in `~/Library/Caches/local.slopwatch.app/`. It stores counts, model names, response identifiers, timestamps, quota readings, paths, and file checkpoints. It excludes conversation text. Quit Slopwatch and remove that directory to rebuild the index. The optional Claude helper writes `slopwatch-limits.json` in the Claude configuration directory.

</details>

## Change something

The [price table](Sources/Slopwatch/Resources/rates.tsv) is plain text. Edit a row and rebuild. The bundled rates are dated November 18, 2026. Estimates exclude tool fees, service-tier adjustments, regional charges, and subscription fees. Codex cache writes use the default retention rate when the log omits the duration. Some Claude logs also include API-key sessions. See the published rates from [OpenAI](https://developers.openai.com/api/docs/pricing) and [Anthropic](https://platform.claude.com/docs/en/about-claude/pricing).

| To change | Start here |
| --- | --- |
| CLI discovery and login checks | [LocalPaths.swift](Sources/Slopwatch/LocalPaths.swift) and [CLIStatus.swift](Sources/Slopwatch/CLIStatus.swift) |
| Provider readings | [CodexReader.swift](Sources/Slopwatch/CodexReader.swift), [ClaudeReader.swift](Sources/Slopwatch/ClaudeReader.swift), and [ClaudeUsageRequest.swift](Sources/Slopwatch/ClaudeUsageRequest.swift) |
| Time windows and pricing | [Accounting.swift](Sources/Slopwatch/Accounting.swift) and [Pricing.swift](Sources/Slopwatch/Pricing.swift) |
| Menu layout and behavior | [Dashboard.swift](Sources/Slopwatch/Dashboard.swift) and [MenuController.swift](Sources/Slopwatch/MenuController.swift) |

The [specification](SPEC.md) covers the design and acceptance checks.
