# Steam + Wine + DXMT Runner (Apple Silicon)

This repo contains a single launcher script, `run.sh`, that sets up:
- Rosetta (if needed)
- Wine Staging (downloaded from Gcenx macOS Wine builds)
- a Steam Wine prefix
- DXMT (installed into `~/DXMT`, enabled via `WINEDLLPATH_PREPEND`)

Then it launches Steam.

## Source

Inspired by this Reddit post:
https://www.reddit.com/r/macgaming/comments/1r8vsnj/how_to_play_windows_steam_games_on_mac_with_m/

## Run

From the repo directory:

```bash
sh run.sh
```

## What `run.sh` does

- Installs Rosetta 2 if missing (requires `sudo`).
- Creates/uses `WINE_ROOT` (default `~/wine-<version>`).
- Creates/uses `WINEPREFIX` (default `~/.wine-steam-11`).
- Creates a symlink in the repo directory pointing to `WINEPREFIX`:
  - `./WINEPREFIX` by default (configurable via `WINEPREFIX_ALIAS_NAME`)
- Downloads `SteamSetup.exe` into `/tmp`.
- Installs DXMT into `~/DXMT` and prepends that path via `WINEDLLPATH_PREPEND`.
- Writes a few Wine registry values inside the prefix:
  - `HKCU\\Software\\Wine\\Mac Driver\\RetinaMode` (controlled via `WINE_RETINA_MODE`)
  - Windows mouse acceleration disable (Enhanced Pointer Precision):
    - `HKCU\\Control Panel\\Mouse\\MouseSpeed = 0`
    - `HKCU\\Control Panel\\Mouse\\MouseThreshold1 = 0`
    - `HKCU\\Control Panel\\Mouse\\MouseThreshold2 = 0`
  - Optional DirectInput mouse warp override:
    - `HKCU\\Software\\Wine\\DirectInput\\MouseWarpOverride` (controlled via `WINE_MOUSE_WARP_OVERRIDE`)

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

Example:

```bash
WINEPREFIX="$HOME/Games/SteamPrefix" WINE_RETINA_MODE=1 ./run.sh
```

## Notes

- Tested on Apple M1 Max (32GB), macOS Sequoia 15.7.4.
- If Steam/Wine/DXMT are already installed in the expected locations, the script skips those steps.
- Mouse settings in macOS (pointer acceleration, polling rate, etc.) are not changed by the script.
