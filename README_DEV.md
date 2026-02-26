# Developer README

This file documents implementation details for `run.sh` and `uninstall.sh`.

## Source

Inspired by:
https://www.reddit.com/r/macgaming/comments/1r8vsnj/how_to_play_windows_steam_games_on_mac_with_m/

## What `run.sh` Does

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

Defaults are the values in `run.sh`.

- `WINE_VERSION`
  - Wine build version to download (default: `11.3`)
- `DXMT_VERSION`
  - DXMT release version to download (default: `0.73`)
- `WINE_ROOT`
  - Where Wine is extracted (default: `~/wine-$WINE_VERSION`)
- `WINEPREFIX`
  - Where the Steam prefix lives (default: `~/.wine-steam-11`)
- `WINEPREFIX_ALIAS_NAME`
  - Name of the symlink created next to `run.sh` (default: `WINEPREFIX`)
- `WINE_RETINA_MODE`
  - `1` enables, `0` disables (default: `0`)
- `WINE_MOUSE_WARP_OVERRIDE`
  - Empty keeps Wine default (and removes the key if it was set before)
  - Allowed values: `force`, `enable`, `disable`

Example overrides (environment variables):

```bash
WINEPREFIX="$HOME/Games/SteamPrefix" WINE_RETINA_MODE=1 bash run.sh
```

## What `uninstall.sh` Removes

Targets are controlled by environment variables (defaults are the values in `uninstall.sh`):

- `WINE_VERSION`
- `WINE_ROOT`
- `WINEPREFIX`
- `DXMT_ROOT`
- `STEAM_SETUP`
- `WINEPREFIX_ALIAS_NAME`

Notes:

- `uninstall.sh` asks for confirmation per item and shows progress as `[X/N]`.
- `uninstall.sh` does not remove Rosetta 2.
- Use the same `WINE_VERSION`/`WINE_ROOT`/`WINEPREFIX` values you used with `run.sh` to uninstall the correct locations.

## Notes

- If Wine/DXMT/Steam are already present in the expected locations, `run.sh` skips those steps.
- The scripts do not change macOS system settings (pointer acceleration, polling rate, etc.).
- Tested on Apple M1 Max (32GB), macOS Sequoia 15.7.4.
