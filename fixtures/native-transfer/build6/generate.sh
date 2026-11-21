#!/bin/sh
set -eu
if [ "$#" -ne 3 ]; then
  echo "Usage: sh hue030-generate-build6.sh CHECKOUT GENERATOR_SWIFT EMPTY_OUTPUT" >&2
  exit 2
fi
src=$1
entry=$2
output=$3
test "$(rtk proxy git -C "$src" rev-parse HEAD)" = 41bc092a3007fec03a79b7ab1d47a305d131e920
test -z "$(rtk proxy git -C "$src" status --porcelain --untracked-files=all -- ios/Packages/HueBoardKit)"
runner=$(mktemp -d "${TMPDIR:-/tmp}/hue-board-fixture-run.XXXXXXXX")
mkdir -p "$runner/Sources/FreezeBuild6"
ln -s "$src/ios/Packages/HueBoardKit" "$runner/HueBoardKit"
cp "$entry" "$runner/Sources/FreezeBuild6/main.swift"
cat > "$runner/Package.swift" <<'PACKAGE'
// swift-tools-version: 6.2
import PackageDescription
let package = Package(
    name: "FreezeBuild6", platforms: [.macOS(.v15)],
    dependencies: [.package(path: "HueBoardKit")],
    targets: [.executableTarget(name: "FreezeBuild6", dependencies: [.product(name: "HueBoardKit", package: "HueBoardKit")])]
)
PACKAGE
rtk proxy xcrun swift run --package-path "$runner" FreezeBuild6 "$output"
