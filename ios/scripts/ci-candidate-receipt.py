"""Print allowlisted receipts for native qualification. Never emit test attachments."""

import json
from pathlib import Path
import plistlib
import re
import sys


def require(condition, message):
    if not condition:
        raise SystemExit(message)


def plist(path):
    with path.open("rb") as stream:
        return plistlib.load(stream)


def archive_receipt(path):
    ios = Path(__file__).resolve().parents[1]
    project = (ios / "project.yml").read_text()
    builds = re.findall(r'^\s*CURRENT_PROJECT_VERSION:\s*(\d+)\s*$', project, re.MULTILINE)
    versions = re.findall(r'^\s*MARKETING_VERSION:\s*(\d+(?:\.\d+){1,2})\s*$', project, re.MULTILINE)
    require(len(builds) == len(versions) == 1, "Cannot identify the core app version and build in its project specification.")
    build, version = builds[0], versions[0]
    bundle = "com.wyattowalsh.HueBoard"
    app = path / "Products/Applications/Hue Board.app"
    info = plist(app / "Info.plist")
    archive_info = plist(path / "Info.plist")["ApplicationProperties"]
    for metadata in (archive_info, info):
        require(metadata["CFBundleIdentifier"] == bundle and metadata["CFBundleVersion"] == build
                and metadata["CFBundleShortVersionString"] == version, "Unexpected archive or app identity.")
    declared = plist(ios / "App/Info.plist")
    for key in ("NSMicrophoneUsageDescription", "NSLocalNetworkUsageDescription", "NSBonjourServices"):
        require(bool(declared[key]) and info.get(key) == declared[key], "Usage declarations differ from source.")
    manifest = plist(app / "PrivacyInfo.xcprivacy")
    require(manifest == plist(ios / "App/PrivacyInfo.xcprivacy"), "Packaged privacy manifest differs from source.")
    require(manifest.get("NSPrivacyTracking") is False and manifest.get("NSPrivacyTrackingDomains") == []
            and manifest.get("NSPrivacyCollectedDataTypes") == []
            and manifest.get("NSPrivacyAccessedAPITypes") == [{
                "NSPrivacyAccessedAPIType": "NSPrivacyAccessedAPICategoryUserDefaults",
                "NSPrivacyAccessedAPITypeReasons": ["CA92.1"],
            }], "Unexpected core privacy declarations.")
    print(f"Unsigned core archive {version} ({build}). App identity, permission strings and privacy manifest verified.")


def package_counts(path):
    # The existing serial SwiftPM XCTest runner emits terminal case lines on Darwin.
    # Ignore every free-form diagnostic and never copy failure messages into the summary.
    cases = re.findall(r"^Test Case '([^'\r\n]+)' (passed|failed|skipped) \(", path.read_text(errors="replace"), re.M)
    require(bool(cases), "No completed Swift package test cases were recorded.")
    passed, failed, skipped = (sum(outcome == value for _, outcome in cases) for value in ("passed", "failed", "skipped"))
    print(f"Swift package tests: {len(cases)} recorded, {passed} passed, {failed} failed, {skipped} skipped.")
    for method in ("testSharedRuntimeMatchesGeneratedParityDigest", "testImportSurvivesProcessDeath"):
        matches = [outcome for case, outcome in cases if case.rstrip("]").endswith(method)]
        require(matches == ["passed"], f"No unique passing receipt for {method}.")
        print(f"{method} passed.")


def simulator_counts(path):
    summary = json.loads(path.read_text())
    fields = ("totalTestCount", "passedTests", "failedTests", "skippedTests", "expectedFailures")
    require(all(type(summary.get(key)) is int and summary[key] >= 0 for key in fields),
            "The simulator returned an unsupported test summary.")
    total, passed, failed, skipped, expected = (summary[key] for key in fields)
    print(f"Simulator app and UI tests: {total} recorded, {passed} passed, {failed} failed, "
          f"{skipped} skipped, {expected} expected failures.")
    require(total == passed and passed > 0 and failed == skipped == expected == 0,
            "A complete passing simulator receipt requires positive passes and zero failures, skips or expected failures.")


if __name__ == "__main__":
    operations = {"archive": archive_receipt, "package-counts": package_counts, "simulator-counts": simulator_counts}
    require(len(sys.argv) == 3 and sys.argv[1] in operations, "Expected receipt type and result path.")
    try:
        operations[sys.argv[1]](Path(sys.argv[2]))
    except (OSError, KeyError, ValueError, TypeError, plistlib.InvalidFileException):
        sys.exit("The requested receipt is absent, invalid or incomplete.")
