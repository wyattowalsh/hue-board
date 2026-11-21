import Foundation
import XCTest
@testable import HueBoardKit

final class HueSetupDocumentTests: XCTestCase {
    private let colors = ["#012345", "#ABCDEF", "#101010", "#F0F0F0"]
    private func draft(look: HuePreset, brightness: Double, seed: Int) -> HueStudioDraft {
        var settings = HueSceneSettings(engineSettings: .from(preset: look, brightness: brightness))
        settings.seed = seed
        return .init(settings: settings, sourceLookID: look.id, duration: 600, cuesEnabled: false)
    }

    func testRoundTripCarriesEachOverlappingFieldOnlyOnce() throws {
        let contract = try HueBoardContractLoader.load()
        let look = try XCTUnwrap(contract.presets.first)
        let source = draft(look: look, brightness: 55, seed: 773)
        let cues = HueCueSequence(presetIDs: [look.id], holdSeconds: 45, order: .shuffle, seed: 773)
        let layout = HueSetupRoom(scope: String(repeating: "a", count: 64), layout: .init(
            areaID: .init(rawValue: "synthetic-area"), placements: []
        ))
        let setup = HueSetupDocument(draft: source, palette: colors, cues: cues, cuesEnabled: true,
                                     mixes: [], favorites: [look.id], layout: layout,
                                     safety: .init(reduceLightMotion: true, maximumDynamicBrightness: 40))
        let bytes = try HuePortableDataCodec.encode(.setup(setup), contract: contract)
        XCTAssertEqual(try HuePortableDataCodec.decode(bytes, contract: contract), .setup(setup))
        let json = String(decoding: bytes, as: UTF8.self)
        for key in ["seed", "palette", "cues", "holdSeconds"] {
            XCTAssertEqual(json.components(separatedBy: "\"\(key)\":").count - 1, 1, key)
        }
        for key in ["customColors", "sequenceIds", "sequenceHold", "warningAcknowledged", "host", "mediaURL", "credential"] {
            XCTAssertFalse(json.contains("\"\(key)\":"), key)
        }
    }

    func testEveryStudioSelectionPreservesExcludedFields() throws {
        let contract = try HueBoardContractLoader.load()
        let look = try XCTUnwrap(contract.presets.first)
        var current = draft(look: look, brightness: 10, seed: 11)
        current.settings.sequenceHold = 300
        let source = draft(look: look, brightness: 55, seed: 773)
        let cues = HueCueSequence(presetIDs: [look.id], holdSeconds: 45, order: .shuffle, seed: 773)
        for mask in 1...7 {
            let hasDraft = mask & 1 != 0
            let hasPalette = mask & 2 != 0
            let hasCues = mask & 4 != 0
            let setup = HueSetupDocument(draft: hasDraft ? source : nil, palette: hasPalette ? colors : nil,
                                         cues: hasCues ? cues : nil, cuesEnabled: hasCues ? true : nil)
            let bytes = try HuePortableDataCodec.encode(.setup(setup), contract: contract)
            guard case .setup(let decoded) = try HuePortableDataCodec.decode(bytes, contract: contract) else {
                return XCTFail("Expected setup")
            }
            let updated = decoded.applyingStudioSections(decoded.availableSections, to: current)
            XCTAssertEqual(updated.settings.brightness, hasDraft ? 55 : 10)
            XCTAssertEqual(updated.settings.customColors, hasPalette ? colors : current.settings.customColors)
            XCTAssertEqual(updated.settings.sequenceHold, hasCues ? 45 : 300)
            XCTAssertEqual(updated.settings.seed, hasDraft || hasCues ? 773 : 11)
            XCTAssertEqual(updated.cuesEnabled, hasCues)
            XCTAssertEqual(decoded.applyingStudioSections(decoded.availableSections, to: updated), updated)
        }
    }

    func testRejectsUnknownSensitiveFieldsMalformedSeedsAndFutureSchema() throws {
        let contract = try HueBoardContractLoader.load()
        let bad = [
            #"{"format":"hue-board.setup","schema":2,"sections":{"favorites":[]}}"#,
            #"{"format":"hue-board.setup","schema":1,"sections":{"favorites":[],"seed":3}}"#,
            #"{"format":"hue-board.setup","schema":1,"sections":{"favorites":[],"mediaURL":"private"}}"#,
            #"{"format":"hue-board.setup","schema":1,"sections":{"safety":{"reduceLightMotion":true,"maximumDynamicBrightness":70,"warningAcknowledged":true}}}"#,
            #"{"format":"hue-board.setup","schema":1,"sections":{"cues":{"presetIDs":[],"holdSeconds":45,"order":"forward","enabled":true},"seed":5}}"#
        ]
        for data in bad {
            XCTAssertThrowsError(try HuePortableDataCodec.decode(Data(data.utf8), contract: contract))
        }
        let look = try XCTUnwrap(contract.presets.first)
        let setup = HueSetupDocument(draft: draft(look: look, brightness: 25, seed: 1),
                                     cues: .init(presetIDs: [look.id], holdSeconds: 45, order: .forward, seed: 2),
                                     cuesEnabled: false)
        XCTAssertThrowsError(try HuePortableDataCodec.encode(.setup(setup), contract: contract))
    }

    func testMultipleRoomEncodingAndSingleRoomBackwardCompatibility() throws {
        let contract = try HueBoardContractLoader.load()
        let a = HueSetupRoom(scope: String(repeating: "a", count: 64),
                             layout: .init(areaID: .init(rawValue: "a"), placements: []))
        let b = HueSetupRoom(scope: String(repeating: "b", count: 64),
                             layout: .init(areaID: .init(rawValue: "b"), placements: []))
        for rooms in [[a], [a, b]] {
            let setup = HueSetupDocument(layouts: rooms)
            let bytes = try HuePortableDataCodec.encode(.setup(setup), contract: contract)
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
            let fields = try XCTUnwrap(json["sections"] as? [String: Any])
            XCTAssertEqual(json["schema"] as? Int, rooms.count == 1 ? 1 : 2)
            XCTAssertEqual(Set(fields.keys), rooms.count == 1 ? ["layout"] : ["layouts"])
            XCTAssertEqual(try HuePortableDataCodec.decode(bytes, contract: contract), .setup(setup))
        }
        XCTAssertThrowsError(try HuePortableDataCodec.encode(.setup(.init(layouts: [a, a])), contract: contract))
    }
}
