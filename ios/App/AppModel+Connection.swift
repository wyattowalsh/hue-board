import Foundation
import HueBoardKit
import HueBoardNativeCore

@MainActor
extension AppModel {
    func bootstrap() async {
        guard connectionState == .disconnected else { return }
        do {
            guard let savedProfile = try await persistence.loadProfile() else {
                isConnectionSheetPresented = true
                return
            }
            profile = savedProfile
            manualHost = savedProfile.host
            connectionState = .connecting

            let verifiedProfile = try await client.verify(profile: savedProfile)
            if verifiedProfile != savedProfile {
                try await persistence.saveProfile(verifiedProfile)
            }
            profile = verifiedProfile

            guard let savedCredential = try keychain.credential(bridgeID: verifiedProfile.bridgeID) else {
                pendingProfile = verifiedProfile
                connectionState = .awaitingBridgeButton
                note = "Bridge certificate verified. Press the physical Bridge button, then pair."
                isConnectionSheetPresented = true
                return
            }

            credential = savedCredential
            try await loadInventory(profile: verifiedProfile, credential: savedCredential)
            connectionState = .ready
            note = "Connected over pinned HTTPS. Play delegates to the Bridge; Native Live is explicit and bounded."
        } catch {
            connectionState = .disconnected
            credential = nil
            errorMessage = error.localizedDescription
            note = "Bridge verification failed closed. Re-verify or forget the saved Bridge before continuing."
            isConnectionSheetPresented = true
        }
    }

    func discoverBridges() async {
        guard !isBusy else { return }
        isBusy = true
        connectionState = .discovering
        defer { isBusy = false }
        do {
            async let localRequest = localDiscovery.discover()
            async let cloudRequest = client.discover()
            let localValues = await localRequest
            let cloudValues: [HueBridgeCandidate]
            do {
                cloudValues = try await cloudRequest
            } catch {
                guard !localValues.isEmpty else { throw error }
                cloudValues = []
            }

            var merged: [String: HueBridgeCandidate] = [:]
            // Insert broker results first so a directly resolved local candidate wins.
            for candidate in cloudValues + localValues {
                let identity = HueBridgeTLSIdentity.normalizeBridgeID(candidate.id)
                    ?? "\(candidate.host):\(candidate.port)"
                merged[identity] = candidate
            }
            discoveredBridges = merged.values.sorted {
                if $0.host == $1.host { return $0.port < $1.port }
                return $0.host.localizedStandardCompare($1.host) == .orderedAscending
            }
            connectionState = .disconnected
            if discoveredBridges.isEmpty {
                note = "No Bridges were discovered by Bonjour or the Hue broker. Enter a private LAN address manually."
            } else {
                let localCount = localValues.count
                let brokerCount = cloudValues.count
                note = "Found \(discoveredBridges.count) Bridge candidate(s): \(localCount) local Bonjour result(s), \(brokerCount) broker result(s). Verify one before pairing."
            }
        } catch {
            connectionState = .disconnected
            errorMessage = error.localizedDescription
        }
    }

    func probe(_ candidate: HueBridgeCandidate) async {
        guard !isBusy else { return }
        isBusy = true
        connectionState = .probing
        defer { isBusy = false }
        do {
            let value = try await client.probe(candidate: candidate)
            pendingProfile = value
            manualHost = value.host
            connectionState = .awaitingBridgeButton
            note = "Bridge API identity and TLS certificate agree. Review the fingerprint, press the physical Bridge button, then pair."
        } catch {
            connectionState = .disconnected
            errorMessage = error.localizedDescription
        }
    }

    func probeManualHost() async {
        let host = manualHost.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard HueBridgeHostValidator.isAllowed(host) else {
            errorMessage = "Use a private LAN IPv4 address or trusted .local Hue Bridge hostname."
            return
        }
        await probe(.init(id: host, host: host))
    }

    func pairPendingBridge() async {
        guard !isBusy, let pendingProfile else { return }
        isBusy = true
        connectionState = .connecting
        defer { isBusy = false }
        do {
            let credential = try await client.pair(profile: pendingProfile)
            try keychain.save(credential)
            try await persistence.saveProfile(pendingProfile)
            self.profile = pendingProfile
            self.credential = credential
            try await loadInventory(profile: pendingProfile, credential: credential)
            connectionState = .ready
            self.pendingProfile = nil
            isConnectionSheetPresented = false
            note = "Paired over pinned HTTPS. Opening and refreshing Hue Board do not change lights."
        } catch {
            connectionState = .awaitingBridgeButton
            errorMessage = error.localizedDescription
        }
    }

    func refreshInventory() async {
        guard let profile, let credential, !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            try await loadInventory(profile: profile, credential: credential)
            note = "Bridge state refreshed over pinned HTTPS. No light writes were sent."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func forgetBridge() async {
        guard canForgetBridge, let profile else {
            errorMessage = "Stop and restore the current area before removing Bridge credentials."
            return
        }
        do {
            try keychain.removeCredential(bridgeID: profile.bridgeID)
            try await persistence.clearBridgeState(bridgeID: profile.bridgeID)
            self.profile = nil
            credential = nil
            areas = []
            selectedAreaID = nil
            pendingProfile = nil
            manualHost = ""
            connectionState = .disconnected
            playback = HuePlaybackMachine()
            note = "Bridge credentials and certificate pin were removed from this device."
            isConnectionSheetPresented = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadInventory(profile: BridgeProfile, credential: HueBridgeCredential) async throws {
        let values = try await client.inventory(profile: profile, credential: credential)
        areas = values
        let saved = await persistence.loadSelectedAreaID(bridgeID: profile.bridgeID)
        if let saved, values.contains(where: { $0.id == saved }) {
            selectedAreaID = saved
        } else {
            selectedAreaID = values.first?.id
            await persistence.saveSelectedAreaID(selectedAreaID, bridgeID: profile.bridgeID)
        }
        try await loadRecoveryState()
    }
}
