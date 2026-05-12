#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="${SCRIPT_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)}"

WINE_VERSION="${WINE_VERSION:-11.8}"
DXMT_VERSION="${DXMT_VERSION:-0.74}"

WINE_ROOT="${WINE_ROOT:-$HOME/wine-${WINE_VERSION}}"
WINE_APP="${WINE_ROOT}/Wine Devel.app"
WINE_BIN="${WINE_APP}/Contents/Resources/wine/bin/wine"

WINEPREFIX="${WINEPREFIX:-$HOME/.wine-steam-11}"
STEAM_SETUP="/tmp/SteamSetup.exe"
DXMT_ROOT="${DXMT_ROOT:-$HOME/DXMT}"
# GPTK_PATH: optional. When set, the D3D translation backend switches from
# DXMT (default) to Apple's Game Porting Toolkit (D3DMetal). Point this at
# either the GPTK root directory or the folder that contains the .dll files
# (we probe a few common layouts). GPTK is NOT downloaded automatically --
# Apple's EULA forbids redistribution, so the user must obtain it from
# developer.apple.com themselves. DXMT is the default precisely because it
# has no such constraint.
GPTK_PATH="${GPTK_PATH:-}"
WINEPREFIX_ALIAS_NAME="${WINEPREFIX_ALIAS_NAME:-WINEPREFIX}"
WINE_RETINA_MODE="${WINE_RETINA_MODE:-0}" # 1=enable RetinaMode, 0=disable RetinaMode (Default)
# 1=detach Steam from the Terminal after launch so closing the window doesn't kill it (Default).
# 0=keep the original foreground behavior (Terminal window must stay open).
MERLOT_DETACH="${MERLOT_DETACH:-1}"
MERLOT_STEAM_LOG="${MERLOT_STEAM_LOG:-${TMPDIR:-/tmp}/merlot-steam.log}"
# Default before we added this: the value is not set in registry (Wine internal default).
# Set to force|enable|disable to override, or leave empty to keep default.
WINE_MOUSE_WARP_OVERRIDE="${WINE_MOUSE_WARP_OVERRIDE:-}"

WINE_URL="https://github.com/Gcenx/macOS_Wine_builds/releases/download/${WINE_VERSION}/wine-devel-${WINE_VERSION}-osx64.tar.xz"
STEAM_URL="https://cdn.cloudflare.steamstatic.com/client/installer/SteamSetup.exe"
DXMT_URL="https://github.com/3Shain/dxmt/releases/download/v${DXMT_VERSION}/dxmt-v${DXMT_VERSION}-builtin.tar.gz"

log() {
  printf "\n==> %s\n" "$1"
}

die() {
  printf "Error: %s\n" "$1" >&2
  exit 1
}

require_macos_arm64() {
  log "Checking platform"
  [[ "$(uname -s)" == "Darwin" ]] || die "This script supports macOS only."
  [[ "$(uname -m)" == "arm64" ]] || die "This script is intended for Apple Silicon (arm64)."
}

ensure_sudo_ready() {
  log "Preparing sudo session (needed for Rosetta install if missing)"
  sudo -v
}

ensure_rosetta() {
  log "Ensuring Rosetta 2"
  if /usr/bin/arch -x86_64 /usr/bin/true >/dev/null 2>&1; then
    echo "Rosetta is already available. Skipping."
    return
  fi

  ensure_sudo_ready
  sudo softwareupdate --install-rosetta --agree-to-license

  /usr/bin/arch -x86_64 /usr/bin/true >/dev/null 2>&1 || die "Rosetta installation check failed."
}

ensure_wine_installed() {
  log "Ensuring Wine ${WINE_VERSION} is installed"
  if [[ -x "${WINE_BIN}" ]]; then
    echo "Wine already installed at ${WINE_APP}. Skipping."
    return
  fi

  mkdir -p "${WINE_ROOT}"
  curl -L --fail --retry 5 --retry-delay 1 "${WINE_URL}" | tar xJf - -C "${WINE_ROOT}"
  [[ -x "${WINE_BIN}" ]] || die "Wine binary not found after extraction: ${WINE_BIN}"
}

