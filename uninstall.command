#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

WINE_VERSION="${WINE_VERSION:-11.3}"
WINE_ROOT="${WINE_ROOT:-$HOME/wine-${WINE_VERSION}}"
WINEPREFIX="${WINEPREFIX:-$HOME/.wine-steam-11}"
DXMT_ROOT="${DXMT_ROOT:-$HOME/DXMT}"
STEAM_SETUP="${STEAM_SETUP:-/tmp/SteamSetup.exe}"
WINEPREFIX_ALIAS_NAME="${WINEPREFIX_ALIAS_NAME:-WINEPREFIX}"
MERLOT_APPS_DIR_NAME="Merlot Apps"
SYSTEM_APPLICATIONS_DIR="/Applications"
TOTAL_STEPS=6
CURRENT_STEP=0

log() {
  printf "\n==> %s\n" "$1"
}

ensure_sudo_ready() {
  log "Preparing sudo session (needed to remove /Applications/Merlot Apps)"
  sudo -v
}

confirm() {
  local prompt="$1"
  local reply=""
  read -r -p "${prompt} [y/N]: " reply
  [[ "${reply}" == "y" || "${reply}" == "Y" ]]
}

step_prefix() {
  printf "[%d/%d]" "${CURRENT_STEP}" "${TOTAL_STEPS}"
}

remove_file() {
  local path="$1"
  local label="$2"
  CURRENT_STEP=$((CURRENT_STEP + 1))

  if [[ -f "${path}" ]]; then
    if confirm "$(step_prefix) Delete ${label}: ${path}?"; then
      rm -f "${path}"
      echo "$(step_prefix) Deleted: ${path}"
    else
      echo "$(step_prefix) Skipped: ${path}"
    fi
    return
  fi

  echo "$(step_prefix) Not found: ${path}"
}

remove_dir() {
  local path="$1"
  local label="$2"
  CURRENT_STEP=$((CURRENT_STEP + 1))

  if [[ -d "${path}" ]]; then
    if [[ "${path}" == "/" ]]; then
      echo "$(step_prefix) Refusing to delete root directory."
      return
    fi
    if confirm "$(step_prefix) Delete ${label}: ${path}?"; then
      rm -rf "${path}"
      echo "$(step_prefix) Deleted: ${path}"
    else
      echo "$(step_prefix) Skipped: ${path}"
    fi
    return
  fi

  echo "$(step_prefix) Not found: ${path}"
}

remove_dir_sudo() {
  local path="$1"
  local label="$2"
  CURRENT_STEP=$((CURRENT_STEP + 1))

  if [[ -d "${path}" ]]; then
    if [[ "${path}" == "/" ]]; then
      echo "$(step_prefix) Refusing to delete root directory."
      return
    fi
    if confirm "$(step_prefix) Delete ${label}: ${path}?"; then
      sudo rm -rf "${path}"
      echo "$(step_prefix) Deleted: ${path}"
    else
      echo "$(step_prefix) Skipped: ${path}"
    fi
    return
  fi

  echo "$(step_prefix) Not found: ${path}"
}

remove_alias_path() {
  local path="$1"
  CURRENT_STEP=$((CURRENT_STEP + 1))

  if [[ -L "${path}" ]]; then
    if confirm "$(step_prefix) Delete symlink alias: ${path}?"; then
      rm -f "${path}"
      echo "$(step_prefix) Deleted: ${path}"
    else
      echo "$(step_prefix) Skipped: ${path}"
    fi
    return
  fi

  if [[ -e "${path}" ]]; then
    echo "$(step_prefix) Alias path exists but is not a symlink: ${path}. Skipping for safety."
    return
  fi

  echo "$(step_prefix) Not found: ${path}"
}

main() {
  ensure_sudo_ready

  log "Uninstall targets detected"
  echo "1. STEAM_SETUP: ${STEAM_SETUP}"
  echo "2. WINEPREFIX alias: ${SCRIPT_DIR}/${WINEPREFIX_ALIAS_NAME}"
  echo "3. Installed Merlot app folder: ${SYSTEM_APPLICATIONS_DIR}/${MERLOT_APPS_DIR_NAME}"
  echo "4. WINEPREFIX: ${WINEPREFIX}"
  echo "5. DXMT_ROOT: ${DXMT_ROOT}"
  echo "6. WINE_ROOT: ${WINE_ROOT}"

  log "Removing artifacts from run.command and Merlot app folders"
  remove_file "${STEAM_SETUP}" "Steam installer file"
  remove_alias_path "${SCRIPT_DIR}/${WINEPREFIX_ALIAS_NAME}"
  remove_dir_sudo "${SYSTEM_APPLICATIONS_DIR}/${MERLOT_APPS_DIR_NAME}" "Installed Merlot app folder"
  remove_dir "${WINEPREFIX}" "Wine prefix directory"
  remove_dir "${DXMT_ROOT}" "DXMT directory"
  remove_dir "${WINE_ROOT}" "Wine root directory"

  log "Done"
}

main "$@"
