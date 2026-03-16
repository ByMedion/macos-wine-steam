# Developer README

This file documents implementation details for `run.command`, `uninstall.command`, and the Merlot `.app` bundles.

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
  - defaults `DXMT_LOG_LEVEL` to `error` unless already set by the caller
- Wine logging:
  - defaults `WINEDEBUG` to `-all,err+all` unless already set by the caller
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

Targets derived from environment variables (defaults are the values in `uninstall.command`):

- `WINE_VERSION`
- `WINE_ROOT`
- `WINEPREFIX`
- `DXMT_ROOT`
- `STEAM_SETUP`
- `WINEPREFIX_ALIAS_NAME`

Additional fixed targets:

- `Merlot Apps` in the repo root, `/Applications`, and `~/Applications`

Notes:

- `uninstall.command` asks for confirmation per item and shows progress as `[X/N]`.
- `uninstall.command` removes the generated `Merlot Apps` folder instead of tracking individual `.app` names.
- `uninstall.command` does not remove Rosetta 2.
- Use the same `WINE_VERSION`/`WINE_ROOT`/`WINEPREFIX` values you used with `run.command` to uninstall the correct locations.

## Notes

- If Wine/DXMT/Steam are already present in the expected locations, `run.command` skips those steps.
- The scripts do not change macOS system settings (pointer acceleration, polling rate, etc.).
- `SCRIPT_DIR` can be overridden via environment variable. When run inside the `.app` bundle, the launcher sets it to the directory containing the `.app` so the WINEPREFIX alias symlink lands next to the app instead of inside it.
- Tested on:
  - Apple M1 Max (32GB), macOS Sequoia 15.7.4
  - Apple M2 Pro (16GB), macOS Sequoia 15.7.4

## Merlot App Bundles

`build_merlot.sh` assembles a `Merlot Apps/` folder containing one macOS `.app` bundle per config in `merlot_configs/`.

### Structure

```
Merlot Apps/
  <APP_NAME>.app/
    Contents/
      Info.plist               # App metadata (Spotlight, Finder, Dock)
      MacOS/
        MerlotLauncher         # Shared launcher for all generated apps
      Resources/
        merlot.env             # Runtime env generated from merlot_configs/*.conf
        run.command            # Copied from repo root at build time
        AppIcon.icns           # Icon for that app
```

### How it works

1. `build_merlot.sh` reads each `merlot_configs/*.conf` file and generates one `.app` bundle per config inside `Merlot Apps/`.
2. Each bundle uses the shared `app/merlot/MerlotLauncher`, generated `Info.plist`, copied `run.command`, and an app-local `merlot.env`.
3. `MerlotLauncher` opens Terminal and runs the embedded `run.command` with the environment overrides listed in that app's `merlot.env`.
4. The launcher exports `SCRIPT_DIR` pointing to the directory containing the `.app`, so the shared `WINEPREFIX` alias symlink lands inside `Merlot Apps/`.

### Build

```bash
./build_merlot.sh
```

To build only one config:

```bash
./build_merlot.sh binding-of-isaac
```

To create a new config, copy the template:

```bash
cp merlot_configs/template.conf.example merlot_configs/my-game.conf
```

### Source files

- `app/merlot/MerlotLauncher` - shared launcher script for generated apps
- `app/merlot/AppIcon.icns` - app icon
- `merlot_configs/*.conf` - per-game launcher metadata and `run.command` environment overrides
- `merlot_configs/template.conf.example` - starting point for new game configs; not built by the script
- `build_merlot.sh` - assembles the `Merlot Apps/` folder
