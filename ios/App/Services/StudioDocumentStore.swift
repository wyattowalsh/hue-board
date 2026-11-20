import Foundation
import HueBoardKit

/// Local index of canonical, scope-free scene documents.
///
/// Nothing in this store contains a Bridge host, application key, room ID, or
/// fixture target. The canonical scene codec validates every item before use.
struct StudioDocumentStore {
    private static let key = "hue-board.native.studio-documents.v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load(contract: HueBoardContract) throws -> [HueSceneDocument] {
        guard let data = defaults.data(forKey: Self.key) else { return [] }
        let documents = try JSONDecoder().decode([HueSceneDocument].self, from: data)
        guard documents.count <= 100 else {
            throw HueBoardError.invalidResponse("The Studio library exceeds its 100-mix limit.")
        }

        var ids = Set<String>()
        for document in documents {
            try HueSceneDocumentCodec.validate(document, contract: contract)
            guard ids.insert(document.documentId).inserted else {
                throw HueBoardError.invalidResponse("Duplicate scene IDs in the saved library.")
            }
        }
        return documents
    }

    func save(_ documents: [HueSceneDocument], contract: HueBoardContract) throws {
        guard documents.count <= 100 else {
            throw HueBoardError.unsupported("The Studio library holds at most 100 mixes.")
        }
        var ids = Set<String>()
        for document in documents {
            try HueSceneDocumentCodec.validate(document, contract: contract)
            guard ids.insert(document.documentId).inserted else {
                throw HueBoardError.invalidResponse("A mix ID was reused.")
            }
        }

        let data = try JSONEncoder().encode(documents)
        // Do not delete or rewrite the original library if encoding or validation fails.
        defaults.set(data, forKey: Self.key)
        guard defaults.data(forKey: Self.key) == data else {
            throw HueBoardError.invalidResponse("The Studio library write did not verify.")
        }
    }
}
