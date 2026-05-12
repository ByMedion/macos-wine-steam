# Run Windows Steam games on Apple Silicon Mac (Wine + DXMT)

For developer details, see the [Developer README](README_DEV.md).

## References & Credits

- Inspired by this Reddit post:
  [How to play Windows Steam games on Mac with M...](https://www.reddit.com/r/macgaming/comments/1r8vsnj/how_to_play_windows_steam_games_on_mac_with_m/)
- Wine builds used by this project:
  [Gcenx/macOS_Wine_builds](https://github.com/Gcenx/macOS_Wine_builds)
- Reddit post about this project:
  [One-click solution to run Windows games on Apple...](https://www.reddit.com/r/macgaming/comments/1rflhp8/oneclick_solution_to_run_windows_games_on_apple/)

## Download

1. Click the green button `Code`, then `Download ZIP`.
2. Unzip the downloaded ZIP file (double-click it).

## Install / Run

### Simple: Spotlight-friendly launchers with game presets

#### Install:

1. In Finder, locate the unzipped folder.
2. Double-click `install_merlot.command`.
3. If macOS blocks it, right-click `install_merlot.command` -> `Open` -> confirm `Open`.
4. It installs `Merlot Apps` into `/Applications`.

#### Run:

1. Open one of the apps in `/Applications/Merlot Apps`, or find it in Spotlight:
   - `Steam (Merlot).app` to launch Steam without game-specific presets.
   - A game launcher, for example `Binding of Isaac (Merlot).app`, to use settings optimized for that game.
2. If macOS blocks it, right-click the app -> `Open` -> confirm `Open`.
3. After Steam launches, the Terminal window prints the Steam log path and can be closed. Steam stays running in the background. (Set `MERLOT_DETACH=0` if you prefer the old foreground behavior where closing Terminal kills Steam.)

`Merlot Apps` includes `Steam (Merlot).app` plus ready-made launchers for supported games in this repository.
Each game launcher includes presets and tweaks optimized for that game.

**Optional advanced setup:**<br>
If you want, you can add your own config in `merlot_configs/` and run `install_merlot.command` again to create another launcher. See the [Developer README](README_DEV.md).

**What to expect:**
- `install_merlot.command` may ask for your macOS password to install `Merlot Apps` into `/Applications`.
- The first time you launch a Merlot app, you may be asked for your macOS password (to install Rosetta if it is missing).
- The first launch can take a while because it downloads Wine, DXMT, and Steam installer.
- At the end, Steam should launch inside Wine.

### Advanced: Generic Steam launcher

1. In Finder, locate the unzipped folder.
2. Double-click `run.command`.
3. If macOS blocks it, right-click `run.command` -> `Open` -> confirm `Open`.
4. After Steam launches, the Terminal window prints the Steam log path and can be closed. Steam stays running in the background. (Set `MERLOT_DETACH=0` if you prefer the old foreground behavior where closing Terminal kills Steam.)

Use this option when you want the general Steam-in-Wine setup instead of a launcher tailored to a specific game.

If you are familiar with Terminal and bash, you can also customize launch options described in the [Developer README](README_DEV.md).

**What to expect:**
- The first time you run `run.command`, you may be asked for your macOS password (to install Rosetta if it is missing).
- The first launch can take a while because it downloads Wine, DXMT, and Steam installer.
- At the end, Steam should launch inside Wine.

## Stop

1. In Steam, use the menu: `Steam` -> `Exit`.
2. Wait until Steam fully closes.
3. You can close Terminal at any time; with the default `MERLOT_DETACH=1` behavior, Steam is detached from it.

## Uninstall

If Steam is running, follow the steps in "Stop" first.

1. Double-click `uninstall.command`.
2. If macOS blocks it, right-click `uninstall.command` -> `Open` -> confirm `Open`.
3. It may ask for your macOS password to remove `/Applications/Merlot Apps`.
4. It will ask for confirmation for each item it wants to remove. Type `y` to remove it, or `n` to skip it (if you want to keep something).

## Notes

- Apple Silicon only. Intel Macs are not supported by this script.
- Tested on:
  - Apple M1 Max (32GB), macOS Sequoia 15.7.4
  - Apple M2 Pro (16GB), macOS Sequoia 15.7.4

## What The Scripts Do (Short)

`run.command`:
- Installs Rosetta 2 (only if missing; requires `sudo`).
- Downloads Wine (Gcenx macOS Wine builds) and sets up a Steam Wine prefix.
- Downloads and installs Steam into that prefix.
- Downloads DXMT and enables it for Wine.

`uninstall.command`:
- Removes files/directories created by `run.command` (with per-item confirmation).
- Does not remove Rosetta 2.
