import Foundation

public enum HueSceneDocumentKind: String, Codable, Sendable {
    case look
}

public enum HueSceneScopePolicy: String, Codable, Sendable {
    case userSelected = "user-selected"
}

public enum HueSceneImportSource: String, Codable, Sendable {
    case sceneSchema2 = "scene-schema-2"
    case legacyScriptable3 = "legacy-scriptable-schema-3"
}

public struct HueSceneDocumentSource: Codable, Equatable, Sendable {
    public let productVersion: String
    public let engineABI: Int
    public let catalogRevision: String?
    public let implementation: String

    public init(
        productVersion: String,
        engineABI: Int = 1,
        catalogRevision: String? = nil,
        implementation: String
    ) {
        self.productVersion = productVersion
        self.engineABI = engineABI
        self.catalogRevision = catalogRevision
        self.implementation = implementation
    }
}

public struct HueSceneSettings: Codable, Equatable, Sendable {
    public var showA: String
    public var showB: String
    public var paletteA: Int
    public var paletteB: Int
    public var morph: Double
    public var brightness: Double
    public var speed: Double
    public var depth: Double
    public var spread: Double
    public var energy: Double
    public var tension: Double
    public var focus: Double
    public var reverse: Bool
    public var gradient: Bool
    public var seed: Int
    public var topology: String
    public var transitionMs: Double
    public var ownership: String
    public var nativeKind: String
    public var effect: String
    public var effectSpeed: Double
    public var effectTint: Bool
    public var saturation: Double
    public var ambientFloor: Double
    public var accentMix: Double
    public var density: Int
    public var phaseOffset: Double
    public var brightnessCurve: Double
    public var directorSeconds: Double
    public var customColors: [String]
    public var sequenceIds: [String]
    public var sequenceHold: Double
    public var sequenceOrder: String

    public init(
        showA: String = "eclipse",
        showB: String = "turbine",
        paletteA: Int = 0,
        paletteB: Int = 1,
        morph: Double = 0,
        brightness: Double = 60,
        speed: Double = 1,
        depth: Double = 75,
        spread: Double = 1.2,
        energy: Double = 65,
        tension: Double = 65,
        focus: Double = 55,
        reverse: Bool = false,
        gradient: Bool = false,
        seed: Int = 731,
        topology: String = "ring",
        transitionMs: Double = 4_500,
        ownership: String = "yield_off",
        nativeKind: String = "palette",
        effect: String = "",
        effectSpeed: Double = 0.4,
        effectTint: Bool = false,
        saturation: Double = 100,
        ambientFloor: Double = 0,
        accentMix: Double = 100,
        density: Int = 1,
        phaseOffset: Double = 0,
        brightnessCurve: Double = 1,
        directorSeconds: Double = 52,
        customColors: [String] = ["#102CBA", "#00B9F2", "#36E5D1", "#A4ED51"],
        sequenceIds: [String] = ["ion-eclipse", "plasma-turbine", "deep-orbit"],
        sequenceHold: Double = 90,
        sequenceOrder: String = "forward"
    ) {
        self.showA = showA
        self.showB = showB
        self.paletteA = paletteA
        self.paletteB = paletteB
        self.morph = morph
        self.brightness = brightness
        self.speed = speed
        self.depth = depth
        self.spread = spread
        self.energy = energy
        self.tension = tension
        self.focus = focus
        self.reverse = reverse
        self.gradient = gradient
        self.seed = seed
        self.topology = topology
        self.transitionMs = transitionMs
        self.ownership = ownership
        self.nativeKind = nativeKind
        self.effect = effect
        self.effectSpeed = effectSpeed
        self.effectTint = effectTint
        self.saturation = saturation
        self.ambientFloor = ambientFloor
        self.accentMix = accentMix
        self.density = density
        self.phaseOffset = phaseOffset
        self.brightnessCurve = brightnessCurve
        self.directorSeconds = directorSeconds
        self.customColors = customColors
        self.sequenceIds = sequenceIds
        self.sequenceHold = sequenceHold
        self.sequenceOrder = sequenceOrder
    }

