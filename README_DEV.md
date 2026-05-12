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
- D3D translation backend (chosen by `GPTK_PATH`):
  - Default (DXMT):
    - downloads and installs into `DXMT_ROOT` (defaults to `~/DXMT`)
    - enables it via `WINEDLLPATH_PREPEND`
    - defaults `DXMT_LOG_LEVEL` to `error` unless already set by the caller
  - Opt-in (Apple Game Porting Toolkit / D3DMetal):
    - activated by setting `GPTK_PATH` to the GPTK root or directly to the folder containing its DLLs
    - common layouts are probed (`<path>`, `<path>/redist/lib/external`, `<path>/lib/external`, `<path>/lib`, `<path>/Libraries`)
    - copies the D3DMetal DLLs into `${WINEPREFIX}/drive_c/windows/system32/` and sets `WINEDLLOVERRIDES=d3d9,d3d10core,d3d11,d3d12,d3d12core,dxgi=n` (unless the caller already set `WINEDLLOVERRIDES`)
    - GPTK is **not** downloaded by this script -- Apple's EULA forbids redistribution, so you must obtain it from developer.apple.com yourself
    - a dedicated prefix (e.g. `WINEPREFIX=~/.wine-steam-gptk`) is recommended so GPTK and DXMT DLLs do not accumulate in the same prefix
- Launch mode:
  - Default (`MERLOT_DETACH=1`) runs Steam with `nohup ... & disown`, redirecting stdout/stderr to `${MERLOT_STEAM_LOG}` (defaults to `${TMPDIR:-/tmp}/merlot-steam.log`). The Terminal window can be closed immediately after launch without killing Steam.
  - `MERLOT_DETACH=0` preserves the pre-patch foreground behavior (Terminal window must stay open).
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
  - Wine build version to download (default: `11.8`)
  - Must exist as a `wine-devel-${WINE_VERSION}-osx64.tar.xz` asset in the [Gcenx macOS Wine builds](https://github.com/Gcenx/macOS_Wine_builds/releases). Gcenx prunes older releases periodically, so this default will need bumping over time.
- `DXMT_VERSION`
  - DXMT release version to download (default: `0.74`)
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
- `GPTK_PATH`
  - Empty (default) uses DXMT. When set, switches the D3D backend to Apple's Game Porting Toolkit (D3DMetal) and skips the DXMT download.
  - Point at either the GPTK root directory or the folder containing its DLLs.
- `MERLOT_DETACH`
  - `1` (default) detaches Steam from the launching Terminal so the window can be closed without killing Steam.
  - `0` keeps the old foreground behavior.
- `MERLOT_STEAM_LOG`
  - Path to the detached-mode Steam log (default: `${TMPDIR:-/tmp}/merlot-steam.log`).

Example overrides (environment variables):

```bash
WINEPREFIX="$HOME/Games/SteamPrefix" WINE_RETINA_MODE=1 ./run.command
```

GPTK example (user-supplied Game Porting Toolkit, dedicated prefix):

```bash
WINEPREFIX="$HOME/.wine-steam-gptk" \
GPTK_PATH="$HOME/Apple-GPTK" \
./run.command
```

## What `uninstall.command` Removes

Targets derived from environment variables (defaults are the values in `uninstall.command`):

- `WINE_VERSION`
- `WINE_ROOT`
- `WINEPREFIX`
- `DXMT_ROOT`
- `STEAM_SETUP`
- `WINEPREFIX_ALIAS_NAME`

Additional hardcoded target:

- `/Applications/Merlot Apps`

Notes:

- `uninstall.command` asks for confirmation per item and shows progress as `[X/N]`.
- `uninstall.command` uses `sudo` to remove `/Applications/Merlot Apps`.
- `uninstall.command` does not remove Rosetta 2.
- Use the same `WINE_VERSION`/`WINE_ROOT`/`WINEPREFIX` values you used with `run.command` to uninstall the correct locations.

## Notes

- If Wine/DXMT/Steam are already present in the expected locations, `run.command` skips those steps.
- The scripts do not change macOS system settings (pointer acceleration, polling rate, etc.).
- `SCRIPT_DIR` can be overridden via environment variable. When run inside the `.app` bundle, the launcher sets it to the directory containing the `.app` so the `WINEPREFIX` alias symlink lands next to the app bundle inside `Merlot Apps/`.
  - Alias creation is best-effort only. If `SCRIPT_DIR` is not writable (for example, `/Applications/Merlot Apps` after a sudo install), `run.command` skips the symlink and continues.
- Tested on:
  - Apple M1 Max (32GB), macOS Sequoia 15.7.4
  - Apple M2 Pro (16GB), macOS Sequoia 15.7.4

## Merlot App Bundles

`install_merlot.command` assembles `Merlot Apps/` in a temporary directory, then installs it into `/Applications/Merlot Apps`.

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
        run.command            # Copied from repo root at install time
        AppIcon.icns           # Icon for that app
```

### How it works

1. `install_merlot.command` reads each `merlot_configs/*.conf` file and generates one `.app` bundle per config inside `Merlot Apps/` in a temporary directory.
2. It asks for `sudo`, replaces `/Applications/Merlot Apps`, and copies the freshly generated folder there.
3. Each bundle uses the shared `app/merlot/MerlotLauncher`, generated `Info.plist`, copied `run.command`, and an app-local `merlot.env`.
4. `MerlotLauncher` opens Terminal and runs the embedded `run.command` with the environment overrides listed in that app's `merlot.env`.
5. The launcher exports `SCRIPT_DIR` pointing to the directory containing the `.app`, so the shared `WINEPREFIX` alias symlink lands in `/Applications/Merlot Apps/`.

### Install

```bash
./install_merlot.command
```

To install only one config:

```bash
./install_merlot.command binding-of-isaac
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
- `install_merlot.command` - assembles and installs the `Merlot Apps/` folder
