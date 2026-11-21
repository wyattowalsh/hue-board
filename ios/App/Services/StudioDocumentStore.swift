import Foundation
import HueBoardKit

/// Local index of canonical, scope-free scene documents.
struct StudioDocumentStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load(contract: HueBoardContract) throws -> [HueSceneDocument] {
        try SetupImportTransaction.withRecoveredSettings(defaults: defaults) {
            guard let data = defaults.data(forKey: SetupImportTransaction.Section.library.preferenceKey) else { return [] }
            let documents = try JSONDecoder().decode([HueSceneDocument].self, from: data)
            try HueSceneDocumentCodec.validateLibrary(documents, contract: contract)
            return documents
        }
    }

    static func encoded(_ documents: [HueSceneDocument], contract: HueBoardContract) throws -> Data {
        try HueSceneDocumentCodec.validateLibrary(documents, contract: contract)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(documents)
    }

    func save(_ documents: [HueSceneDocument], contract: HueBoardContract) throws {
        let data = try Self.encoded(documents, contract: contract)
        try SetupImportTransaction.withRecoveredSettings(defaults: defaults) {
            let key = SetupImportTransaction.Section.library.preferenceKey
            defaults.set(data, forKey: key)
            guard defaults.data(forKey: key) == data else {
                throw HueBoardError.invalidResponse("The Studio library write did not verify.")
            }
        }
    }
}