    public init(engineSettings: HueEngineSettings) {
        self.init(
            showA: engineSettings.showA,
            showB: engineSettings.showB,
            paletteA: engineSettings.paletteA,
            paletteB: engineSettings.paletteB,
            morph: engineSettings.morph,
            brightness: engineSettings.brightness,
            speed: engineSettings.speed,
            depth: engineSettings.depth,
            spread: engineSettings.spread,
            energy: engineSettings.energy,
            tension: engineSettings.tension,
            focus: engineSettings.focus,
            reverse: engineSettings.reverse,
            gradient: engineSettings.gradient,
            seed: engineSettings.seed,
            topology: engineSettings.topology,
            saturation: engineSettings.saturation,
            ambientFloor: engineSettings.ambientFloor,
            accentMix: engineSettings.accentMix,
            density: engineSettings.density,
            phaseOffset: engineSettings.phaseOffset,
            brightnessCurve: engineSettings.brightnessCurve,
            directorSeconds: engineSettings.directorSeconds,
            customColors: engineSettings.customColors
        )
    }

    public var nativeEngineSettings: HueEngineSettings {
        HueEngineSettings(
            showA: showA,
            showB: showB,
            paletteA: paletteA,
            paletteB: paletteB,
            morph: morph,
            brightness: brightness,
            speed: speed,
            depth: depth,
            spread: spread,
            energy: energy,
            tension: tension,
            focus: focus,
            reverse: reverse,
            gradient: gradient,
            seed: seed,
            topology: topology,
            saturation: saturation,
            ambientFloor: ambientFloor,
            accentMix: accentMix,
            density: density,
            phaseOffset: phaseOffset,
            brightnessCurve: brightnessCurve,
            directorSeconds: directorSeconds,
            customColors: customColors
        )
    }
}

public struct HueSceneDocument: Codable, Equatable, Sendable {
    public let format: String
    public let schema: Int
    public let kind: HueSceneDocumentKind
    public let documentId: String
    public let name: String
    public let createdAt: String
    public let modifiedAt: String
    public let scope: HueSceneScopePolicy
    public let source: HueSceneDocumentSource
    public let settings: HueSceneSettings

    public init(
        format: String = HueSceneDocumentCodec.format,
        schema: Int = HueSceneDocumentCodec.schema,
        kind: HueSceneDocumentKind = .look,
        documentId: String,
        name: String,
        createdAt: String,
        modifiedAt: String,
        scope: HueSceneScopePolicy = .userSelected,
        source: HueSceneDocumentSource,
        settings: HueSceneSettings
    ) {
        self.format = format
        self.schema = schema
        self.kind = kind
        self.documentId = documentId
        self.name = name
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.scope = scope
        self.source = source
        self.settings = settings
    }
}

public struct HueSceneImportResult: Equatable, Sendable {
    public let document: HueSceneDocument
    public let source: HueSceneImportSource
    public let warnings: [String]

    public init(document: HueSceneDocument, source: HueSceneImportSource, warnings: [String]) {
        self.document = document
        self.source = source
        self.warnings = warnings
    }
}

public enum HueSceneDocumentError: Error, Equatable, LocalizedError, Sendable {
    case invalidDocument(String)
    case unsupportedSchema(Int)
    case invalidSettings(String)

    public var errorDescription: String? {
        switch self {
        case .invalidDocument(let message), .invalidSettings(let message): message
        case .unsupportedSchema(let schema):
            "Hue Board scene schema \(schema) is not supported. Nothing was imported."
        }
    }
}

public enum HueSceneDocumentCodec {
    public static let format = "hue-board.scene"
    public static let schema = 2
    public static let engineABI = 1

    private static let legacyApps = Set(["hue-board", "BOYZ.EXE"])
    private static let rootKeys = Set([
        "format", "schema", "kind", "documentId", "name", "createdAt",
        "modifiedAt", "scope", "source", "settings"
    ])
    private static let sourceKeys = Set([
        "productVersion", "engineABI", "catalogRevision", "implementation"
    ])
    private static let settingKeys = Set([
        "showA", "showB", "paletteA", "paletteB", "morph", "brightness", "speed",
        "depth", "spread", "energy", "tension", "focus", "reverse", "gradient",
        "seed", "topology", "transitionMs", "ownership", "nativeKind", "effect",
        "effectSpeed", "effectTint", "saturation", "ambientFloor", "accentMix",
        "density", "phaseOffset", "brightnessCurve", "directorSeconds", "customColors",
        "sequenceIds", "sequenceHold", "sequenceOrder"
    ])

