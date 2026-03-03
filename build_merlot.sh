#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

APP_NAME="The Binding of Merlot"
BUILD_DIR="${SCRIPT_DIR}/${APP_NAME}.app"

log() {
  printf "==> %s\n" "$1"
}

die() {
  printf "Error: %s\n" "$1" >&2
  exit 1
}

log "Building ${APP_NAME}.app"

# Clean previous build
if [[ -d "${BUILD_DIR}" ]]; then
  log "Removing previous build"
  rm -rf "${BUILD_DIR}"
fi

# Create directory structure
mkdir -p "${BUILD_DIR}/Contents/MacOS"
mkdir -p "${BUILD_DIR}/Contents/Resources"

# Copy Info.plist
log "Copying Info.plist"
cp "${SCRIPT_DIR}/app/merlot/Info.plist" "${BUILD_DIR}/Contents/Info.plist"

# Create PkgInfo (standard macOS convention)
printf 'APPL????' > "${BUILD_DIR}/Contents/PkgInfo"

# Copy launcher
log "Copying launcher"
cp "${SCRIPT_DIR}/app/merlot/BindingOfMerlot" "${BUILD_DIR}/Contents/MacOS/BindingOfMerlot"
chmod +x "${BUILD_DIR}/Contents/MacOS/BindingOfMerlot"

# Copy icon
log "Copying icon"
cp "${SCRIPT_DIR}/app/merlot/AppIcon.icns" "${BUILD_DIR}/Contents/Resources/AppIcon.icns"

# Copy scripts
log "Copying run.command"
cp "${SCRIPT_DIR}/run.command" "${BUILD_DIR}/Contents/Resources/run.command"
chmod +x "${BUILD_DIR}/Contents/Resources/run.command"

log "Built: ${BUILD_DIR}"
echo ""
echo "To install, drag '${APP_NAME}.app' to /Applications (or ~/Applications)."
echo "Spotlight will index it once it is in an Applications folder."