ensure_wineprefix_alias() {
  log "Ensuring local alias to WINEPREFIX"
  local alias_path="${SCRIPT_DIR}/${WINEPREFIX_ALIAS_NAME}"
  local alias_dir
  alias_dir="$(dirname "${alias_path}")"

  if [[ -e "${alias_path}" && ! -L "${alias_path}" ]]; then
    echo "Path exists and is not a symlink: ${alias_path}. Skipping alias creation."
    return
  fi

  if [[ -L "${alias_path}" ]]; then
    local current_target
    current_target="$(readlink "${alias_path}")"
    if [[ "${current_target}" == "${WINEPREFIX}" ]]; then
      echo "Alias is already up to date: ${alias_path} -> ${WINEPREFIX}"
      return
    fi
  fi

  if [[ ! -d "${alias_dir}" ]]; then
    echo "Alias directory does not exist: ${alias_dir}. Skipping alias creation."
    return
  fi

  if [[ ! -w "${alias_dir}" ]]; then
    echo "Alias directory is not writable: ${alias_dir}. Skipping alias creation."
    return
  fi

  if ! ln -sfn "${WINEPREFIX}" "${alias_path}"; then
    echo "Could not create alias at ${alias_path}. Continuing without it."
    return
  fi

  echo "Alias created: ${alias_path} -> ${WINEPREFIX}"
}

setup_wine_env() {
  export WINEPREFIX
  export PATH
  PATH="$(dirname "${WINE_BIN}"):${PATH}"
}

ensure_wine_prefix() {
  log "Ensuring Wine prefix for Steam"
  if [[ -f "${WINEPREFIX}/system.reg" ]]; then
    echo "Wine prefix already initialized at ${WINEPREFIX}. Skipping."
    return
  fi
  "${WINE_BIN}" wineboot --init
}

ensure_wine_mouse_warp_override() {
  local mode="${WINE_MOUSE_WARP_OVERRIDE}"
  if [[ -z "${mode}" ]]; then
    log "Restoring default Wine MouseWarpOverride"
    if "${WINE_BIN}" reg query "HKCU\\Software\\Wine\\DirectInput" /v MouseWarpOverride >/dev/null 2>&1; then
      "${WINE_BIN}" reg delete "HKCU\\Software\\Wine\\DirectInput" /v MouseWarpOverride /f >/dev/null 2>&1 || true
      echo "Removed MouseWarpOverride from registry (Wine default behavior)."
    else
      echo "MouseWarpOverride is not set. Skipping."
    fi
    return
  fi

  case "${mode}" in
    force|enable|disable) ;;
    *) die "WINE_MOUSE_WARP_OVERRIDE must be one of: force | enable | disable | (empty for default)" ;;
  esac

  log "Configuring Wine MouseWarpOverride=${mode}"
  local query_out
  query_out="$("${WINE_BIN}" reg query "HKCU\\Software\\Wine\\DirectInput" /v MouseWarpOverride 2>/dev/null || true)"
  if printf "%s" "${query_out}" | grep -Eiq "MouseWarpOverride[[:space:]]+REG_SZ[[:space:]]+${mode}"; then
    echo "MouseWarpOverride is already set to ${mode}. Skipping."
    return
  fi

  "${WINE_BIN}" reg add "HKCU\\Software\\Wine\\DirectInput" /v MouseWarpOverride /t REG_SZ /d "${mode}" /f >/dev/null
  echo "Set MouseWarpOverride=${mode}."
}

ensure_wine_retina_mode() {
  local enabled="$1"
  [[ "${enabled}" == "0" || "${enabled}" == "1" ]] || die "WINE_RETINA_MODE must be 0 or 1."

  local desired_value="n"
  if [[ "${enabled}" == "1" ]]; then
    desired_value="y"
  fi

  log "Configuring Wine RetinaMode=${desired_value}"
  local query_out
  query_out="$("${WINE_BIN}" reg query "HKCU\\Software\\Wine\\Mac Driver" /v RetinaMode 2>/dev/null || true)"
  if printf "%s" "${query_out}" | grep -Eiq "RetinaMode[[:space:]]+REG_SZ[[:space:]]+${desired_value}"; then
    echo "RetinaMode is already set to ${desired_value}. Skipping."
    return
  fi

  "${WINE_BIN}" reg add "HKCU\\Software\\Wine\\Mac Driver" /v RetinaMode /t REG_SZ /d "${desired_value}" /f >/dev/null
  echo "Set RetinaMode=${desired_value}."
}

