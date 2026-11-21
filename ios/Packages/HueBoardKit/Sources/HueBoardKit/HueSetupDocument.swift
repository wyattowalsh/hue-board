import Foundation

public enum HueSetupSection: String, CaseIterable, Hashable, Sendable {
    case draft, palette, cues, mixes, favorites, layout, safety

    public var title: String {
        switch self {
        case .draft: "Studio draft"
        case .palette: "Custom palette"
        case .cues: "Cue sequence"
        case .mixes: "Saved mixes"
        case .favorites: "Scene favorites"
        case .layout: "Room layouts"
        case .safety: "Physical-light safety preferences"
        }
    }
}

public struct HueSetupRoom: Codable, Equatable, Sendable {
    /// A one-way binding of the source Bridge and area. A setup never includes host or pairing data.
    public let scope: String
    public let layout: HueRoomLayout

    public init(scope: String, layout: HueRoomLayout) {
        self.scope = scope
        self.layout = layout
    }
}

/// Palette, cues and the shared seed each have one owner on disk. A missing section means preserve it.
public struct HueSetupDocument: Equatable, Sendable {
    public let draft: HueStudioDraft?
    public let palette: [String]?
    public let cues: HueCueSequence?
    public let cuesEnabled: Bool?
    public let mixes: [HueSceneDocument]?
    public let favorites: [String]?
    public let layouts: [HueSetupRoom]
    public var layout: HueSetupRoom? { layouts.count == 1 ? layouts.first : nil }
    public let safety: HueSafetyPreferences?

    public init(
        draft: HueStudioDraft? = nil, palette: [String]? = nil, cues: HueCueSequence? = nil,
        cuesEnabled: Bool? = nil, mixes: [HueSceneDocument]? = nil, favorites: [String]? = nil,
        layout: HueSetupRoom? = nil, layouts: [HueSetupRoom] = [], safety: HueSafetyPreferences? = nil
    ) {
        self.draft = draft.map {
            var value = $0
            let defaults = HueSceneSettings()
            value.settings.customColors = defaults.customColors
            value.settings.sequenceIds = defaults.sequenceIds
            value.settings.sequenceHold = defaults.sequenceHold
            value.settings.sequenceOrder = defaults.sequenceOrder
            value.cuesEnabled = false
            return value
        }
        self.palette = palette
        self.cues = cues
        self.cuesEnabled = cuesEnabled
        self.mixes = mixes
        self.favorites = favorites
        self.layouts = layouts + (layout.map { [$0] } ?? [])
        self.safety = safety
    }

    public var availableSections: Set<HueSetupSection> {
        var result = Set<HueSetupSection>()
        if draft != nil { result.insert(.draft) }
        if palette != nil { result.insert(.palette) }
        if cues != nil { result.insert(.cues) }
        if mixes != nil { result.insert(.mixes) }
        if favorites != nil { result.insert(.favorites) }
        if !layouts.isEmpty { result.insert(.layout) }
        if safety != nil { result.insert(.safety) }
        return result
    }

    /// Merge only the chosen parts of Studio. Independent import paths use exactly the same projection.
    public func applyingStudioSections(_ sections: Set<HueSetupSection>, to current: HueStudioDraft) -> HueStudioDraft {
        var updated = current
        if sections.contains(.draft), let draft {
            updated = draft
            updated.settings.customColors = current.settings.customColors
            updated.settings.sequenceIds = current.settings.sequenceIds
            updated.settings.sequenceHold = current.settings.sequenceHold
            updated.settings.sequenceOrder = current.settings.sequenceOrder
            updated.cuesEnabled = current.cuesEnabled
        }
        if sections.contains(.palette), let palette { updated.settings.customColors = palette }
        if sections.contains(.cues), let cues, let cuesEnabled {
            updated.settings.sequenceIds = cues.presetIDs
            updated.settings.sequenceHold = cues.holdSeconds
            updated.settings.sequenceOrder = cues.order.rawValue
            updated.settings.seed = cues.seed
            updated.cuesEnabled = cuesEnabled
        }
        return updated
    }
}

enum HueSetupCodec {
    static let format = "hue-board.setup"
    private static let draftExclusions = Set(["customColors", "sequenceIds", "sequenceHold", "sequenceOrder", "seed"])
    private static var malformed: HueBoardError { .invalidResponse("This Hue Board setup has missing, conflicting, or unsupported fields.") }

