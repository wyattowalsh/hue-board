import Foundation

public struct HueStudioDraft: Codable, Equatable, Sendable {
    public var settings: HueSceneSettings
    public var sourceLookID: String
    public var duration: TimeInterval
    public var cuesEnabled: Bool

    public init(settings: HueSceneSettings, sourceLookID: String, duration: TimeInterval, cuesEnabled: Bool) {
        self.settings = settings
        self.sourceLookID = sourceLookID
        self.duration = duration
        self.cuesEnabled = cuesEnabled
    }
}

/// The transferable preferences intentionally exclude device-local consent.
public struct HueSafetyPreferences: Codable, Equatable, Sendable {
    public let reduceLightMotion: Bool
    public let maximumDynamicBrightness: Double

    public init(reduceLightMotion: Bool, maximumDynamicBrightness: Double) {
        self.reduceLightMotion = reduceLightMotion
        self.maximumDynamicBrightness = maximumDynamicBrightness
    }

    public func applying(to current: PhysicalLightSafetySettings) -> PhysicalLightSafetySettings {
        .init(
            warningAcknowledged: current.warningAcknowledged,
            reduceLightMotion: reduceLightMotion,
            maximumDynamicBrightness: maximumDynamicBrightness
        )
    }
}

public enum HuePortableData: Equatable, Sendable {
    case studioDraft(HueStudioDraft)
    case customPalette([String])
    case cues(HueCueSequence)
    case mixLibrary([HueSceneDocument])
    case favorites([String])
    case roomLayout(HueRoomLayout)
    case safety(HueSafetyPreferences)
    case setup(HueSetupDocument)
}

public enum HuePortableDataCodec {
    public static let maximumFileSize = 512 * 1024

    private static let format = "hue-board.native-data"
    private static let schema = 1

    private enum Kind: String, Codable {
        case studioDraft, customPalette, cues, mixLibrary, favorites, roomLayout, safety
    }

    private struct Header: Decodable {
        let format: String
        let schema: Int
        let kind: Kind
    }

    private struct File<Payload: Codable>: Codable {
        let format: String
        let schema: Int
        let kind: Kind
        let payload: Payload
    }

    public static func encode(_ value: HuePortableData, contract: HueBoardContract) throws -> Data {
        try validate(value, contract: contract)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        func encodePayload<Payload: Codable>(_ payload: Payload, as kind: Kind) throws -> Data {
            try encoder.encode(File(format: format, schema: schema, kind: kind, payload: payload))
        }
        let data = switch value {
        case .studioDraft(let draft): try encodePayload(draft, as: .studioDraft)
        case .customPalette(let colors): try encodePayload(colors, as: .customPalette)
        case .cues(let cues): try encodePayload(cues, as: .cues)
        case .mixLibrary(let documents): try encodePayload(documents, as: .mixLibrary)
        case .favorites(let ids): try encodePayload(ids, as: .favorites)
        case .roomLayout(let layout): try encodePayload(layout, as: .roomLayout)
        case .safety(let preferences): try encodePayload(preferences, as: .safety)
        case .setup(let setup): try HueSetupCodec.encode(setup)
        }
        try checkSize(data)
        return data
    }