ensure_wine_windows_mouse_accel_disabled() {
  log "Disabling Windows mouse acceleration in Wine"

  # Disable Windows "Enhanced Pointer Precision" (mouse acceleration) inside the prefix.
  # This is independent from macOS pointer acceleration.
  "${WINE_BIN}" reg add "HKCU\\Control Panel\\Mouse" /v MouseSpeed /t REG_SZ /d 0 /f >/dev/null
  "${WINE_BIN}" reg add "HKCU\\Control Panel\\Mouse" /v MouseThreshold1 /t REG_SZ /d 0 /f >/dev/null
  "${WINE_BIN}" reg add "HKCU\\Control Panel\\Mouse" /v MouseThreshold2 /t REG_SZ /d 0 /f >/dev/null

  echo "Set MouseSpeed=0, MouseThreshold1=0, MouseThreshold2=0."
}

find_steam_exe() {
  local steam32="${WINEPREFIX}/drive_c/Program Files (x86)/Steam/steam.exe"
  local steam64="${WINEPREFIX}/drive_c/Program Files/Steam/steam.exe"
  if [[ -f "${steam32}" ]]; then
    printf "%s\n" "${steam32}"
  elif [[ -f "${steam64}" ]]; then
    printf "%s\n" "${steam64}"
  fi
}

cleanup_steam_setup() {
  if [[ -f "${STEAM_SETUP}" ]]; then
    log "Cleaning up Steam installer cache"
    rm -f "${STEAM_SETUP}"
    echo "Removed ${STEAM_SETUP}."
  fi
}

ensure_steam_installed() {
  log "Ensuring Steam is installed in Wine prefix"
  local steam_exe
  steam_exe="$(find_steam_exe || true)"
  if [[ -n "${steam_exe}" ]]; then
    echo "Steam already installed at ${steam_exe}. Skipping installer."
    return
  fi

  if [[ ! -f "${STEAM_SETUP}" ]]; then
    echo "Downloading Steam installer..."
    curl -L --fail --retry 5 --retry-delay 1 -o "${STEAM_SETUP}" "${STEAM_URL}"
  fi

  echo "Launching Steam installer. Complete the wizard in the Wine window."
  "${WINE_BIN}" "${STEAM_SETUP}"

  steam_exe="$(find_steam_exe || true)"
  [[ -n "${steam_exe}" ]] || die "Steam installation appears incomplete (steam.exe not found)."
  cleanup_steam_setup
}

ensure_dxmt_installed() {
  log "Ensuring DXMT ${DXMT_VERSION} is installed"
  if [[ -d "${DXMT_ROOT}/i386-windows" && -d "${DXMT_ROOT}/x86_64-windows" && -d "${DXMT_ROOT}/x86_64-unix" ]]; then
    echo "DXMT already installed at ${DXMT_ROOT}. Skipping."
    return
  fi

  local tmp_dir
  tmp_dir="$(mktemp -d /tmp/dxmt.XXXXXX)"

  curl -L --fail --retry 5 --retry-delay 1 "${DXMT_URL}" | tar xzf - -C "${tmp_dir}"

  local payload_dir=""
  if [[ -d "${tmp_dir}/i386-windows" && -d "${tmp_dir}/x86_64-windows" && -d "${tmp_dir}/x86_64-unix" ]]; then
    payload_dir="${tmp_dir}"
  elif [[ -d "${tmp_dir}/v${DXMT_VERSION}/i386-windows" && -d "${tmp_dir}/v${DXMT_VERSION}/x86_64-windows" && -d "${tmp_dir}/v${DXMT_VERSION}/x86_64-unix" ]]; then
    payload_dir="${tmp_dir}/v${DXMT_VERSION}"
  fi

  [[ -n "${payload_dir}" ]] || die "DXMT extraction failed: payload directories not found."

  mkdir -p "${DXMT_ROOT}"
  rm -rf "${DXMT_ROOT}/i386-windows" "${DXMT_ROOT}/x86_64-windows" "${DXMT_ROOT}/x86_64-unix"
  cp -R "${payload_dir}/i386-windows" "${DXMT_ROOT}/"
  cp -R "${payload_dir}/x86_64-windows" "${DXMT_ROOT}/"
  cp -R "${payload_dir}/x86_64-unix" "${DXMT_ROOT}/"
  rm -rf "${tmp_dir}"
}

