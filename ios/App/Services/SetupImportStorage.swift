import Foundation
import HueBoardKit
import HueBoardNativeCore

@MainActor
extension AppModel {
    func setupStorageFingerprint(for changes: HueSetupDurableChanges) throws -> SetupImportTransaction.Fingerprint {
        try SetupImportTransaction.fingerprint(for: Set(setupReplacements(changes).keys), defaults: setupDefaults)
    }

    func commitSetupStorage(
        _ changes: HueSetupDurableChanges, expected: SetupImportTransaction.Fingerprint
    ) throws {
        try SetupImportTransaction.commit(setupReplacements(changes), expected: expected, defaults: setupDefaults)
    }

    private func setupReplacements(
        _ changes: HueSetupDurableChanges
    ) throws -> [SetupImportTransaction.Section: SetupImportTransaction.Value] {
        var values: [SetupImportTransaction.Section: SetupImportTransaction.Value] = [:]
        if let library = changes.library {
            values[.library] = .data(try StudioDocumentStore.encoded(library, contract: contract))
        }
        if let favorites = changes.favorites {
            values[.favorites] = .identifiers(favorites.sorted())
        }
        if let safety = changes.safety {
            values[.safety] = .data(try PhysicalLightSafetyStore.encoded(safety))
        }
        for (scope, layout) in changes.layouts {
            guard let bridgeID = profile?.bridgeID, let area = setupArea(for: scope, id: layout.areaID) else {
                throw HueBoardError.unsupported("Select the original room and review the setup import again.")
            }
            values[.layout(bridgeID: bridgeID, areaID: area.id.rawValue)] =
                .data(try HueRoomLayoutStore.encoded(layout, for: area))
        }
        return values
    }
}
