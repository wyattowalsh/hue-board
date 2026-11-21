#!/usr/bin/env python3
"""Verify the packaged Hue Board engine and golden frames with the JavaScriptCore CLI."""

import argparse
import hashlib
import json
import math
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile


SOURCES = Path(__file__).resolve().parents[1] / "ios/Packages/HueBoardKit/Sources"
DRIVER = r"""
function fixed(value) {
    return (Math.abs(value) < 5e-12 ? 0 : value).toFixed(11);
}
for (const preset of contract.presets) {
    // HueEngineSettings.from(preset:brightness:), with the golden seed and topology.
    const settings = {
        ...contract.defaults,
        showA: preset.pattern, showB: preset.pattern,
        paletteA: preset.palette, paletteB: preset.palette,
        brightness: golden.brightness, speed: preset.speed, depth: preset.depth,
        energy: preset.energy, focus: preset.focus, seed: golden.seed, topology: golden.topology
    };
    for (const time of golden.times) {
        for (const position of golden.positions) {
            const frame = HueBoardEngineBridge.sample(time, position, settings, 0);
            const values = [time, position, ...frame.rgb, frame.brightness];
            if (values.length !== 6 || !values.every(Number.isFinite)) {
                throw new Error("Invalid frame for " + [preset.id, time, position].join("/"));
            }
            print([preset.id, ...values.map(fixed)].join("|") + "\t" + JSON.stringify([preset.id, ...values]));
        }
    }
}
"""


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def verify_frames(output, golden):
    frames = {}
    canonical = []
    for line_number, line in enumerate(output.splitlines(), 1):
        encoded, separator, raw = line.partition("\t")
        if not separator:
            raise ValueError(f"unexpected JSC output on line {line_number}: {line[:160]}")
        preset, time, position, red, green, blue, brightness = json.loads(raw)
        key = (preset, time, position)
        if key in frames:
            raise ValueError(f"duplicate frame {key}")
        numbers = [time, position, red, green, blue, brightness]
        if not all(math.isfinite(value) for value in numbers):
            raise ValueError(f"nonfinite frame {key}")
        decimals = [format(0 if abs(value) < 5e-12 else value, ".11f") for value in numbers]
        independent = "|".join([preset, *decimals])
        if encoded != independent:
            raise ValueError(f"fixed-11 formatting differs for {key}: JSC {encoded}, Python {independent}")
        canonical.append(independent + "\n")
        frames[key] = [red, green, blue, brightness]

    if len(frames) != golden["caseCount"]:
        raise ValueError(f"expected {golden['caseCount']} unique frames, received {len(frames)}")
    digest = sha256("".join(canonical).encode())
    if digest != golden["sha256"]:
        raise ValueError(f"frame SHA-256 {digest} differs from golden {golden['sha256']}")

    anchors = set()
    for anchor in golden["anchors"]:
        key = (anchor["preset"], anchor["time"], anchor["position"])
        if key in anchors or key not in frames:
            raise ValueError(f"duplicate or missing golden anchor {key}")
        anchors.add(key)
        expected = [*anchor["rgb"], anchor["brightness"]]
        if len(expected) != 4 or not all(
            math.isclose(actual, target, rel_tol=0, abs_tol=1e-9)
            for actual, target in zip(frames[key], expected)
        ):
            raise ValueError(f"anchor {key}: observed {frames[key]}, expected {expected} within 1e-9")
    return digest


def run(executable):
    resources = SOURCES / "HueBoardKit/Resources"
    engine = SOURCES / "HueBoardAppleEngine/Resources"
    runtime = engine / "engine-runtime.js"
    contract = json.loads((resources / "hue-board-contract.json").read_bytes())
    golden = json.loads((resources / "engine-golden.json").read_bytes())
    manifest = json.loads((engine / "engine-manifest.json").read_bytes())
    if sha256(runtime.read_bytes()) != manifest["sha256"]:
        raise ValueError(f"{runtime.name} does not match engine-manifest.json")
    if not contract["release"] == golden["release"] == manifest["release"]:
        raise ValueError("contract, golden and runtime manifests identify different releases")
    if (golden["schema"], golden["algorithm"], golden["numberFormat"]) != (2, "sha256", "fixed-11-posix"):
        raise ValueError("expected schema 2, sha256 and fixed-11-posix in engine-golden.json")
    counts = (len(contract["presets"]), len(golden["times"]), len(golden["positions"]),
              golden["caseCount"], len(golden["anchors"]))
    if counts != (32, 4, 4, 512, 8):
        raise ValueError(f"unexpected preset/time/position/frame/anchor counts: {counts}")

    with tempfile.TemporaryDirectory(prefix="hue-jsc-") as temp:
        driver = Path(temp) / "sample.js"
        driver.write_text(f"const contract = {json.dumps(contract)};\nconst golden = {json.dumps(golden)};\n" + DRIVER,
                          encoding="utf-8")
        for mode, flags in (("default", []), ("interpreter", ["--useJIT=false"])):
            result = subprocess.run([executable, *flags, str(runtime), str(driver)],
                                    capture_output=True, text=True, timeout=30)
            if result.returncode:
                detail = (result.stderr.strip() or result.stdout.strip())[-800:]
                raise ValueError(f"JSC {mode} exited {result.returncode}: {detail}")
            if result.stderr.strip():
                print(f"JSC {mode}: {result.stderr.strip()[-800:]}", file=sys.stderr)
            try:
                digest = verify_frames(result.stdout, golden)
            except (KeyError, TypeError, ValueError) as error:
                raise ValueError(f"JSC {mode}: {error}") from error
            print(f"{mode}: 512 frames, eight anchors, independent fixed-11, SHA-256 {digest}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--jsc", default="jsc", metavar="PATH", help="JavaScriptCore CLI (default: jsc on PATH)")
    args = parser.parse_args()
    executable = shutil.which(args.jsc)
    if executable is None:
        parser.error(f"could not find executable {args.jsc!r}; install the JSC CLI or pass --jsc /path/to/jsc")
    try:
        run(executable)
    except (OSError, KeyError, TypeError, ValueError, subprocess.TimeoutExpired) as error:
        parser.exit(1, f"parity verification failed: {error}\n")


if __name__ == "__main__":
    main()
