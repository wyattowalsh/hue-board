#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
IOS_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly IOS_DIR
ROOT_DIR="$(cd -- "${IOS_DIR}/.." && pwd)"
readonly ROOT_DIR
readonly MIN_XCODE_MAJOR=27
readonly MIN_XCODE_MINOR=2
readonly MIN_IPHONEOS_SDK_MAJOR=27
readonly MIN_IPHONEOS_SDK_MINOR=2
readonly DERIVED_DATA="${HUE_BOARD_DERIVED_DATA:-${IOS_DIR}/DerivedData/device}"
readonly REPORT_PATH="${DERIVED_DATA}/preflight.txt"

if [[ -f "${IOS_DIR}/device.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "${IOS_DIR}/device.env"
  set +a
fi

readonly TEAM_ID="${HUE_BOARD_TEAM_ID:-}"
readonly DEVICE_ID="${HUE_BOARD_DEVICE_ID:-}"
readonly BUNDLE_ID="${HUE_BOARD_BUNDLE_ID:-com.wyattowalsh.HueBoard.dev}"
readonly XCODE_APP="${HUE_BOARD_XCODE_PATH:-}"

log() { printf '\n==> %s\n' "$*"; }
warn() { printf '\nwarning: %s\n' "$*" >&2; }
die() { printf '\nerror: %s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"; }

with_xcode() {
  if [[ -n "${XCODE_APP}" ]]; then
    DEVELOPER_DIR="${XCODE_APP%/}/Contents/Developer" "$@"
  else
    "$@"
  fi
}

version_at_least() {
  local value="$1" required_major="$2" required_minor="$3"
  local major minor ignored
  IFS='.' read -r major minor ignored <<< "${value}"
  [[ "${major}" =~ ^[0-9]+$ && "${minor:-0}" =~ ^[0-9]+$ ]] || return 1
  (( major > required_major || (major == required_major && ${minor:-0} >= required_minor) ))
}

main() {
  [[ "$(uname -s)" == "Darwin" ]] || die "iPhone qualification requires macOS."
  for command in git xcodebuild xcrun corepack swift security; do need "${command}"; done

  local xcode_version sdk_version identities device_output repository_clean xcode_selection
  xcode_version="$(with_xcode xcodebuild -version | awk 'NR == 1 { print $2 }')"
  sdk_version="$(with_xcode xcrun --sdk iphoneos --show-sdk-version)"

  version_at_least "${xcode_version}" "${MIN_XCODE_MAJOR}" "${MIN_XCODE_MINOR}" \
    || die "Xcode ${MIN_XCODE_MAJOR}.${MIN_XCODE_MINOR} or newer is required for release qualification; active version is ${xcode_version}."
  version_at_least "${sdk_version}" "${MIN_IPHONEOS_SDK_MAJOR}" "${MIN_IPHONEOS_SDK_MINOR}" \
    || die "iPhoneOS SDK ${MIN_IPHONEOS_SDK_MAJOR}.${MIN_IPHONEOS_SDK_MINOR} or newer is required; active SDK is ${sdk_version}."

  [[ -n "${TEAM_ID}" ]] || die "Set HUE_BOARD_TEAM_ID in ios/device.env."
  [[ -n "${DEVICE_ID}" ]] || die "Set HUE_BOARD_DEVICE_ID in ios/device.env."
  [[ "${BUNDLE_ID}" =~ ^[A-Za-z0-9][A-Za-z0-9.-]*$ ]] \
    || die "HUE_BOARD_BUNDLE_ID must be a reverse-DNS-style identifier without spaces or wildcards."

  identities="$(security find-identity -v -p codesigning 2>/dev/null \
    | grep -E 'Apple Development|iPhone Developer' || true)"
  [[ -n "${identities}" ]] \
    || die "No Apple Development signing identity is visible. Sign in through Xcode and enable automatic signing."

  device_output="$(with_xcode xcrun devicectl list devices 2>&1)" \
    || die "devicectl could not list devices. Pair the iPhone in Xcode Device Hub, trust the Mac, unlock it, and enable Developer Mode."
  grep -Fq "${DEVICE_ID}" <<< "${device_output}" \
    || die "Configured HUE_BOARD_DEVICE_ID is not visible to devicectl. Run 'make iphone-list' and update ios/device.env."

  if [[ -z "$(git -C "${ROOT_DIR}" status --porcelain --untracked-files=no)" ]]; then
    repository_clean=yes
  else
    repository_clean=no
    warn "Tracked repository changes are present. The build may proceed, but it is not release-evidence clean."
  fi

  if [[ -n "${XCODE_APP}" ]]; then xcode_selection=custom; else xcode_selection=system; fi

  mkdir -p "${DERIVED_DATA}"
  cat > "${REPORT_PATH}" <<EOF
Hue Board iPhone qualification preflight
repository_commit=$(git -C "${ROOT_DIR}" rev-parse HEAD)
repository_clean=${repository_clean}
xcode_version=${xcode_version}
iphoneos_sdk=${sdk_version}
xcode_selection=${xcode_selection}
bundle_id=${BUNDLE_ID}
signing_identity_present=yes
configured_device_visible=yes
supported_surface=iphone-portrait
team_id_recorded=no
device_identifier_recorded=no
EOF

  log "Qualification doctor passed"
  cat "${REPORT_PATH}"
  printf 'Sanitized report: %s\n' "${REPORT_PATH}"
}

main "$@"
