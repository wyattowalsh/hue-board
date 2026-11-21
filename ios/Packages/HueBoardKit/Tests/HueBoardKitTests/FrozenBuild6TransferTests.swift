import Foundation
import XCTest
@testable import HueBoardKit

final class FrozenBuild6TransferTests: XCTestCase {
    private let names = ["canonical-v2", "cues", "draft", "favorites", "layout", "legacy-migrated-v2",
                         "legacy-v3", "mixes", "palette", "safety"]

    private func fixture(_ name: String, extension ext: String? = "json") throws -> Data {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "Build6Transfer"))
        return try Data(contentsOf: url)
    }

    private func read(_ name: String, _ contract: HueBoardContract) throws -> HuePortableData {
        try HuePortableDataCodec.decode(fixture(name), contract: contract)
    }

    func testFixtureBytesMatchFrozenManifest() throws {
        let manifest = try fixture("SHA256SUMS", extension: nil)
        let digest = fixtureSHA256(manifest)
        XCTAssertEqual(digest, "39cd556120966f39ebeb3a4eee830b5dd56f4eaf76d4fa5c8b8eab545aff4abd")
        var reconstructed = ""
        for name in names {
            let digest = try fixtureSHA256(fixture(name))
            reconstructed += digest + "  " + name + ".json\n"
        }
        XCTAssertEqual(Data(reconstructed.utf8), manifest)
    }

    func testEveryBuild6ExportAndLegacyOracleImportWithoutFieldDrift() throws {
        let contract = try HueBoardContractLoader.load()
        let colors = ["#103050", "#2468AC", "#ACE024", "#FEDCBA"]
        let ids = ["ion-eclipse", "deep-orbit"]
        let cues = HueCueSequence(presetIDs: ids, holdSeconds: 75, order: .shuffle, seed: 683)
        XCTAssertEqual(try read("palette", contract), .customPalette(colors))
        XCTAssertEqual(try read("cues", contract), .cues(cues))
        XCTAssertEqual(try read("favorites", contract), .favorites(ids))
        XCTAssertEqual(try read("safety", contract), .safety(.init(reduceLightMotion: true, maximumDynamicBrightness: 62)))
        let placement = HueFixturePlacement(id: .init(rawValue: "synthetic-light"), selected: true,
                                            x: 0.25, y: 0.75, phase: 0.5, trim: 0.8, ceiling: 47, role: .accent)
        XCTAssertEqual(try read("layout", contract),
                       .roomLayout(.init(areaID: .init(rawValue: "synthetic-area"), placements: [placement])))
        guard case .studioDraft(let draft) = try read("draft", contract),
              case .mixLibrary(let library) = try read("mixes", contract),
              let mix = library.first else { return XCTFail("Build 6 document was routed to the wrong section") }
        XCTAssertEqual(library.count, 1)
        XCTAssertEqual(mix.documentId, "synthetic-build6-mix")
        XCTAssertEqual(mix.settings, draft.settings)
        XCTAssertEqual(draft.duration, 900)
        XCTAssertEqual(draft.sourceLookID, ids[0])
        XCTAssertTrue(draft.cuesEnabled)
        XCTAssertEqual(draft.settings.brightness, 37)
        XCTAssertEqual(draft.settings.sequenceIds, ids)
        XCTAssertEqual(draft.settings.customColors, colors)
        XCTAssertEqual(draft.settings.seed, 683)
        XCTAssertEqual(try read("canonical-v2", contract), .mixLibrary(library))

        let legacy = try read("legacy-v3", contract)
        XCTAssertEqual(try read("legacy-migrated-v2", contract), legacy)
        guard case .mixLibrary(let migrated) = legacy else { return XCTFail("Legacy mix was lost") }
        XCTAssertEqual(migrated.first?.settings.brightness, 46)
        XCTAssertEqual(try HueSceneDocumentCodec.mergingLibrary(migrated, into: migrated, contract: contract), migrated)
        let new = HueSetupDocument(draft: draft, palette: colors, cues: cues, cuesEnabled: true,
                                   mixes: library + migrated, favorites: ids)
        let bytes = try HuePortableDataCodec.encode(.setup(new), contract: contract)
        XCTAssertEqual(try HuePortableDataCodec.decode(bytes, contract: contract), .setup(new))
        XCTAssertEqual(new.applyingStudioSections(new.availableSections, to: draft), draft)
    }
}
