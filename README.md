# MacVitals

A small menu bar app for MacBooks, built for fanless Airs. It shows system load, tells you when macOS starts thermal throttling, and lists pending Homebrew updates.

## Requirements

- macOS 14 (Sonoma) or newer
- Apple Silicon. Intel Macs work too, but the CPU line shows a meaningless "E 0%".
- The Command Line Tools (`xcode-select --install`). You don't need Xcode.
- [Homebrew](https://brew.sh) for the Brew tab. Without it, the tab shows a message and the rest of the app works normally.

## Install

```bash
git clone <repo-url> MacVitals
cd MacVitals
./build.sh
open ~/Applications/MacVitals.app
```

`build.sh` compiles a release build, wraps it in `MacVitals.app`, signs it ad hoc, and installs it to `~/Applications`. If MacVitals is already running, the script quits it first.

The app has no Dock icon. Look for the colored dots in the menu bar. To start it automatically, open Settings (gear icon) and turn on **Launch at login**. If macOS asks, approve it in System Settings › General › Login Items.

If you copy a built `MacVitals.app` to another Mac instead of building it there, Gatekeeper blocks it on first launch because it isn't notarized. Right-click the app and choose Open once to allow it.

## Usage

### Menu bar dots

| Dot | Meaning |
| --- | --- |
| 🟢 | Normal |
| 🔴 | Throttling: macOS is limiting performance because the Mac is too hot |
| 🔵 | Homebrew updates are pending (shown next to the green or red dot) |

### Dashboard

Click the dots to open the dashboard.

- **System:**
  - CPU load, split into performance and efficiency cores
  - memory used and swap
  - a 30-minute thermal timeline
  - the top five processes
  - battery and power draw
  - free disk space and network throughput
- **Banner:** when the Mac runs warm, an amber banner appears; when it throttles, a red one.
- **Brew:**
  - outdated formulae and casks, with the installed and latest versions
  - "Check now" to refresh
  - The tab is read only. Run `brew upgrade` in your terminal to update.
- **Settings** (gear icon):
  - dot colors
  - how often to check Homebrew (1–24 hours, 6 by default)
  - launch at login

## Update

```bash
cd MacVitals
git pull
./build.sh
open ~/Applications/MacVitals.app
```

## Uninstall

```bash
~/Applications/MacVitals.app/Contents/MacOS/MacVitals --login-item off
pkill -x MacVitals
rm -rf ~/Applications/MacVitals.app
defaults delete io.github.macvitals
```

The last line removes your saved settings.

## How it measures

- **Throttling:** `ProcessInfo.thermalState`, the public signal macOS uses when it limits performance. `serious` and `critical` count as throttling. `fair` shows as amber in the dashboard only.
- **CPU:** per-core tick deltas from `host_processor_info`. On Apple Silicon the efficiency cores come first.
- **Memory:** app memory + wired + compressed, the same as Activity Monitor's "Memory Used".
- **Brew:** `brew update` + `brew outdated --json=v2`. This runs at launch, on the interval set in Settings, and when you click "Check now".
- **Sampling:** every 10 s in the background and every 2 s while the dashboard is open. Top processes are only read while the dashboard is open.

Everything uses public APIs or `sysctl`, so MacVitals needs no root access and no helper tools.

## Development

```bash
swift build                     # debug build
./build.sh                      # release build, installed to ~/Applications

# Force a thermal state to see the red dot and banner (nominal, fair, serious, critical)
MACVITALS_FAKE_THERMAL=serious ~/Applications/MacVitals.app/Contents/MacOS/MacVitals

# Render both tabs, settings, and the dot states to PNGs without opening anything
.build/release/MacVitals --snapshot /tmp/macvitals

# Turn launch at login on or off from the command line
~/Applications/MacVitals.app/Contents/MacOS/MacVitals --login-item on
```
