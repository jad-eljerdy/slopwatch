# Slopwatch

Slopwatch is a native macOS menu bar app for Codex and Claude Code. Open its menu to see remaining subscription capacity and the API value of local usage.

## Connections

Find the installed CLI in standard Mac executable directories and the process search path. Ask the CLI for its local sign-in status. Distinguish subscription access, API access, signed-out state, and an unavailable executable. Keep historical totals available if sign-in changes.

## Subscription limits

Use the most recent provider reading. Identify each Codex window by its duration. Show the reported percentage and reset time. Support five-hour, weekly, and other reported session windows. Discard expired percentages from the current display.

Read the utilization snapshot in the Claude Code configuration. Support the Claude Code status-line payload as a local source when the cached snapshot is old. Preserve an existing custom status line. Explain how to obtain a new reading when none is available.

## Local activity

Read active and archived Codex JSONL files, including Zstandard archives when the local decoder is available. Read Claude project logs and subagent logs. Honor the configured CLI data directories.
