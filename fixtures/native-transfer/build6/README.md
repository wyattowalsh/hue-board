# Native build 6 transfer fixtures

The producer uses the HueBoardKit package from commit `41bc092a3007fec03a79b7ab1d47a305d131e920`, the source revision of native 0.2.2 (6). Inputs have fixed synthetic fixture IDs, a fixed mix ID and creation time, and explicit Studio settings. The program runs locally without Bridge or device access.

The corpus was generated on Xcode 27.2 on November 21, 2026. The SHA-256 of the 10-entry digest manifest is `39cd556120966f39ebeb3a4eee830b5dd56f4eaf76d4fa5c8b8eab545aff4abd`. The generator source SHA-256 is `6c39e700bd1e4d2812989a5511a5ec5dd061aac68ee1510dfe6fee4c76681269`.

The seven native-data files are direct outputs of the schema 1 codec. The canonical scene file is the same mix exported through the scene v2 codec. Legacy Scriptable schema 3 supports import. The producer preserves its synthetic input and the canonical v2 document that build 6 produced when it migrated the input. Comparing the current decoder to that historic document detects changes in its generated ID, dates and settings.

From an empty output directory on the source Mac, run the generator against a separate clean checkout of the pinned revision. Supply absolute paths.

```sh
rtk proxy sh fixtures/native-transfer/build6/generate.sh \
  "$BUILD6_CHECKOUT" "$PWD/fixtures/native-transfer/build6/Generate.swift" "$OUTPUT_DIR"
(cd "$OUTPUT_DIR" && shasum -a 256 -c SHA256SUMS)
```

The wrapper verifies the producer revision and package cleanliness before building an isolated SwiftPM executable. It refuses a nonempty fixture output directory. The current package test checks each file against the frozen digest manifest, exercises all seven single-section readers, compares the canonical and legacy migration results, and carries the decoded composition into a setup document. [Frozen package test](../../../ios/Packages/HueBoardKit/Tests/HueBoardKitTests/FrozenBuild6TransferTests.swift) · [Fixture bytes](../../../ios/Packages/HueBoardKit/Tests/HueBoardKitTests/Fixtures/Build6Transfer)