    public static func makeDocument(
        name: String,
        settings: HueSceneSettings,
        source: HueSceneDocumentSource,
        documentId: String = UUID().uuidString.lowercased(),
        now: Date = Date()
    ) -> HueSceneDocument {
        let timestamp = timestamp(now)
        return HueSceneDocument(
            documentId: documentId,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            createdAt: timestamp,
            modifiedAt: timestamp,
            source: source,
            settings: settings
        )
    }

    public static func encode(
        _ document: HueSceneDocument,
        contract: HueBoardContract
    ) throws -> Data {
        try validate(document, contract: contract)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(document)
    }

    public static func decode(
        _ data: Data,
        contract: HueBoardContract
    ) throws -> HueSceneImportResult {
        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw HueSceneDocumentError.invalidDocument(
                "The selected file is not valid JSON. Nothing was imported."
            )
        }
        guard let root = object as? [String: Any] else {
            throw HueSceneDocumentError.invalidDocument(
                "Expected a Hue Board scene document object. Nothing was imported."
            )
        }

        if root["format"] as? String == format {
            return try decodeSchema2(data, root: root, contract: contract)
        }
        return try migrateLegacySchema3(data, root: root, contract: contract)
    }

    public static func validate(
        _ document: HueSceneDocument,
        contract: HueBoardContract
    ) throws {
        guard document.format == format else {
            throw HueSceneDocumentError.invalidDocument("Unknown Hue Board scene format.")
        }
        guard document.schema == schema else {
            throw HueSceneDocumentError.unsupportedSchema(document.schema)
        }
        guard document.kind == .look, document.scope == .userSelected else {
            throw HueSceneDocumentError.invalidDocument(
                "Hue Board scene documents cannot embed a physical target or unsupported document kind."
            )
        }
        guard matches(document.documentId, pattern: "^[A-Za-z0-9._-]{1,80}$") else {
            throw HueSceneDocumentError.invalidDocument("The scene document identifier is invalid.")
        }
        let name = document.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 80,
              !name.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains)
        else {
            throw HueSceneDocumentError.invalidDocument("The scene name is invalid.")
        }
        guard let created = parseTimestamp(document.createdAt),
              let modified = parseTimestamp(document.modifiedAt),
              modified >= created
        else {
            throw HueSceneDocumentError.invalidDocument("The scene timestamps are invalid.")
        }
        guard document.source.engineABI == engineABI else {
            throw HueSceneDocumentError.invalidDocument(
                "Engine ABI \(document.source.engineABI) is not supported."
            )
        }
        guard matches(document.source.productVersion, pattern: "^[A-Za-z0-9.+_-]{1,40}$"),
              matches(document.source.implementation, pattern: "^[A-Za-z0-9._-]{1,40}$")
        else {
            throw HueSceneDocumentError.invalidDocument("The scene source metadata is invalid.")
        }
        if let revision = document.source.catalogRevision,
           !matches(revision, pattern: "^[A-Fa-f0-9]{64}$") {
            throw HueSceneDocumentError.invalidDocument("The catalog revision is invalid.")
        }
        try validate(document.settings, contract: contract)
    }

    private static func decodeSchema2(
        _ data: Data,
        root: [String: Any],
        contract: HueBoardContract
    ) throws -> HueSceneImportResult {
        try rejectUnknownKeys(root, allowed: rootKeys, context: "scene document")
        guard let source = root["source"] as? [String: Any],
              let settings = root["settings"] as? [String: Any]
        else {
            throw HueSceneDocumentError.invalidDocument(
                "The scene source or settings object is missing."
            )
        }
        try rejectUnknownKeys(source, allowed: sourceKeys, context: "scene source")
        try rejectUnknownKeys(settings, allowed: settingKeys, context: "scene settings")
        let rawSchema = (root["schema"] as? NSNumber)?.intValue ?? -1
        guard rawSchema == schema else { throw HueSceneDocumentError.unsupportedSchema(rawSchema) }

        let decoder = JSONDecoder()
        let document: HueSceneDocument
        do {
            document = try decoder.decode(HueSceneDocument.self, from: data)
        } catch {
            throw HueSceneDocumentError.invalidDocument(
                "The Hue Board scene document is incomplete or malformed."
            )
        }
        try validate(document, contract: contract)
        return HueSceneImportResult(document: document, source: .sceneSchema2, warnings: [])
    }

    private static func migrateLegacySchema3(
        _ data: Data,
        root: [String: Any],
        contract: HueBoardContract
    ) throws -> HueSceneImportResult {
        guard let app = root["app"] as? String,
              legacyApps.contains(app),
              (root["schema"] as? NSNumber)?.intValue == 3
        else {
            throw HueSceneDocumentError.invalidDocument(
                "Expected a Hue Board scene schema 2 document or legacy schema 3 mix."
            )
        }

        let decoder = JSONDecoder()
        let legacy: LegacyMixDocument
        do {
            legacy = try decoder.decode(LegacyMixDocument.self, from: data)
        } catch {
            throw HueSceneDocumentError.invalidDocument(
                "The legacy Hue Board mix is malformed. Nothing was imported."
            )
        }

        var warnings = ["Migrated a legacy Scriptable schema 3 mix to scene schema 2."]
        let settings = sanitize(legacy.settings, contract: contract, warnings: &warnings)
        let canonical = try canonicalData(settings)
        let identifier = "legacy-" + fnv1a64Hex(canonical)
        let epoch = "1970-01-01T00:00:00Z"
        let document = HueSceneDocument(
            documentId: identifier,
            name: "Imported Hue Board look",
            createdAt: epoch,
            modifiedAt: epoch,
            source: HueSceneDocumentSource(
                productVersion: "5.3.x",
                engineABI: engineABI,
                implementation: "scriptable-legacy"
            ),
            settings: settings
        )
        try validate(document, contract: contract)

        let ignored = Set(root.keys).subtracting(["app", "schema", "settings"])
        if !ignored.isEmpty {
            warnings.append("Ignored unsupported legacy metadata: \(ignored.sorted().joined(separator: ", ")).")
        }
        return HueSceneImportResult(
            document: document,
            source: .legacyScriptable3,
            warnings: warnings
        )
    }

    private static func validate(
        _ settings: HueSceneSettings,
        contract: HueBoardContract
    ) throws {
        let patterns = Set(contract.patterns.map(\.id))
        guard patterns.contains(settings.showA), patterns.contains(settings.showB) else {
            throw HueSceneDocumentError.invalidSettings("The scene references an unknown pattern.")
        }
        let palettes = Set(contract.palettes.map(\.index))
        guard palettes.contains(settings.paletteA), palettes.contains(settings.paletteB) else {
            throw HueSceneDocumentError.invalidSettings("The scene references an unknown palette.")
        }

        try require(settings.morph, in: 0...100, name: "morph")
        try require(settings.brightness, in: 5...100, name: "brightness")
        try require(settings.speed, in: 0.25...1.6, name: "speed")
        try require(settings.depth, in: 0...100, name: "depth")
        try require(settings.spread, in: 0.5...2, name: "spread")
        try require(settings.energy, in: 0...100, name: "energy")
        try require(settings.tension, in: 0...100, name: "tension")
        try require(settings.focus, in: 0...100, name: "focus")
        try require(settings.transitionMs, in: 2_500...15_000, name: "transitionMs")
        try require(settings.effectSpeed, in: 0...1, name: "effectSpeed")
        try require(settings.saturation, in: 0...100, name: "saturation")
        try require(settings.ambientFloor, in: 0...65, name: "ambientFloor")
        try require(settings.accentMix, in: 0...100, name: "accentMix")
        try require(settings.phaseOffset, in: -1...1, name: "phaseOffset")
        try require(settings.brightnessCurve, in: 0.5...2, name: "brightnessCurve")
        try require(settings.directorSeconds, in: 30...180, name: "directorSeconds")
        try require(settings.sequenceHold, in: 30...600, name: "sequenceHold")

        guard (0...999_999).contains(settings.seed), (1...4).contains(settings.density) else {
            throw HueSceneDocumentError.invalidSettings("The scene integer settings are out of range.")
        }
        guard ["ring", "path"].contains(settings.topology),
              ["yield_off", "hold"].contains(settings.ownership),
              ["palette", "effect"].contains(settings.nativeKind),
              ["forward", "shuffle"].contains(settings.sequenceOrder),
              settings.effect.count <= 40
        else {
            throw HueSceneDocumentError.invalidSettings("The scene contains an invalid mode setting.")
        }
        guard settings.customColors.count == 4 else {
            throw HueSceneDocumentError.invalidSettings("A scene requires exactly four custom colors.")
        }
        do {
            for color in settings.customColors { _ = try RGB(hex: color) }
        } catch {
            throw HueSceneDocumentError.invalidSettings("The scene contains an invalid custom color.")
        }
        guard settings.sequenceIds.count <= 12,
              settings.sequenceIds.allSatisfy({ matches($0, pattern: "^[a-z0-9-]{1,50}$") })
        else {
            throw HueSceneDocumentError.invalidSettings("The scene sequence identifiers are invalid.")
        }
    }

    private static func sanitize(
        _ legacy: LegacySceneSettings,
        contract: HueBoardContract,
        warnings: inout [String]
    ) -> HueSceneSettings {
        let defaults = HueSceneSettings()
        let patterns = Set(contract.patterns.map(\.id))
        let palettes = Set(contract.palettes.map(\.index))

        func pattern(_ value: String?, fallback: String, name: String) -> String {
            guard let value else { return fallback }
            guard patterns.contains(value) else {
                warnings.append("Replaced unknown \(name) pattern with \(fallback).")
                return fallback
            }
            return value
        }
        func bounded(
            _ value: Double?,
            fallback: Double,
            range: ClosedRange<Double>,
            name: String
        ) -> Double {
            guard let value, value.isFinite else { return fallback }
            let result = min(max(value, range.lowerBound), range.upperBound)
            if result != value { warnings.append("Clamped \(name) to the supported range.") }
            return result
        }
        func integer(
            _ value: Double?,
            fallback: Int,
            range: ClosedRange<Int>,
            name: String
        ) -> Int {
            guard let value, value.isFinite else { return fallback }
            let rounded = Int(value.rounded())
            let result = min(max(rounded, range.lowerBound), range.upperBound)
            if Double(result) != value { warnings.append("Normalized \(name) to the supported range.") }
            return result
        }
        func palette(_ value: Double?, fallback: Int, name: String) -> Int {
            let candidate = integer(
                value,
                fallback: fallback,
                range: 0...max(0, contract.palettes.count - 1),
                name: name
            )
            guard palettes.contains(candidate) else {
                warnings.append("Replaced unknown \(name) with \(fallback).")
                return fallback
            }
            return candidate
        }

        let customColors: [String]
        if let colors = legacy.customColors,
           colors.count == 4,
           colors.allSatisfy({ (try? RGB(hex: $0)) != nil }) {
            customColors = colors.map(\.uppercased)
        } else {
            if legacy.customColors != nil { warnings.append("Replaced invalid custom colors with defaults.") }
            customColors = defaults.customColors
        }

        let sequenceIds: [String]
        if let values = legacy.sequenceIds {
            let filtered = values.filter { matches($0, pattern: "^[a-z0-9-]{1,50}$") }.prefix(12)
            sequenceIds = Array(filtered)
            if sequenceIds != values { warnings.append("Removed unsupported sequence identifiers.") }
        } else {
            sequenceIds = defaults.sequenceIds
        }

        let effect: String
        if let value = legacy.effect {
            effect = String(value.prefix(40))
            if effect != value { warnings.append("Truncated the legacy effect identifier.") }
        } else {
            effect = defaults.effect
        }

        return HueSceneSettings(
            showA: pattern(legacy.showA ?? legacy.mode, fallback: defaults.showA, name: "primary"),
            showB: pattern(legacy.showB, fallback: defaults.showB, name: "secondary"),
            paletteA: palette(legacy.paletteA ?? legacy.palette, fallback: defaults.paletteA, name: "primary palette"),
            paletteB: palette(legacy.paletteB, fallback: defaults.paletteB, name: "secondary palette"),
            morph: bounded(legacy.morph, fallback: defaults.morph, range: 0...100, name: "morph"),
            brightness: bounded(legacy.brightness, fallback: defaults.brightness, range: 5...100, name: "brightness"),
            speed: bounded(legacy.speed, fallback: defaults.speed, range: 0.25...1.6, name: "speed"),
            depth: bounded(legacy.depth, fallback: defaults.depth, range: 0...100, name: "depth"),
            spread: bounded(legacy.spread, fallback: defaults.spread, range: 0.5...2, name: "spread"),
            energy: bounded(legacy.energy, fallback: defaults.energy, range: 0...100, name: "energy"),
            tension: bounded(legacy.tension, fallback: defaults.tension, range: 0...100, name: "tension"),
            focus: bounded(legacy.focus, fallback: defaults.focus, range: 0...100, name: "focus"),
            reverse: legacy.reverse ?? defaults.reverse,
            gradient: legacy.gradient ?? defaults.gradient,
            seed: integer(legacy.seed, fallback: defaults.seed, range: 0...999_999, name: "seed"),
            topology: legacy.topology == "path" ? "path" : defaults.topology,
            transitionMs: bounded(legacy.transitionMs, fallback: defaults.transitionMs, range: 2_500...15_000, name: "transitionMs"),
            ownership: ["yield_off", "hold"].contains(legacy.ownership ?? "") ? legacy.ownership! : defaults.ownership,
            nativeKind: legacy.nativeKind == "effect" ? "effect" : defaults.nativeKind,
            effect: effect,
            effectSpeed: bounded(legacy.effectSpeed, fallback: defaults.effectSpeed, range: 0...1, name: "effectSpeed"),
            effectTint: legacy.effectTint ?? defaults.effectTint,
            saturation: bounded(legacy.saturation, fallback: defaults.saturation, range: 0...100, name: "saturation"),
            ambientFloor: bounded(legacy.ambientFloor, fallback: defaults.ambientFloor, range: 0...65, name: "ambientFloor"),
            accentMix: bounded(legacy.accentMix, fallback: defaults.accentMix, range: 0...100, name: "accentMix"),
            density: integer(legacy.density, fallback: defaults.density, range: 1...4, name: "density"),
            phaseOffset: bounded(legacy.phaseOffset, fallback: defaults.phaseOffset, range: -1...1, name: "phaseOffset"),
            brightnessCurve: bounded(legacy.brightnessCurve, fallback: defaults.brightnessCurve, range: 0.5...2, name: "brightnessCurve"),
            directorSeconds: bounded(legacy.directorSeconds, fallback: defaults.directorSeconds, range: 30...180, name: "directorSeconds"),
            customColors: customColors,
            sequenceIds: sequenceIds,
            sequenceHold: bounded(legacy.sequenceHold, fallback: defaults.sequenceHold, range: 30...600, name: "sequenceHold"),
            sequenceOrder: legacy.sequenceOrder == "shuffle" ? "shuffle" : defaults.sequenceOrder
        )
    }

    private static func rejectUnknownKeys(
        _ value: [String: Any],
        allowed: Set<String>,
        context: String
    ) throws {
        let unknown = Set(value.keys).subtracting(allowed)
        guard unknown.isEmpty else {
            throw HueSceneDocumentError.invalidDocument(
                "The \(context) contains unsupported fields: \(unknown.sorted().joined(separator: ", "))."
            )
        }
    }

    private static func require(
        _ value: Double,
        in range: ClosedRange<Double>,
        name: String
    ) throws {
        guard value.isFinite, range.contains(value) else {
            throw HueSceneDocumentError.invalidSettings("The \(name) setting is out of range.")
        }
    }

    private static func canonicalData<Value: Encodable>(_ value: Value) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }

    private static func fnv1a64Hex(_ data: Data) -> String {
        var hash: UInt64 = 1_469_598_103_934_665_603
        for byte in data {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return String(format: "%016llx", hash)
    }

    private static func timestamp(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    private static func parseTimestamp(_ value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: value) { return date }
        let standard = ISO8601DateFormatter()
        standard.formatOptions = [.withInternetDateTime]
        return standard.date(from: value)
    }

    private static func matches(_ value: String, pattern: String) -> Bool {
        value.range(of: pattern, options: .regularExpression) != nil
    }
}

private struct LegacyMixDocument: Decodable {
    let app: String
    let schema: Int
    let settings: LegacySceneSettings
}

private struct LegacySceneSettings: Decodable {
    let mode: String?
    let showA: String?
    let showB: String?
    let palette: Double?
    let paletteA: Double?
    let paletteB: Double?
    let morph: Double?
    let brightness: Double?
    let speed: Double?
    let depth: Double?
    let spread: Double?
    let energy: Double?
    let tension: Double?
    let focus: Double?
    let reverse: Bool?
    let gradient: Bool?
    let seed: Double?
    let topology: String?
    let transitionMs: Double?
    let ownership: String?
    let nativeKind: String?
    let effect: String?
    let effectSpeed: Double?
    let effectTint: Bool?
    let saturation: Double?
    let ambientFloor: Double?
    let accentMix: Double?
    let density: Double?
    let phaseOffset: Double?
    let brightnessCurve: Double?
    let directorSeconds: Double?
    let customColors: [String]?
    let sequenceIds: [String]?
    let sequenceHold: Double?
    let sequenceOrder: String?
}
