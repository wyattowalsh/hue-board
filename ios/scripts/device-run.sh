#!/usr/bin/env bash
set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly IOS_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly ROOT_DIR="$(cd -- "${IOS_DIR}/.." && pwd)"
readonly PROJECT_PATH="${IOS_DIR}/HueBoard.xcodeproj"
readonly SCHEME="HueBoard"
readonly XCODEGEN_COMMIT="8445e778451c7e44237b90281bde622d764b0084"
readonly DERIVED_DATA="${HUE_BOARD_DERIVED_DATA:-${IOS_DIR}/DerivedData/device}"
readonly RESULT_BUNDLE="${DERIVED_DATA}/HueBoard.xcresult"
readonly BUNDLE_ID="${HUE_BOARD_BUNDLE_ID:-com.wyattowalsh.HueBoard.dev}"
readonly TEAM_ID="${HUE_BOARD_TEAM_ID:-}"
readonly DEVICE_ID="${HUE_BOARD_DEVICE_ID:-}"
readonly XCODE_APP="${HUE_BOARD_XCODE_PATH:-}"

log() { printf '\n==> %s\n' "$*"; }
warn() { printf '\nwarning: %s\n' "$*" >&2; }
die() { printf '\nerror: %s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"; }

usage() {
  cat <<'EOF'
Usage: bash ios/scripts/device-run.sh <command>

Commands:
  preflight        Inspect macOS, Xcode, SDK, signing identities, and connected devices.
  prepare          Run source tests and generate the Xcode project.
  list             Prepare the project and list Xcode/devicectl destinations.
  simulator-build Build the unsigned generic iOS Simulator target.
  device-build     Build a signed Debug app for HUE_BOARD_DEVICE_ID.
  device-install   Install the previously built app on HUE_BOARD_DEVICE_ID.
  device-launch    Launch the installed app on HUE_BOARD_DEVICE_ID.
  device-run       Prepare, build, install, and launch on the physical iPhone.
  open             Prepare and open the generated Xcode project.

Physical-device commands read:
  HUE_BOARD_TEAM_ID       Apple Developer Team ID (required)
  HUE_BOARD_DEVICE_ID     Provisioning UDID (required)
  HUE_BOARD_BUNDLE_ID     Unique bundle ID (default: com.wyattowalsh.HueBoard.dev)
  HUE_BOARD_XCODE_PATH    Optional Xcode.app path, such as /Applications/Xcode-beta.app

Copy ios/device.env.example to ios/device.env and use the Makefile targets, or export
these values in the current shell. No credential, application key, or Bridge address
belongs in this file.
EOF
}

with_xcode() {
  if [[ -n "${XCODE_APP}" ]]; then
    DEVELOPER_DIR="${XCODE_APP%/}/Contents/Developer" "$@"
  else
    "$@"
  fi
}

require_macos_and_xcode() {
  [[ "$(uname -s)" == "Darwin" ]] || die "Apple-platform builds require macOS."
  need git
  need xcodebuild
  need xcrun
  need corepack
  need swift
  need security

  local version major developer_dir
  version="$(with_xcode xcodebuild -version | awk 'NR == 1 { print $2 }')"
  major="${version%%.*}"
  [[ "${major}" =~ ^[0-9]+$ ]] || die "Could not parse the Xcode version: ${version}"
  (( major >= 26 )) || die "Xcode 26 or newer is required; active version is ${version}."

  if [[ -n "${XCODE_APP}" ]]; then
    developer_dir="${XCODE_APP%/}/Contents/Developer"
  else
    developer_dir="$(xcode-select -p)"
  fi

  log "Apple toolchain"
  with_xcode xcodebuild -version
  printf 'Developer directory: %s\n' "${developer_dir}"
  printf 'iPhoneOS SDK: %s\n' "$(with_xcode xcrun --sdk iphoneos --show-sdk-version)"
}

show_signing_and_devices() {
  log "Available Apple Development signing identities"
  security find-identity -v -p codesigning 2>/dev/null \
    | grep -E 'Apple Development|iPhone Developer' \
    || warn "No Apple Development signing identity is currently visible. Add an Apple Account in Xcode and enable automatic signing."

  log "Connected and paired devices"
  if with_xcode xcrun devicectl list devices; then
    :
  else
    warn "devicectl could not list devices. Pair the iPhone in Xcode Device Hub, trust the Mac, and enable Developer Mode."
  fi
}

xcodegen_binary() {
  if command -v xcodegen >/dev/null 2>&1; then
    command -v xcodegen
    return
  fi

  local cache_root source binary
  cache_root="${HUE_BOARD_CACHE_DIR:-${HOME}/Library/Caches/HueBoard}"
  source="${cache_root}/XcodeGen-${XCODEGEN_COMMIT}"
  binary="${source}/.build/release/xcodegen"

  if [[ ! -x "${binary}" ]]; then
    log "Building pinned XcodeGen ${XCODEGEN_COMMIT}" >&2
    mkdir -p "${cache_root}"
    rm -rf "${source}"
    git clone --no-checkout https://github.com/yonaskolb/XcodeGen.git "${source}" >&2
    git -C "${source}" checkout --detach "${XCODEGEN_COMMIT}" >&2
    with_xcode swift build --package-path "${source}" -c release --product xcodegen >&2
  fi

  printf '%s\n' "${binary}"
}

prepare_source() {
  require_macos_and_xcode
  cd "${ROOT_DIR}"

  log "Repository revision"
  git rev-parse HEAD

  log "Installing pinned JavaScript dependencies"
  corepack prepare pnpm@10.17.1 --activate
  corepack pnpm install --frozen-lockfile

  log "Verifying the currently published Scriptable artifact"
  corepack pnpm verify:release

  log "Building source and generated assets"
  corepack pnpm build
  corepack pnpm export:ios-contract

  log "Checking generated native resources"
  git diff --exit-code -- \
    ios/Packages/HueBoardKit/Sources/HueBoardKit/Resources \
    ios/Packages/HueBoardKit/Sources/HueBoardAppleEngine/Resources

  log "Running source and timing regression suites"
  corepack pnpm test
  corepack pnpm test:timing

  log "Running shared Swift package tests"
  with_xcode swift test --package-path "${IOS_DIR}/Packages/HueBoardKit"

  local generator
  generator="$(xcodegen_binary)"
  log "Generating ${PROJECT_PATH}"
  "${generator}" generate --spec "${IOS_DIR}/project.yml" --project "${IOS_DIR}"
}

list_destinations() {
  prepare_source
  show_signing_and_devices
  log "Xcode scheme destinations"
  with_xcode xcodebuild \
    -project "${PROJECT_PATH}" \
    -scheme "${SCHEME}" \
    -showdestinations
}

simulator_build() {
  prepare_source
  log "Building generic iOS Simulator target"
  with_xcode xcodebuild \
    -project "${PROJECT_PATH}" \
    -scheme "${SCHEME}" \
    -configuration Debug \
    -sdk iphonesimulator \
    -destination 'generic/platform=iOS Simulator' \
    -derivedDataPath "${DERIVED_DATA}" \
    CODE_SIGNING_ALLOWED=NO \
    build
}

require_device_configuration() {
  [[ -n "${TEAM_ID}" ]] || die "Set HUE_BOARD_TEAM_ID or add it to ios/device.env."
  [[ -n "${DEVICE_ID}" ]] || die "Set HUE_BOARD_DEVICE_ID to the iPhone Provisioning UDID."
}

device_build() {
  prepare_source
  require_device_configuration
  rm -rf "${RESULT_BUNDLE}"

  log "Building signed Debug app for the selected iPhone"
  with_xcode xcodebuild \
    -project "${PROJECT_PATH}" \
    -scheme "${SCHEME}" \
    -configuration Debug \
    -destination "id=${DEVICE_ID}" \
    -derivedDataPath "${DERIVED_DATA}" \
    -resultBundlePath "${RESULT_BUNDLE}" \
    -allowProvisioningUpdates \
    -allowProvisioningDeviceRegistration \
    DEVELOPMENT_TEAM="${TEAM_ID}" \
    PRODUCT_BUNDLE_IDENTIFIER="${BUNDLE_ID}" \
    CODE_SIGN_STYLE=Automatic \
    build
}

built_app() {
  local app
  app="$(find "${DERIVED_DATA}/Build/Products/Debug-iphoneos" -maxdepth 1 -type d -name '*.app' -print -quit 2>/dev/null || true)"
  [[ -n "${app}" ]] || die "No built iPhone app found. Run device-build first."
  printf '%s\n' "${app}"
}

device_install() {
  require_macos_and_xcode
  require_device_configuration
  local app
  app="$(built_app)"
  log "Installing $(basename "${app}")"
  with_xcode xcrun devicectl device install app --device "${DEVICE_ID}" "${app}"
}

device_launch() {
  require_macos_and_xcode
  require_device_configuration
  log "Launching ${BUNDLE_ID}"
  with_xcode xcrun devicectl device process launch --device "${DEVICE_ID}" "${BUNDLE_ID}"
}

main() {
  case "${1:-}" in
    preflight)
      require_macos_and_xcode
      show_signing_and_devices
      ;;
    prepare) prepare_source ;;
    list) list_destinations ;;
    simulator-build) simulator_build ;;
    device-build) device_build ;;
    device-install) device_install ;;
    device-launch) device_launch ;;
    device-run)
      device_build
      device_install
      device_launch
      ;;
    open)
      prepare_source
      open "${PROJECT_PATH}"
      ;;
    help|-h|--help|'') usage ;;
    *) usage; die "Unknown command: $1" ;;
  esac
}

main "$@"
