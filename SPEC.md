# Slopwatch

Slopwatch is a native macOS menu bar app for Codex and Claude Code. Open its menu to see remaining subscription capacity and the API value of local usage.

## Connections

Find the installed CLI in standard Mac executable directories and the process search path. Ask the CLI for its local sign-in status. Distinguish subscription access, API access, signed-out state, and an unavailable executable. Keep historical totals available if sign-in changes.

## Subscription limits

Use the most recent provider reading. Identify each Codex window by its duration. Show the reported percentage and reset time. Support five-hour, weekly, and other reported session windows. Discard expired percentages from the current display.

Read the utilization snapshot in the Claude Code configuration. Request fresh limits through the signed-in CLI when its reading is missing or stale. Claude Code can contact Anthropic for the account reading. Send only a usage control request. Support the Claude Code status-line payload as an additional local source. Preserve an existing custom status line.

## Local activity

Read active and archived Codex JSONL files, including Zstandard archives when the local decoder is available. Read Claude project logs and subagent logs. Honor the configured CLI data directories.

Use the preceding 24 hours, 168 hours, and 720 hours. Apply the same interval to tokens, charts, and estimates. Show totals for both providers and allow inspection of each provider.

Count each model response once. Exclude cached input and reasoning from additional totals when the provider already includes them. Separate normal input, cache reads, cache writes, and output for pricing.

## API value

Bundle a dated table of public standard API rates in USD per million tokens. Support different cache read and write rates. Show the extent of missing price coverage. Identify the estimate as a token price comparison. Subscription invoices, tool fees, and negotiated rates are outside this estimate.

## Interface

Use SwiftUI and AppKit. Provide a recognizable monochrome menu bar symbol. Place the time range, token total, API value, activity chart, and quota meters in one compact panel. Support keyboard controls, VoiceOver, light appearance, and dark appearance.

## Performance and recovery

Open the panel immediately. Read files off the main thread. Reuse parsed records for unchanged files. Resume growing plain logs at the last complete line. Rebuild replaced or truncated files. Keep a bounded buffer for long records. Expose incomplete data and retry on refresh.

## Privacy

Process usage on this Mac. Keep the index free of conversation text, account credentials, and email addresses. Use local CLI status commands only. Disable optional CLI telemetry for those commands. Include no network client, update checker, or analytics SDK.

## Acceptance

Build a release app with the installed Apple Swift toolchain. Test both formats, duplicate records, partial files, calendar boundaries, pricing, and expired limits. Launch the signed local bundle and verify its menu bar item. Keep all Git history local.
