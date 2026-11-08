import Foundation
import Observation
import HueBoardAppleEngine
import HueBoardKit
import HueBoardNativeCore

@MainActor
@Observable
final class AppModel {
    enum Tab: Hashable { case lights, scenes, live, settings }
    enum ConnectionState: Equatable {
        case disconnected
        case discovering
        case probing
        case awaitingBridgeButton
        case connecting
        case ready
    }

    var selectedTab: Tab = .lights
    var connectionState: ConnectionState = .disconnected
    var discoveredBridges: [HueBridgeCandidate] = []
    var manualHost = ""
    var pendingProfile: BridgeProfile?
    var profile: BridgeProfile?
    var credential: HueBridgeCredential?
    var areas: [HueArea] = []
    var selectedAreaID: HueResourceID?
    var selectedPresetID: String
    var brightness = 60.0
    var liveDuration: TimeInterval = 15 * 60
    var playback = HuePlaybackMachine()
    var liveProgress = 0.0
    var note = "Connect a Hue Bridge to begin. Opening Hue Board never changes lights."
    var errorMessage: String?
    var isBusy = false
    var isConnectionSheetPresented = false
    var hasRestorePoint = false
    var restoreAreaID: HueResourceID?

    let contract: HueBoardContract
    let engine: JavaScriptHueEngine

    @ObservationIgnored private let client = HueBridgeClient()
    @ObservationIgnored private let persistence = AppPersistence.shared
    @ObservationIgnored private let keychain = KeychainVault()
    @ObservationIgnored private var foregroundLiveTask: Task<Void, Never>?

    init() {
        do {
            contract = try HueBoardContractLoader.load()
            engine = try JavaScriptHueEngine()
        } catch {
            preconditionFailure("Hue Board native resources are invalid: \(error.localizedDescription)")
        }
        selectedPresetID = contract.presets.first?.id ?? "ion-eclipse"
    }

    var selectedArea: HueArea? {
        if let selectedAreaID, let area = areas.first(where: { $0.id == selectedAreaID }) { return area }
        return areas.first
    }

    var selectedPreset: HuePreset? { contract.preset(id: selectedPresetID) }
    var isReady: Bool { connectionState == .ready && profile != nil && credential != nil }
    var playbackSnapshot: HuePlaybackSnapshot { playback.snapshot }
    var isLiveRunning: Bool {
        (playback.snapshot.mode == .liveForeground || playback.snapshot.mode == .liveContinued)
            && playback.snapshot.phase == .running
    }
    var canSwitchArea: Bool { !hasRestorePoint && !isLiveRunning && !isBusy }
    var canUseEverydayControls: Bool {
        isReady && !hasRestorePoint && playback.snapshot.mode != .bridge && !isLiveRunning && !isBusy
    }
    var canPlayScene: Bool {
        isReady && !isLiveRunning && !isBusy
            && (!hasRestorePoint || restoreAreaID == selectedAreaID)
    }
    var canStartLive: Bool { isReady && !hasRestorePoint && playback.snapshot.mode != .bridge && !isBusy }
    var canForgetBridge: Bool { isReady && !hasRestorePoint && !isLiveRunning && !isBusy }

    func bootstrap() async {
        guard connectionState == .disconnected else { return }
        do {
            guard let savedProfile = try await persistence.loadProfile() else {
                isConnectionSheetPresented = true
                return
            }
            guard let savedCredential = try keychain.credential(bridgeID: savedProfile.bridgeID) else {
                pendingProfile = savedProfile
                manualHost = savedProfile.host
                connectionState = .awaitingBridgeButton
                isConnectionSheetPresented = true
                return
            }
            connectionState = .connecting
            profile = savedProfile
            credential = savedCredential
            try await loadInventory(profile: savedProfile, credential: savedCredential)
            connectionState = .ready
            note = "Connected. Play delegates to the Bridge; Native Live is explicit and bounded."
        } catch {
            connectionState = .disconnected
            errorMessage = error.localizedDescription
            isConnectionSheetPresented = true
        }
    }

    func discoverBridges() async {
        guard !isBusy else { return }
        isBusy = true
        connectionState = .discovering
        defer { isBusy = false }
        do {
            discoveredBridges = try await client.discover()
            connectionState = .disconnected
            note = discoveredBridges.isEmpty
                ? "No Bridges were discovered. Enter a private LAN address manually."
                : "Choose a discovered Bridge or enter its private LAN address."
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
            note = "Bridge identity verified. Press the physical Bridge button, then pair."
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
            note = "Paired. Opening and refreshing Hue Board do not change lights."
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
            note = "Bridge state refreshed. No light writes were sent."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func selectArea(_ id: HueResourceID) async {
        guard canSwitchArea else {
            errorMessage = "Stop and restore the current area before switching rooms or zones."
            return
        }
        selectedAreaID = id
        if let profile { await persistence.saveSelectedAreaID(id, bridgeID: profile.bridgeID) }
        await loadRecoveryState()
    }

    func setAreaPower(_ on: Bool)async {
        guard canUseEverydayControls, let profile, let credential, let area = selectedArea else {
            if !canUseEverydayControls { errorMessage = "Stop and restore active playback before using everyday controls." }
            return
        }
        isBusy = true
        defer { isBusy = false }
        do {
            for light in area.lights where light.capabilities.power && !light.capabilities.streaming {
                try await client.updateLight(
                    id: light.id,
                    action: HueLightAction(on: .init(on: on)),
                    profile: profile,
                    credential: credential
                )
            }
            try await loadInventory(profile: profile, credential: credential)
            note = on ? "Power-on commands accepted." : "Power-off commands accepted."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setAreaBrightness(_ value: Double) async {
        guard canUseEverydayControls, let profile, let credential, let area = selectedArea else {
            if !canUseEverydayControls { errorMessage = "Stop and restore active playback before changing brightness." }
            return
        }
        brightness = min(max(value, 1), 100)
        isBusy = true
        defer { isBusy = false }
        do {
            for light in area.lights where light.capabilities.dir‰íz{hš+my×è®W§‚Ø