    public static func decode(_ data: Data, contract: HueBoardContract) throws -> HuePortableData {
        try checkSize(data)
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw HueBoardError.invalidResponse("Choose a Hue Board JSON document.")
        }
        if root["format"] as? String == HueSetupCodec.format {
            return .setup(try HueSetupCodec.decode(root: root, contract: contract))
        }
        guard root["format"] as? String == format else {
            let result = try HueSceneDocumentCodec.decode(data, contract: contract)
            return .mixLibrary([result.document])
        }
        let decoder = JSONDecoder()
        guard Set(root.keys) == ["format", "schema", "kind", "payload"],
              let header = try? decoder.decode(Header.self, from: data),
              header.schema == schema else {
            throw HueBoardError.invalidResponse("This Hue Board file format or version is unsupported.")
        }
        func decodePayload<Payload: Codable>(_ type: Payload.Type) throws -> Payload {
            try decoder.decode(File<Payload>.self, from: data).payload
        }
        let value: HuePortableData
        switch header.kind {
        case .studioDraft: value = .studioDraft(try decodePayload(HueStudioDraft.self))
        case .customPalette: value = .customPalette(try decodePayload([String].self))
        case .cues: value = .cues(try decodePayload(HueCueSequence.self))
        case .mixLibrary:
            guard let documents = root["payload"] as? [[String: Any]],
                  documents.count <= HueSceneDocumentCodec.maximumLibraryCount else {
                throw HueBoardError.invalidResponse("This file exceeds the Studio library limit or is malformed.")
            }
            value = .mixLibrary(try documents.map { document in
                let documentData = try JSONSerialization.data(withJSONObject: document)
                return try HueSceneDocumentCodec.decode(documentData, contract: contract).document
            })
        case .favorites: value = .favorites(try decodePayload([String].self))
        case .roomLayout: value = .roomLayout(try decodePayload(HueRoomLayout.self))
        case .safety: value = .safety(try decodePayload(HueSafetyPreferences.self))
        }
        try validate(value, contract: contract)
        return value
    }

    private static func checkSize(_ data: Data) throws {
        guard data.count <= maximumFileSize else {
            throw HueBoardError.unsupported("Hue Board files must be 512 KB or smaller.")
        }
    }

    static func validate(_ value: HuePortableData, contract: HueBoardContract) throws {
        switch value {
        case .setup(let setup):
            try HueSetupCodec.validate(setup, contract: contract)
        case .studioDraft(let draft):
            try HueSceneDocumentCodec.validate(draft.settings, contract: contract)
            try validatePortableColors(draft.settings.customColors)
            guard contract.preset(id: draft.sourceLookID) != nil, (300...3_600).contains(draft.duration) else {
                throw HueBoardError.invalidResponse("The Studio draft has an invalid source look or session duration.")
            }
            if draft.cuesEnabled {
                try HueCueSequence(
                    presetIDs: draft.settings.sequenceIds,
                    holdSeconds: draft.settings.sequenceHold,
                    order: HueCueOrder(rawValue: draft.settings.sequenceOrder) ?? .forward,
                    seed: draft.settings.seed
                ).validate(contract: contract)
            }
        case .customPalette(let colors):
            try validatePortableColors(colors)
        case .cues(let cues):
            guard (0...999_999).contains(cues.seed) else {
                throw HueBoardError.invalidResponse("The cue sequence has an invalid random seed.")
            }
            if cues.presetIDs.isEmpty {
                guard (30...600).contains(cues.holdSeconds) else {
                    throw HueBoardError.invalidResponse("The cue hold time must be 30–600 seconds.")
                }
            } else {
                try cues.validate(contract: contract)
            }
        case .mixLibrary(let documents):
            try HueSceneDocumentCodec.validateLibrary(documents, contract: contract)
        case .favorites(let ids):
            let knownIDs = Set(contract.presets.map(\.id))
            guard ids.count == Set(ids).count, ids.allSatisfy(knownIDs.contains) else {
                throw HueBoardError.invalidResponse("The favorites file contains unknown or duplicate looks.")
            }
        case .roomLayout(let layout):
            try layout.validatePlacements()
        case .safety(let preferences):
            guard (10...100).contains(preferences.maximumDynamicBrightness) else {
                throw HueBoardError.invalidResponse("The maximum dynamic brightness must be 10–100%.")
            }
        }
    }

    private static func validatePortableColors(_ colors: [String]) throws {
        guard colors.count == 4, colors.allSatisfy({ color in
            color.utf8.count == 7 && color.range(of: "#[0-9A-Fa-f]{6}", options: .regularExpression) != nil
        }) else {
            throw HueBoardError.invalidResponse("A custom palette requires four colors in #RRGGBB format.")
        }
    }
}