enable_dxmt_env() {
  log "Enabling DXMT via WINEDLLPATH_PREPEND"
  export WINEDLLPATH_PREPEND
  case ":${WINEDLLPATH_PREPEND:-}:" in
    *":${DXMT_ROOT}:"*) ;;
    *) WINEDLLPATH_PREPEND="${DXMT_ROOT}${WINEDLLPATH_PREPEND:+:${WINEDLLPATH_PREPEND}}" ;;
  esac

  export DXMT_LOG_LEVEL="${DXMT_LOG_LEVEL:-error}"
  export WINEDEBUG="${WINEDEBUG:--all,err+all}"
}

use_gptk() {
  [[ -n "${GPTK_PATH}" ]]
}

find_gptk_dll_dir() {
  local root="$1"
  local candidates=(
    "${root}"
    "${root}/redist/lib/external"
    "${root}/lib/external"
    "${root}/lib"
    "${root}/Libraries"
  )
  local c
  for c in "${candidates[@]}"; do
    if [[ -f "${c}/d3d11.dll" ]]; then
      printf '%s\n' "${c}"
      return 0
    fi
  done
  return 1
}

ensure_gptk_installed() {
  log "Installing GPTK DLLs into the Wine prefix"
  [[ -d "${GPTK_PATH}" ]] || die "GPTK_PATH is not a directory: ${GPTK_PATH}"

  local src
  if ! src="$(find_gptk_dll_dir "${GPTK_PATH}")"; then
    die "Could not find d3d11.dll under GPTK_PATH=${GPTK_PATH}. Obtain the Game Porting Toolkit from developer.apple.com and point GPTK_PATH at the root (or directly at the folder containing the DLLs)."
  fi

  local target="${WINEPREFIX}/drive_c/windows/system32"
  [[ -d "${target}" ]] || die "Prefix system32 not found (is the prefix initialized?): ${target}"

  echo "Copying GPTK DLLs from ${src} to ${target}"
  local f copied=0
  for f in "${src}"/*.dll; do
    [[ -f "${f}" ]] || continue
    cp -f "${f}" "${target}/"
    copied=$((copied + 1))
  done
  [[ "${copied}" -gt 0 ]] || die "No .dll files found in ${src}"
  echo "Copied ${copied} DLL(s)."
}

enable_gptk_env() {
  log "Enabling GPTK via WINEDLLOVERRIDES"
  export WINEDLLOVERRIDES="${WINEDLLOVERRIDES:-d3d9,d3d10core,d3d11,d3d12,d3d12core,dxgi=n}"
  export WINEDEBUG="${WINEDEBUG:--all,err+all}"
  echo "WINEDLLOVERRIDES=${WINEDLLOVERRIDES}"
}

launch_steam() {
  log "Launching Steam"
  local steam_exe
  steam_exe="$(find_steam_exe || true)"
  [[ -n "${steam_exe}" ]] || die "steam.exe not found."

  local -a steam_cmd=("${WINE_BIN}" "${steam_exe}")
  if [[ -n "${STEAM_GAME_ID:-}" ]]; then
    echo "Launching Steam game ${STEAM_GAME_ID}..."
    steam_cmd+=(-applaunch "${STEAM_GAME_ID}")
  fi

  case "${MERLOT_DETACH}" in
    0)
      "${steam_cmd[@]}"
      ;;
    1)
      log "Detaching Steam from this Terminal (log: ${MERLOT_STEAM_LOG})"
      : >"${MERLOT_STEAM_LOG}" || die "Cannot write to ${MERLOT_STEAM_LOG}"
      nohup "${steam_cmd[@]}" </dev/null >>"${MERLOT_STEAM_LOG}" 2>&1 &
      disown
      echo "Steam is running in the background (PID $!). Safe to close this Terminal window."
      echo "Tail the log with: tail -f ${MERLOT_STEAM_LOG}"
      ;;
    *)
      die "MERLOT_DETACH must be 0 or 1."
      ;;
  esac
}

main() {
  require_macos_arm64
  ensure_rosetta
  ensure_wine_installed
  setup_wine_env
  ensure_wine_prefix
  ensure_wineprefix_alias
  ensure_wine_mouse_warp_override
  ensure_wine_retina_mode "${WINE_RETINA_MODE}"
  ensure_wine_windows_mouse_accel_disabled
  ensure_steam_installed
  if use_gptk; then
    ensure_gptk_installed
    enable_gptk_env
  else
    ensure_dxmt_installed
    enable_dxmt_env
  fi
  launch_steam
}

main "$@"
