# Developer README

This file documents implementation details for `run.command`, `uninstall.command`, and the `.app` bundles.

## Source

Inspired by:
https://www.reddit.com/r/macgaming/comments/1r8vsnj/how_to_play_windows_steam_games_on_mac_with_m/

## What `run.command` Does

- Checks platform:
  - macOS only
  - Apple Silicon (`arm64`) only
- Ensures Rosetta 2 is available:
  - triggers `sudo` because Rosetta installation may be required
- Downloads and extracts Wine:
  - Wine builds are downloaded from Gcenx macOS Wine builds
  - default Wine version is controlled by `WINE_VERSION`
  - extracted into `WINE_ROOT` (defaults to `~/wine-$WINE_VERSION`)
- Initializes the Wine prefix:
  - default prefix location is `WINEPREFIX` (defaults to `~/.wine-steam-11`)
- Creates/updates a symlink next to the scripts pointing at `WINEPREFIX`:
  - name controlled by `WINEPREFIX_ALIAS_NAME` (defaults to `WINEPREFIX`)
- Steam installation:
  - downloads `SteamSetup.exe` into `STEAM_SETUP` (defaults to `/tmp/SteamSetup.exe`)
  - runs the installer via Wine
  - deletes `STEAM_SETUP` after Steam is detected in the prefix
- DXMT:
  - downloads and installs into `DXMT_ROOT` (defaults to `~/DXMT`)
  - enables it via `WINEDLLPATH_PREPEND`
- Writes registry values inside the prefix:
  - `HKCU\\Software\\Wine\\Mac Driver\\RetinaMode` controlled by `WINE_RETINA_MODE` (`0`/`1`)
  - Disables Windows mouse acceleration (Enhanced Pointer Precision):
    - `HKCU\\Control Panel\\Mouse\\MouseSpeed = 0`
    - `HKCU\\Control Panel\\Mouse\\MouseThreshold1 = 0`
    - `HKCU\\Control Panel\\Mouse\\MouseThreshold2 = 0`
  - Optional DirectInput override:
    - `HKCU\\Software\\Wine\\DirectInput\\MouseWarpOverride` controlled by `WINE_MOUSE_WARP_OVERRIDE` (`force|enable|disable|empty`)

## Configuration (Environment Variables)

Defaults are the values in `run.command`.

- `WINE_VERSION`
  - Wine build version to download (default: `11.3`)
- `DXMT_VERSION`
  - DXMT release version to download (default: `0.73`)
- `WINE_ROOT`
  - Where Wine is extracted (default: `~/wine-$WINE_VERSION`)
- `WINEPREFIX`
  - Where the Steam prefix lives (default: `~/.wine-steam-11`)
- `WINEPREFIX_ALIAS_NAME`
  - Name of the symlink created next to `run.command` (default: `WINEPREFIX`)
- `WINE_RETINA_MODE`
  - `1` enables, `0` disables (default: `0`)
- `WINE_MOUSE_WARP_OVERRIDE`
  - Empty keeps Wine default (and removes the key if it was set before)
  - Allowed values: `force`, `enable`, `disable`

Example overrides (environment variables):

```bash
WINEPREFIX="$HOME/Games/SteamPrefix" WINE_RETINA_MODE=1 ./run.command
```

## What `uninstall.command` Removes

Targets are controlled by environment variables (defaults are the values in `uninstall.command`):

- `WINE_VERSION`
- `WINE_ROOT`
- `WINEPREFIX`
- `DXMT_ROOT`
- `STEAM_SETUP`
- `WINEPREFIX_ALIAS_NAME`

Notes:

- `uninstall.command` asks for confirmation per item and shows progress as `[X/N]`.
- `uninstall.command` does not remove Rosetta 2.
- Use the same `WINE_VERSION`/`WINE_ROOT`/`WINEPREFIX` values you used with `run.command` to uninstall the correct locations.

## Notes

- If Wine/DXMT/Steam are already present in the expected locations, `run.command` skips those steps.
- The scripts do not change macOS system settings (pointer acceleration, polling rate, etc.).
- `SCRIPT_DIR` can be overridden via environment variable. When run inside the `.app` bundle, the launcher sets it to the directory containing the `.app` so the WINEPREFIX alias symlink lands next to the app instead of inside it.
- Tested on:
  - Apple M1 Max (32GB), macOS Sequoia 15.7.4
  - Apple M2 Pro (16GB), macOS Sequoia 15.7.4

## The Binding of Merlot

`build_merlot.sh` assembles a macOS `.app` bundle that launches The Binding of Isaac: Rebirth through Steam in Wine.

### Structure

```
The Binding of Merlot.app/
  Contents/
    Info.plist                 # App metadata (Spotlight, Finder, Dock)
    MacOS/
      BindingOfMerlot          # Launcher: opens Terminal and runs run.command with STEAM_GAME_ID=250900
    Resources/
      run.command              # Copied from repo root at build time
      AppIcon.icns             # Wine glass + tears icon
```

### How it works

1. `build_merlot.sh` copies `app/merlot/Info.plist`, `app/merlot/BindingOfMerlot` (launcher), `app/merlot/AppIcon.icns`, and `run.command` into the `.app` directory structure.
2. When launched, `Contents/MacOS/BindingOfMerlot` uses `osascript` to open a Terminal window and run the embedded `run.command` with `STEAM_GAME_ID=250900`.
3. `run.command` sets up Wine/DXMT/Steam as usual, then launches Isaac directly via `steam.exe -applaunch 250900`.
4. The launcher exports `SCRIPT_DIR` pointing to the directory containing the `.app`, so the WINEPREFIX alias symlink is created next to the app (not buried inside it).

### Build

```bash
./build_merlot.sh
```

Then drag `The Binding of Merlot.app` to `/Applications` or `~/Applications`.

### Source files

- `app/merlot/Info.plist` — plist template
- `app/merlot/BindingOfMerlot` — launcher script (opens Terminal + runs `run.command` with game-specific overrides)
- `app/merlot/AppIcon.icns` — app icon
- `build_merlot.sh` — assembles the `.app` bundle
