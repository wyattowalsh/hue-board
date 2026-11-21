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
        try HueSceneDocumentCodec.validateLibrary(documents, contract: contract)
        return documents
    }

    func save(_ documents: [HueSceneDocument], contract: HueBoardContract) throws {
        try HueSceneDocumentCodec.validateLibrary(documents, contract: contract)
        let data = try JSONEncoder().encode(documents)
        // Do not delete or rewrite the original library if encoding or validation fails.
        defaults.set(data, forKey: Self.key)
        guard defaults.data(forKey: Self.key) == data else {
            throw HueBoardError.invalidResponse("The Studio library write did not verify.")
        }
    }
}
