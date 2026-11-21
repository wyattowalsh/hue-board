#!/bin/sh
set -eu

checkout=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd -P)
image='swift:6.2.3-noble@sha256:6dd90eb2359663a2cde8f03e9951f488b23134b3b8fce20e9dcb6cada75dd803'
case "${1:-}" in
    '')
        exec docker run --rm --network none --volume "$checkout:/product:ro" "$image" \
            sh /product/tests/native-appmodel/run.sh --container
        ;;
    --container)
        unset HUE_MODEL_JSC
        ;;
    --jsc)
        test "$(uname -s)" = Linux || { echo 'The optional JSCGTK runner requires Linux.' >&2; exit 1; }
        jsc=$(command -v "${HUE_MODEL_JSC:-jsc}") || { echo 'Install jsc or set HUE_MODEL_JSC.' >&2; exit 1; }
        HUE_MODEL_JSC=$(realpath "$jsc")
        HUE_MODEL_ENGINE_RESOURCES="$checkout/ios/Packages/HueBoardKit/Sources/HueBoardAppleEngine/Resources"
        export HUE_MODEL_JSC HUE_MODEL_ENGINE_RESOURCES
        ;;
    *) echo "Usage: sh $0 [--jsc]" >&2; exit 2 ;;
esac

scratch=$(mktemp -d)
trap 'rm -rf -- "$scratch"' EXIT
cd "$scratch"
app="$checkout/ios/App"
qa="$checkout/tests/native-appmodel"
mkdir -p Sources/Hue_Board Sources/CryptoKit Tests/HueModelTests
ln -s "$checkout" product
ln -s "$qa/Package.swift" Package.swift
ln -s "$qa/LinuxServices.swift" "$qa/LinuxEngine.swift" Sources/Hue_Board/
ln -s "$qa/SHA256.swift" Sources/CryptoKit/
ln -s "$checkout/ios/Packages/HueBoardKit/Sources/HueBoardKit/PersistenceChecksum.swift" Sources/CryptoKit/
for file in "$app"/AppModel*.swift "$app/RoomDiscoverySession.swift" \
    "$app/Services/StudioInputPreviewSession.swift" "$app/Services/StudioDocumentStore.swift" \
    "$app/Services/SetupImportStorage.swift"
do
    test -f "$file"
    ln -s "$file" Sources/Hue_Board/
done

suites='AcceptedRestoreReconciliationTests EmergencyAndConsentAppTests HueBoardAppTests HuePortableDataAppTests HueSetupFlowTests RoomArrangementDiscoveryTests RoomArrangementPersistenceTests SafetyEditsAppTests'
if [ "$1" = --jsc ]; then
    suites="$suites StudioRehearsalAppTests SweepRehearsalTests"
    set --
else
    set -- --skip RoomArrangementPersistenceTests.testSweepRequiresFreshEligibleMapAndOnlyCommitsApprovedPhases
fi
for suite in $suites; do
    file="$checkout/ios/Tests/AppTests/$suite.swift"
    test -f "$file"
    ln -s "$file" Tests/HueModelTests/
done

export XDG_CONFIG_HOME="$scratch/preferences"
export SWIFTPM_MODULECACHE_OVERRIDE="$scratch/cache"
mkdir -p "$XDG_CONFIG_HOME" "$SWIFTPM_MODULECACHE_OVERRIDE"
swift --version
swift test --cache-path "$scratch/cache" --jobs 2 "$@"
