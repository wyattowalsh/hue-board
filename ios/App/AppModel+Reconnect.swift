import Foundation
import HueBoardKit
import HueBoardNativeCore

@MainActor
extension AppModel {
    func reconnectSavedBridge() async {
        guard !isBusy, let savedProfile = profile else {
            errorMessage = "No saved Bridge connection is available to retry."
            return
        }

        isBusy = true
        connectionState = .connecting
        stopEventMonitoring()
        defer { isBusy = false }

        do {
            let verifiedProfile = try await client.verify(profile: savedProfile)
            guard let savedCredential = try keychain.credential(
                bridgeID: verifiedProfile.bridgeID
            ) else {
                throw HueBoardError.authorization(
                    "The saved Bridge application key is missing. Pair again after verifying the Bridge."
                )
            }
            if verifiedProfile != savedProfile {
                try await persistence.saveProfile(verifiedProfile)
            }

            profile = verifiedProfile
            credential = savedCredential
            try await loadInventory(profile: verifiedProfile, credential: savedCredential)
            connectionState = .ready
            pendingProfile = nil
            isConnectionSheetPresented = false
            note = "Reconnected over pinned HTTPS without creating a new Bridge application key."
            startEventMonitoring()
        } catch {
            connectionState = .disconnected
            credential = nil
            errorMessage = error.localizedDescription
            note = "Saved connection retry failed closed. Verify the Bridge or forget it deliberately."
            isConnectionSheetPresented = true
        }
    }
}
