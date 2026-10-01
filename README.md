# MacVitals

A small menu bar app for fanless MacBook Airs. It shows system load, warns you when macOS starts thermal throttling, and lists pending Homebrew updates.

## Menu bar dots

| Dot | Meaning |
| --- | --- |
| 🟢 | Normal |
| 🔴 | Throttling (thermal state `serious` or `critical`) |
| 🔵 | Homebrew updates pending (shown next to green or red) |

Click the dots to open the dashboard:
- **System:** CPU (performance and efficiency cores), memory, a 30-minute thermal timeline, top processes, battery and power, disk and network.
- **Brew:** outdated formulae and casks. This tab is read only and never upgrades anything.
- **Settings** (gear icon): dot colors, the brew check interval, and launch at login.

## Build and install

You only need the Command Line Tools, not Xcode.

```bash
./build.sh                      # builds, signs ad hoc, installs to ~/Applications
open ~/Applications/MacVitals.app
```

## How it measures

- **Throttling:** `ProcessInfo.thermalState`, the public signal macOS uses when it limits performance. The `fair` state shows as amber in the dashboard only.
- **CPU:** per-core tick deltas from `host_processor_info`. On Apple Silicon the efficiency cores come first.
- **Memory:** app memory + wired + compressed, the same as Activity Monitor's "Memory Used".
- **Brew:** `brew update` + `brew outdated --json=v2`. This runs at launch, every 6 hours by default (you can change this in Settings), and when you click "Check now".
- **Sampling:** every 10 s in the background and every 2 s while the dashboard is open. Top processes are only read while the dashboard is open.

## Testing

```bash
# Force a thermal state to see the red dot and banner (nominal, fair, serious, critical)
MACVITALS_FAKE_THERMAL=serious ~/Applications/MacVitals.app/Contents/MacOS/MacVitals

# Render both tabs and the dot states to PNGs without opening anything
.build/release/MacVitals --snapshot /tmp/macvitals
```
