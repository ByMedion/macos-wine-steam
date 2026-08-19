#!/usr/bin/env bash
#
# install-wrapper.sh -- build and/or deploy the steamwebhelper CEF wrapper.
#
# Steam's client UI renders as a solid black window under Wine on Apple
# Silicon. CEF's ANGLE D3D11 backend cannot query the DXGI adapter, falls back
# to GLES 2.0 (CEF needs 3.0), disables the GPU, and then paints its
# transparent-background window black. Steam's own -cef-* flags do not fix it:
# the flags that matter have to reach steamwebhelper.exe itself.
#
# The fix is a small wrapper that takes steamwebhelper.exe's place, injects
# --disable-gpu --single-process, and delegates to the renamed original.
#
# Usage:
#   install-wrapper.sh                # build if needed, then deploy
#   install-wrapper.sh --build-only   # build into the cache, do not deploy
#   install-wrapper.sh --deploy-only  # deploy cached binary (no toolchain needed)
#
# Environment:
#   WINEPREFIX              prefix to deploy into (default ~/.wine-steam-11)
#   MERLOT_WRAPPER_CACHE    where the built .exe is cached
#                           (default ~/.merlot/cef-wrapper/steamwebhelper.exe)
#   MERLOT_WRAPPER_AUTO_BREW=1  install mingw-w64 via Homebrew without asking
set -euo pipefail

WRAPPER_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
WINEPREFIX="${WINEPREFIX:-$HOME/.wine-steam-11}"
MERLOT_WRAPPER_CACHE="${MERLOT_WRAPPER_CACHE:-$HOME/.merlot/cef-wrapper/steamwebhelper.exe}"
CEF_ROOT="${WINEPREFIX}/drive_c/Program Files (x86)/Steam/bin/cef"

# Valve's steamwebhelper.exe is a multi-megabyte Chromium bundle; ours is well
# under 500 KB. Size is how we tell the two apart, which stays correct even
# when a rebuild changes the wrapper's checksum.
WRAPPER_SIZE_CEILING=500000

mode="both"
case "${1:-}" in
  --build-only)  mode="build" ;;
  --deploy-only) mode="deploy" ;;
  "")            mode="both" ;;
  *) printf "Usage: %s [--build-only|--deploy-only]\n" "$0" >&2; exit 2 ;;
esac

log() { printf "==> %s\n" "$1"; }
die() { printf "Error: %s\n" "$1" >&2; exit 1; }

find_mingw() {
  local candidate
  candidate="$(command -v x86_64-w64-mingw32-gcc 2>/dev/null || true)"
  if [[ -n "${candidate}" ]]; then
    printf "%s\n" "${candidate}"
    return 0
  fi
  if command -v brew >/dev/null 2>&1; then
    candidate="$(brew --prefix 2>/dev/null)/bin/x86_64-w64-mingw32-gcc"
    if [[ -x "${candidate}" ]]; then
      printf "%s\n" "${candidate}"
      return 0
    fi
  fi
  return 1
}

ensure_mingw() {
  local cc
  if cc="$(find_mingw)"; then
    printf "%s\n" "${cc}"
    return 0
  fi

  command -v brew >/dev/null 2>&1 || die \
"mingw-w64 is required to build the wrapper, and Homebrew was not found.
Install Homebrew (https://brew.sh) then run: brew install mingw-w64"

  if [[ "${MERLOT_WRAPPER_AUTO_BREW:-0}" != "1" ]]; then
    printf "\n" >&2
    printf "The Steam UI fix needs the mingw-w64 cross-compiler (a few hundred MB).\n" >&2
    printf "Install it with Homebrew now? [y/N] " >&2
    local reply=""
    read -r reply </dev/tty || true
    case "${reply}" in
      y|Y|yes|YES) ;;
      *) die "Declined. Install it yourself with: brew install mingw-w64" ;;
    esac
  fi

  log "Installing mingw-w64 via Homebrew"
  brew install mingw-w64 || die "brew install mingw-w64 failed"

  cc="$(find_mingw)" || die "mingw-w64 still not found after install"
  printf "%s\n" "${cc}"
}

build_wrapper() {
  local cc
  cc="$(ensure_mingw)"

  log "Building steamwebhelper wrapper"
  mkdir -p "$(dirname "${MERLOT_WRAPPER_CACHE}")"
  make -C "${WRAPPER_DIR}" clean >/dev/null 2>&1 || true
  make -C "${WRAPPER_DIR}" CC="${cc}" >/dev/null \
    || die "Wrapper build failed"

  [[ -f "${WRAPPER_DIR}/steamwebhelper.exe" ]] \
    || die "Wrapper binary missing after build"

  mv -f "${WRAPPER_DIR}/steamwebhelper.exe" "${MERLOT_WRAPPER_CACHE}"
  echo "Built ${MERLOT_WRAPPER_CACHE} ($(wc -c < "${MERLOT_WRAPPER_CACHE}" | tr -d ' ') bytes)"
}

is_wrapper_like() {
  local path="$1"
  [[ -f "${path}" ]] || return 1
  (( $(stat -f%z "${path}") < WRAPPER_SIZE_CEILING ))
}

deploy_wrapper() {
  [[ -f "${MERLOT_WRAPPER_CACHE}" ]] \
    || die "No wrapper binary at ${MERLOT_WRAPPER_CACHE}. Run: $0 --build-only"
  [[ -d "${CEF_ROOT}" ]] \
    || die "Steam CEF directory not found: ${CEF_ROOT}"

  local installed=0 cef_dir target real
  while IFS= read -r -d '' cef_dir; do
    target="${cef_dir}/steamwebhelper.exe"
    real="${cef_dir}/steamwebhelper_real.exe"

    if [[ ! -f "${target}" ]]; then
      echo "No steamwebhelper.exe in ${cef_dir}. Skipping."
      continue
    fi

    if is_wrapper_like "${target}"; then
      # Never copy a wrapper over the stash -- that would destroy Valve's binary.
      if [[ ! -f "${real}" ]] || is_wrapper_like "${real}"; then
        die "${cef_dir}: Valve's original steamwebhelper.exe is gone. Reinstall Steam to recover."
      fi
    else
      # target is Valve's. Preserve it before we overwrite.
      if [[ ! -f "${real}" ]] || is_wrapper_like "${real}"; then
        cp "${target}" "${real}" || die "Failed to stash Valve binary to ${real}"
      elif [[ "$(md5 -q "${target}")" != "$(md5 -q "${real}")" ]]; then
        # Steam updated its helper; refresh the stash so we delegate to the
        # current build rather than a stale one.
        cp "${target}" "${real}" || die "Failed to refresh ${real}"
      fi
    fi

    cp "${MERLOT_WRAPPER_CACHE}" "${target}" || die "Failed to install wrapper to ${target}"
    installed=$((installed + 1))
  done < <(find "${CEF_ROOT}" -maxdepth 1 -type d -name "cef.win*" -print0)

  (( installed > 0 )) || die "No cef.win* directories found under ${CEF_ROOT}"
  log "Wrapper active in ${installed} CEF directory/directories"
}

case "${mode}" in
  build)  build_wrapper ;;
  deploy) deploy_wrapper ;;
  both)
    [[ -f "${MERLOT_WRAPPER_CACHE}" ]] || build_wrapper
    deploy_wrapper
    ;;
esac