    static func validate(_ setup: HueSetupDocument, contract: HueBoardContract) throws {
        guard !setup.availableSections.isEmpty,
              (setup.cues == nil) == (setup.cuesEnabled == nil),
              !(setup.cuesEnabled == true && setup.cues?.presetIDs.isEmpty == true) else { throw malformed }
        if let draft = setup.draft {
            try HuePortableDataCodec.validate(.studioDraft(draft), contract: contract)
            if let cues = setup.cues, draft.settings.seed != cues.seed { throw malformed }
        }
        if let colors = setup.palette { try HuePortableDataCodec.validate(.customPalette(colors), contract: contract) }
        if let cues = setup.cues { try HuePortableDataCodec.validate(.cues(cues), contract: contract) }
        if let mixes = setup.mixes { try HuePortableDataCodec.validate(.mixLibrary(mixes), contract: contract) }
        if let ids = setup.favorites { try HuePortableDataCodec.validate(.favorites(ids), contract: contract) }
        guard Set(setup.layouts.map(\.scope)).count == setup.layouts.count else { throw malformed }
        for room in setup.layouts {
            guard room.scope.utf8.count == 64,
                  room.scope.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }) else { throw malformed }
            try HuePortableDataCodec.validate(.roomLayout(room.layout), contract: contract)
        }
        if let safety = setup.safety { try HuePortableDataCodec.validate(.safety(safety), contract: contract) }
    }

    private static func object<T: Encodable>(_ value: T) throws -> Any {
        try JSONSerialization.jsonObject(with: JSONEncoder().encode(value), options: .fragmentsAllowed)
    }

    private static func typed<T: Codable>(_ type: T.Type, from object: Any) throws -> T {
        let options: JSONSerialization.WritingOptions = [.fragmentsAllowed, .sortedKeys]
        let bytes = try JSONSerialization.data(withJSONObject: object, options: options)
        let value = try JSONDecoder().decode(type, from: bytes)
        // Compare JSON to JSON. Foundation's bridged collection equality differs by host,
        // and NSNumber equality can equate a JSON boolean with the number zero or one.
        // Re-encoding also detects nested fields the typed decoder would otherwise discard.
        let roundTrip = try JSONSerialization.data(withJSONObject: self.object(value), options: options)
        guard bytes == roundTrip else { throw malformed }
        return value
    }

    static func encode(_ setup: HueSetupDocument) throws -> Data {
        var sections: [String: Any] = [:]
        if let draft = setup.draft {
            guard let settings = try object(draft.settings) as? [String: Any] else { throw malformed }
            sections["draft"] = [
                "settings": settings.filter { !draftExclusions.contains($0.key) },
                "sourceLookID": draft.sourceLookID, "duration": draft.duration
            ] as [String: Any]
        }
        if let seed = setup.draft?.settings.seed ?? setup.cues?.seed { sections["seed"] = seed }
        if let cues = setup.cues, let enabled = setup.cuesEnabled {
            sections["cues"] = [
                "presetIDs": cues.presetIDs, "holdSeconds": cues.holdSeconds,
                "order": cues.order.rawValue, "enabled": enabled
            ] as [String: Any]
        }
        if let palette = setup.palette { sections["palette"] = palette }
        if let mixes = setup.mixes { sections["mixes"] = try object(mixes) }
        if let favorites = setup.favorites { sections["favorites"] = favorites }
        let schema: Int
        if setup.layouts.count > 1 {
            schema = 2
            sections["layouts"] = try object(setup.layouts)
        } else {
            schema = 1
            if let layout = setup.layout { sections["layout"] = try object(layout) }
        }
        if let safety = setup.safety { sections["safety"] = try object(safety) }
        return try JSONSerialization.data(withJSONObject: ["format": format, "schema": schema, "sections": sections],
                                          options: [.sortedKeys, .withoutEscapingSlashes])
    }

    static func decode(root: [String: Any], contract: HueBoardContract) throws -> HueSetupDocument {
        guard Set(root.keys) == ["format", "schema", "sections"],
              let version = root["schema"], let sections = root["sections"] as? [String: Any] else { throw malformed }
        let schema = try typed(Int.self, from: version)
        var keys = Set(HueSetupSection.allCases.map(\.rawValue) + ["seed"])
        switch schema {
        case 1: break
        case 2:
            keys.remove("layout")
            keys.insert("layouts")
            guard let layouts = sections["layouts"] as? [Any], layouts.count > 1 else { throw malformed }
        default: throw malformed
        }
        guard Set(sections.keys).isSubset(of: keys) else { throw malformed }
        func read<T: Codable>(_ key: String, _ type: T.Type) throws -> T? {
            try sections[key].map { try typed(type, from: $0) }
        }
        let seed = try read("seed", Int.self)
        guard (seed != nil) == (sections["draft"] != nil || sections["cues"] != nil) else { throw malformed }
        var draft: HueStudioDraft?
        if let field = sections["draft"] {
            guard let data = field as? [String: Any], Set(data.keys) == ["settings", "sourceLookID", "duration"],
                  let settings = data["settings"] as? [String: Any],
                  let base = try object(HueSceneSettings()) as? [String: Any],
                  Set(settings.keys) == Set(base.keys).subtracting(draftExclusions),
                  let source = data["sourceLookID"] as? String, let duration = data["duration"], let seed else { throw malformed }
            var merged = base.merging(settings) { _, new in new }
            merged["seed"] = seed
            draft = try .init(settings: typed(HueSceneSettings.self, from: merged), sourceLookID: source,
                              duration: typed(Double.self, from: duration), cuesEnabled: false)
        }
        var cues: HueCueSequence?
        var enabled: Bool?
        if let field = sections["cues"] {
            guard var data = field as? [String: Any], Set(data.keys) == ["presetIDs", "holdSeconds", "order", "enabled"],
                  let enabledValue = data.removeValue(forKey: "enabled"), let seed else { throw malformed }
            data["seed"] = seed
            enabled = try typed(Bool.self, from: enabledValue)
            cues = try typed(HueCueSequence.self, from: data)
        }
        let result = try HueSetupDocument(
            draft: draft, palette: read("palette", [String].self), cues: cues, cuesEnabled: enabled,
            mixes: read("mixes", [HueSceneDocument].self), favorites: read("favorites", [String].self),
            layout: read("layout", HueSetupRoom.self), layouts: read("layouts", [HueSetupRoom].self) ?? [],
            safety: read("safety", HueSafetyPreferences.self)
        )
        try validate(result, contract: contract)
        return result
    }
}
