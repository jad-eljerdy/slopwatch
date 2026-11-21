# Menu bar CPU use on macOS

On November 21, 2026, Slopwatch v1.1.7 used 25.53 seconds of CPU time in 30 seconds with the panel closed. The Mac was on battery power. Both provider icons were visible, with one Codex value and two Claude values. Version 1.1.12 used 0.0035 seconds of CPU time under the same conditions.

| Slopwatch process, 30 seconds | v1.1.7 (build 14) | v1.1.12 (build 19) |
| --- | ---: | ---: |
| Average CPU, as a percentage of one core | 85.09% | 0.012% |
| Interrupt wakeups | 3,264 | 14 |

## Cause

A four-second process sample caught the main thread repeatedly snapshotting the status item and laying out its nested AppKit views. In 482 of 916 main-thread samples, the stack included the status item’s replicant update, which copies the item for display in the menu bar. No user action or change in the displayed percentages was necessary. The menu bar implementation was the same in v1.1.7 through v1.1.11.

## Changes

- The native status button now displays one image for the provider icons and their values. The image changes only when the visible content changes. The tooltip and expiry deadline update independently.
- The one-minute timer skips its extra activity scan while the panel is closed. Opening the panel still checks for stale activity. Scheduled subscription checks and wake handling still refresh usage.

## Verification

The comparison used the same Apple silicon Mac running macOS 27.0.1, with the same menu bar configuration. The second measurement started after the updated app had loaded current quota readings. CPU time and interrupt wakeups came from the difference between two macOS process resource counters. CPU time used the Mach timebase conversion. A second four-second sample of the updated app found the main thread waiting for events and no status-item snapshot calls.

A separate 18-second measurement included opening the panel’s **Refresh usage** command and closing the panel. Slopwatch used 0.18 CPU seconds during that interval. These figures cover the app process. They exclude provider CLI child processes. The test did not measure watts or hours of battery life.
