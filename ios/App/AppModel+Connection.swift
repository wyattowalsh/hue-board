import Foundation
import HueBoardKit
import HueBoardNativeCore

@MainActor
extension AppModel {
    func bootstrap() async {
        guard connectionState == .disconnected else { return }
        do {
            safetySettings = await safetyStore.load()
            guard let savedProfile = try await persistence.loadProfile() else {
                isConnectionSheetPresented = true
                return
            }
            profile = savedProfile
            manualHost = savedProfile.displayHost
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
            note = "Connected over pinned HTTPS. Play delegates to the Bridge; Ambient Live is explicit and bounded."
            startEventMonitoring()
        } catch {
            stopEventMonitoring()
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
                note = "Found \(discoveredBridges.count) Bridge candidate(s): \(localValues.count) local Bonjour result(s), \(cloudValues.count) broker result(s). Verify one before pairing."
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
            manualHost = value.displayHost
            connectionState = .awaitingBridgeButton
            note = "Bridge API identity and TLS certificate agree. Review the fingerprint, press the physical Bridge button, then pair."
        } catch {
            connectionState = .disconnected
            errorMessage = error.localizedDescription
        }
    }

    func probeManualHost() async {
        do {
            let endpoint = try HueBridgeEndpoint(parsing: manualHost)
            await probe(
                .init(
                    id: endpoint.displayHost,
                    host: endpoint.host,
                    port: endpoint.port
                )
            )
        } catch {
            errorMessage = error.localizedDescription
        }
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
            startEventMonitoring()
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
        await removeBridge(profile, discardRecovery: false)
    }

    func discardRecoveryAndForgetBridge() async {
        guard let profile, hasRestorePoint, !isBusy else {
            errorMessage = "A saved recovery baseline is required for destructive reset."
            return
        }
        await removeBridge(profile, discardRecovery: true)
    }

    private func removeBridge(_ profile: BridgeProfile, discardRecovery: Bool) async {
        isBusy = true
        stopEventMonitoring()
        foregroundLiveTask?.cancel()
        foregroundLiveTask = nil
        ContinuedLiveCoordinator.shared.cancel()
        await stopCoordinatedPlayback(reason: .user)
        defer { isBusy = false }

        var credentialRemoved = false
        do {
            if !discardRecovery, try await persistence.loadRestoreJournal() != nil {
                throw HueBoardError.unsupported("Restore the saved baseline before removing this Bridge.")
            }
            try keychain.removeCredential(bridgeID: profile.bridgeID)
            credentialRemoved = true
            credential = nil
            connectionState = .disconnected
            try await persistence.clearBridgeState(bridgeID: profile.bridgeID, discardRecovery: discardRecovery)
            resetDisconnectedState()
            note = discardRecovery
                ? "Bridge credentials and the unrecoverable restore baseline were deleted from this device."
                : "Bridge credentials were removed from this device."
            isConnectionSheetPresented = true
        } catch {
            errorMessage = error.localizedDescription
            if credentialRemoved {
                note = "The Bridge credential was removed, but local metadata cleanup failed. No further Bridge requests will be sent; retry Forget to finish cleanup."
                isConnectionSheetPresented = true
            } else if isReady {
                startEventMonitoring()
            }
        }
    }

    private func resetDisconnectedState() {
        profile = nil
        credential = nil
        areas = []
        selectedAreaID = nil
        pendingProfile = nil
        discoveredBridges = []
        manualHost = ""
        lastEventAt = nil
        eventStreamConnected = false
        eventStreamDetail = "Unavailable until a Bridge is connected."
        connectionState = .disconnected
        playback = HuePlaybackMachine()
        liveProgress = 0
        hasRestorePoint = false
        restoreAreaID = nil
        activePlaybackLease = nil
    }

    func loadInventory(profile: BridgeProfile, credential: HueBridgeCredential) async throws {
        let values = try await client.inventory(profile: profile, credential: credential)
        areas = values
        let saved = try await persistence.loadSelectedAreaID(bridgeID: profile.bridgeID)
        if let saved, values.contains(where: { $0.id == saved }) {
            selectedAreaID = saved
        } else {
            selectedAreaID = values.first?.id
            try await persistence.saveSelectedAreaID(selectedAreaID, bridgeID: profile.bridgeID)
        }
        try await loadRecoveryState()
    }
}
