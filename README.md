# Run Windows Steam games on Apple Silicon Mac (Wine + DXMT)

For developer details, see the [Developer README](README_DEV.md).

## Download

1. Click the green button `Code`, then `Download ZIP`.
2. Unzip the downloaded ZIP file (double-click it).

## Install / Run

### Simple: Spotlight-friendly launchers with game presets

#### Install:

1. In the unzipped folder, run `build_merlot.sh` in Terminal:
   ```bash
   ./build_merlot.sh
   ```
2. Open the generated `Merlot Apps` folder.
3. Drag the whole `Merlot Apps` folder to `/Applications` (or `~/Applications`).

#### Run:

1. Open one of the apps:
   - `Steam (Merlot).app` to launch Steam without game-specific presets.
   - A game launcher, for example `Binding of Isaac.app`, to use presets optimized for that game.
2. If macOS blocks it, right-click the app -> `Open` -> confirm `Open`.
3. Keep the Terminal window open while the game is running. Close Terminal only after you exit.

This folder includes `Steam (Merlot).app`, which starts Steam, plus ready-made launchers for games already included in this repository.
Each game launcher includes presets and tweaks optimized for that game.
If you want, you can also add your own config in `merlot_configs/` and run `build_merlot.sh` again to create another launcher.

What to expect:
- You may be asked for your macOS password (to install Rosetta if it is missing).
- First run can take a while because it downloads Wine, DXMT, and Steam installer.
- At the end, Steam should launch inside Wine.

### Advanced: Generic Steam launcher

1. In Finder, locate the unzipped folder.
2. Double-click `run.command`.
3. If macOS blocks it, right-click `run.command` -> `Open` -> confirm `Open`.
4. Keep the Terminal window open while Steam is running. Close Terminal only after you exit Steam.

Use this option when you want the general Steam-in-Wine setup instead of a launcher tailored to a specific game.

If you are familiar with Terminal and bash, you can also customize launch options described in the [Developer README](README_DEV.md).

What to expect:
- You may be asked for your macOS password (to install Rosetta if it is missing).
- First run can take a while because it downloads Wine, DXMT, and Steam installer.
- At the end, Steam should launch inside Wine.

## Stop

1. In Steam, use the menu: `Steam` -> `Exit`.
2. Wait until Steam fully closes.
3. Close Terminal.

## Uninstall

If Steam is running, follow the steps in "Stop" first.

1. Double-click `uninstall.command`.
2. If macOS blocks it, right-click `uninstall.command` -> `Open` -> confirm `Open`.
3. It will ask for confirmation for each item it wants to remove. Type `y` to remove it, or `n` to skip it (if you want to keep something).

## Notes

- Apple Silicon only. Intel Macs are not supported by this script.
- Tested on:
  - Apple M1 Max (32GB), macOS Sequoia 15.7.4
  - Apple M2 Pro (16GB), macOS Sequoia 15.7.4
- Inspired by this Reddit post:
  https://www.reddit.com/r/macgaming/comments/1r8vsnj/how_to_play_windows_steam_games_on_mac_with_m/

## What The Scripts Do (Short)

`run.command`:
- Installs Rosetta 2 (only if missing; requires `sudo`).
- Downloads Wine Staging (Gcenx macOS Wine builds) and sets up a Steam Wine prefix.
- Downloads and installs Steam into that prefix.
- Downloads DXMT and enables it for Wine.

`uninstall.command`:
- Removes files/directories created by `run.command` (with per-item confirmation).
- Does not remove Rosetta 2.
