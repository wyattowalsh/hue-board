import CryptoKit
import Foundation
import HueBoardKit

enum FixtureError: Error {
    case destinationRequired
    case nonemptyDestination
    case catalogMismatch
    case legacyNotMigrated
}

guard CommandLine.arguments.count == 2 else { throw FixtureError.destinationRequired }
let out = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let files = FileManager.default
try files.createDirectory(at: out, withIntermediateDirectories: true)
guard try files.contentsOfDirectory(atPath: out.path).isEmpty else { throw FixtureError.nonemptyDestination }
let contract = try HueBoardContractLoader.load()
guard let look = contract.preset(id: "ion-eclipse"), contract.preset(id: "deep-orbit") != nil else {
    throw FixtureError.catalogMismatch
}

let colors = ["#103050", "#2468AC", "#ACE024", "#FEDCBA"]
var settings = HueSceneSettings(engineSettings: .from(preset: look, brightness: 37))
settings.customColors = colors
settings.seed = 683
settings.sequenceIds = [look.id, "deep-orbit"]
settings.sequenceHold = 75
settings.sequenceOrder = "shuffle"

let mix = HueSceneDocumentCodec.makeDocument(name: "Transfer fixture", settings: settings,
    source: .init(productVersion: contract.release, implementation: "native"),
    documentId: "synthetic-build6-mix", now: Date(timeIntervalSince1970: 1_700_000_000))
let placement = HueFixturePlacement(id: .init(rawValue: "synthetic-light"), selected: true,
    x: 0.25, y: 0.75, phase: 0.5, trim: 0.8, ceiling: 47, role: .accent)
let values: [(String, HuePortableData)] = [
    ("draft", .studioDraft(.init(settings: settings, sourceLookID: look.id, duration: 900, cuesEnabled: true))),
    ("palette", .customPalette(colors)),
    ("cues", .cues(.init(presetIDs: settings.sequenceIds, holdSeconds: 75, order: .shuffle, seed: 683))),
    ("mixes", .mixLibrary([mix])),
    ("favorites", .favorites([look.id, "deep-orbit"])),
    ("layout", .roomLayout(.init(areaID: .init(rawValue: "synthetic-area"), placements: [placement]))),
    ("safety", .safety(.init(reduceLightMotion: true, maximumDynamicBrightness: 62)))
]
var output: [String: Data] = [:]
for (name, value) in values {
    output[name] = try HuePortableDataCodec.encode(value, contract: contract)
}
output["canonical-v2"] = try HueSceneDocumentCodec.encode(mix, contract: contract)
// Scriptable's older schema is import-only. Pin its input, and separately pin what build 6 migrated it to.
let legacy = Data(#"{"app":"hue-board","schema":3,"settings":{"brightness":46,"seed":214,"sequenceIds":["deep-orbit"]}}"#.utf8)
output["legacy-v3"] = legacy
guard case .mixLibrary(let migrated) = try HuePortableDataCodec.decode(legacy, contract: contract),
      migrated.count == 1, let document = migrated.first else { throw FixtureError.legacyNotMigrated }
output["legacy-migrated-v2"] = try HueSceneDocumentCodec.encode(document, contract: contract)

var checksums = ""
for key in output.keys.sorted() {
    guard let data = output[key] else { continue }
    let name = key + ".json"
    try data.write(to: out.appendingPathComponent(name), options: .withoutOverwriting)
    let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    checksums += digest + "  " + name + "\n"
}
try Data(checksums.utf8).write(to: out.appendingPathComponent("SHA256SUMS"), options: .withoutOverwriting)
print("Generated \(output.count) synthetic compatibility files.")
