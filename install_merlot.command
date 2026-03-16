#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="${SCRIPT_DIR}/app/merlot"
CONFIGS_DIR="${SCRIPT_DIR}/merlot_configs"
INSTALL_ROOT="/Applications"
INSTALL_DIR="${INSTALL_ROOT}/Merlot Apps"
DEFAULT_ICON_PATH="${SCRIPT_DIR}/app/merlot/AppIcon.icns"
LAUNCHER_TEMPLATE="${TEMPLATE_DIR}/MerlotLauncher"
LAUNCHER_NAME="MerlotLauncher"

log() {
  printf "==> %s\n" "$1"
}

die() {
  printf "Error: %s\n" "$1" >&2
  exit 1
}

ensure_sudo_ready() {
  log "Preparing sudo session (needed to install into /Applications)"
  sudo -v
}

resolve_path() {
  local path="$1"
  local base_dir="$2"

  if [[ "${path}" = /* ]]; then
    [[ -e "${path}" ]] || die "Path does not exist: ${path}"
    printf "%s\n" "${path}"
    return
  fi

  if [[ -e "${base_dir}/${path}" ]]; then
    printf "%s\n" "${base_dir}/${path}"
    return
  fi

  if [[ -e "${SCRIPT_DIR}/${path}" ]]; then
    printf "%s\n" "${SCRIPT_DIR}/${path}"
    return
  fi

  die "Path does not exist: ${path}"
}

xml_escape() {
  local value="$1"
  value="${value//&/&amp;}"
  value="${value//</&lt;}"
  value="${value//>/&gt;}"
  printf "%s" "${value}"
}

write_info_plist() {
  local destination="$1"
  local app_name="$2"
  local bundle_id="$3"
  local app_version="$4"
  local min_system_version="$5"

  cat > "${destination}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>$(xml_escape "${app_name}")</string>
    <key>CFBundleDisplayName</key>
    <string>$(xml_escape "${app_name}")</string>
    <key>CFBundleExecutable</key>
    <string>${LAUNCHER_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>$(xml_escape "${bundle_id}")</string>
    <key>CFBundleVersion</key>
    <string>$(xml_escape "${app_version}")</string>
    <key>CFBundleShortVersionString</key>
    <string>$(xml_escape "${app_version}")</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>$(xml_escape "${min_system_version}")</string>
    <key>NSHumanReadableCopyright</key>
    <string>MIT License</string>
</dict>
</plist>
EOF
}

write_runtime_env() {
  local destination="$1"
  local env_name

  {
    printf 'APP_NAME=%q\n' "${APP_NAME}"
    printf 'RUN_ENV_NAMES=(\n'
    if (( ${#RUN_ENV_NAMES[@]} > 0 )); then
      for env_name in "${RUN_ENV_NAMES[@]}"; do
        printf '  %q\n' "${env_name}"
      done
    fi
    printf ')\n'

    if (( ${#RUN_ENV_NAMES[@]} > 0 )); then
      for env_name in "${RUN_ENV_NAMES[@]}"; do
        [[ "${!env_name+x}" == "x" ]] || die "Config ${config_path} is missing ${env_name}"
        printf '%s=%q\n' "${env_name}" "${!env_name}"
      done
    fi
  } > "${destination}"
}

collect_config_paths() {
  local arg
  local config_path

  if (( $# > 0 )); then
    for arg in "$@"; do
      if [[ -f "${arg}" ]]; then
        printf '%s\0' "${arg}"
        continue
      fi

      config_path="${CONFIGS_DIR}/${arg%.conf}.conf"
      [[ -f "${config_path}" ]] || die "Config not found: ${arg}"
      printf '%s\0' "${config_path}"
    done
    return
  fi

  shopt -s nullglob
  local config_paths=("${CONFIGS_DIR}"/*.conf)
  shopt -u nullglob

  (( ${#config_paths[@]} > 0 )) || die "No configs found in ${CONFIGS_DIR}"

  printf '%s\0' "${config_paths[@]}"
}

build_from_config() (
  set -euo pipefail

  local config_path="$1"
  local output_dir="$2"
  local config_dir
  config_dir="$(cd -- "$(dirname -- "${config_path}")" && pwd)"

  local APP_NAME=""
  local BUNDLE_ID=""
  local ICON_PATH="${DEFAULT_ICON_PATH}"
  local APP_VERSION="1.0"
  local LS_MINIMUM_SYSTEM_VERSION="11.0"
  local -a RUN_ENV_NAMES=()

  # shellcheck disable=SC1090
  source "${config_path}"

  [[ -n "${APP_NAME}" ]] || die "Config ${config_path} must set APP_NAME"
  [[ "${APP_NAME}" != */* ]] || die "APP_NAME must not contain '/' in ${config_path}"
  [[ -n "${BUNDLE_ID}" ]] || die "Config ${config_path} must set BUNDLE_ID"

  local icon_source
  icon_source="$(resolve_path "${ICON_PATH}" "${config_dir}")"

  local build_dir="${output_dir}/${APP_NAME}.app"

  log "Building ${APP_NAME}.app"

  rm -rf "${build_dir}"
  mkdir -p "${build_dir}/Contents/MacOS" "${build_dir}/Contents/Resources"

  write_info_plist \
    "${build_dir}/Contents/Info.plist" \
    "${APP_NAME}" \
    "${BUNDLE_ID}" \
    "${APP_VERSION}" \
    "${LS_MINIMUM_SYSTEM_VERSION}"

  printf 'APPL????' > "${build_dir}/Contents/PkgInfo"

  cp "${LAUNCHER_TEMPLATE}" "${build_dir}/Contents/MacOS/${LAUNCHER_NAME}"
  chmod +x "${build_dir}/Contents/MacOS/${LAUNCHER_NAME}"

  cp "${icon_source}" "${build_dir}/Contents/Resources/AppIcon.icns"
  cp "${SCRIPT_DIR}/run.command" "${build_dir}/Contents/Resources/run.command"
  chmod +x "${build_dir}/Contents/Resources/run.command"

  write_runtime_env "${build_dir}/Contents/Resources/merlot.env"
)

main() {
  local temp_root=""
  local output_dir=""
  local -a config_paths=()
  local config_path

  while IFS= read -r -d '' config_path; do
    config_paths+=("${config_path}")
  done < <(collect_config_paths "$@")

  (( ${#config_paths[@]} > 0 )) || die "No configs selected"

  ensure_sudo_ready
  temp_root="$(mktemp -d /tmp/merlot-apps.XXXXXX)"
  output_dir="${temp_root}/Merlot Apps"
  mkdir -p "${output_dir}"

  trap 'if [[ -n "${temp_root:-}" ]]; then rm -rf "${temp_root}"; fi' EXIT

  for config_path in "${config_paths[@]}"; do
    build_from_config "${config_path}" "${output_dir}"
  done

  log "Installing to ${INSTALL_DIR}"
  sudo rm -rf "${INSTALL_DIR}"
  sudo mkdir -p "${INSTALL_ROOT}"
  sudo cp -R "${output_dir}" "${INSTALL_ROOT}/"

  log "Installed app folder: ${INSTALL_DIR}"
  echo ""
  echo "Launch any app inside '/Applications/Merlot Apps' from Finder, Launchpad, or Spotlight."
}
main "$@"
