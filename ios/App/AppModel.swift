import Foundation
import HueBoardAppleEngine
import HueBoardKit
import HueBoardNativeCore
import Observation

@MainActor
@Observable
final class AppModel {
  enum Tab: Hashable { case lights, scenes, live, room }
  enum PendingDynamicAction: Equatable {
    case bridge(presetID: String)
    case ambient
  }
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
  var roomLayout: HueRoomLayout?
  var roomLayoutIssue: String?
  var focusedFixtureID: HueResourceID?
  var roomLayoutScope: String?
  var selectedPresetID: String
  // An editable Studio draft. Editing it never sends a Bridge command.
  var studioSettings: HueEngineSettings = .init()
  var savedStudioDocuments: [HueSceneDocument] = []
  var studioLibraryIssue: String?
  var cueIDs: [String] = ["ion-eclipse", "plasma-turbine", "deep-orbit"]
  var cueHoldSeconds: Double = 90
  var cueOrder: HueCueOrder = .forward
  var isCueSequenceEnabled = false
  var currentCueStatus: String?
  var brightness = 60.0
  var liveDuration: TimeInterval = 15 * 60
  var playback = HuePlaybackMachine()
  var liveProgress = 0.0
  var eventStreamConnected = false
  var eventStreamDetail = "Paused while Hue Board is inactive."
  var lastEventAt: Date?
  var note = "Connect a Hue Bridge to begin. Opening Hue Board never changes lights."
  var errorMessage: String?
  var isBusy = false
  var isConnectionSheetPresented = false
  var isSettingsPresented = false
  var openConnectionAfterSettings = false

  func presentConnection() {
    if isSettingsPresented {
      openConnectionAfterSettings = true
      isSettingsPresented = false
    } else {
      isConnectionSheetPresented = true
    }
  }
  var hasRestorePoint = false
  var foreignRecoveryPending = false
  var emergencyOffInFlight = false
  var restoreAreaID: HueResourceID?
  var safetySettings: PhysicalLightSafetySettings = .default
  var pendingDynamicAction: PendingDynamicAction?
  var isDynamicLightSafetyPresented = false

  let contract: HueBoardContract
  let engine: JavaScriptHueEngine

  @ObservationIgnored nonisolated let client = HueBridgeClient()
  @ObservationIgnored nonisolated let eventClient = HueEventStreamClient()
  @ObservationIgnored nonisolated let persistence = AppPersistence.shared
  @ObservationIgnored nonisolated let safetyStore = PhysicalLightSafetyStore.shared
  @ObservationIgnored nonisolated let playbackCoordinator = PlaybackCoordinator()
  @ObservationIgnored nonisolated let localDiscovery = HueLocalDiscovery()
  @ObservationIgnored let keychain = KeychainVault()
  @ObservationIgnored let studioDocumentStore = StudioDocumentStore()
  @ObservationIgnored let roomLayoutStore = HueRoomLayoutStore()
  @ObservationIgnored var activePlaybackLease: PlaybackWriterLease?
  @ObservationIgnored var foregroundLiveTask: Task<Void, Never>?
  @ObservationIgnored var eventTask: Task<Void, Never>?
  @ObservationIgnored var eventRefreshTask: Task<Void, Never>?
  @ObservationIgnored var eventMonitorGeneration = 0
  @ObservationIgnored var eventRefreshGeneration = 0

  init() {
    do {
      contract = try HueBoardContractLoader.load()
      engine = try JavaScriptHueEngine()
    } catch {
      preconditionFailure("Hue Board native resources are invalid: \(error.localizedDescription)")
    }
    selectedPresetID = contract.presets.first?.id ?? "ion-eclipse"
    if let preset = contract.presets.first {
      studioSettings = HueEngineSettings.from(preset: preset, brightness: brightness)
    }
    do {
      savedStudioDocuments = try studioDocumentStore.load(contract: contract)
    } catch {
      // Preserve malformed or incompatible storage for recovery; never
      // replace it with a new empty library after a decode failure.
      studioLibraryIssue = error.localizedDescription
    }
  }

  var selectedArea: HueArea? {
    if let selectedAreaID, let area = areas.first(where: { $0.id == selectedAreaID }) {
      return area
    }
    return areas.first
  }

  var selectedPreset: HuePreset? { contract.preset(id: selectedPresetID) }

  // Load is deliberately explicit. Choosing a Bridge scene must not silently
  // replace a user's in-progress Studio composition.
  func loadPresetIntoStudio(_ preset: HuePreset) {
    guard !isLiveRunning else { return }
    selectedPresetID = preset.id
    studioSettings = HueEngineSettings.from(preset: preset, brightness: brightness)
  }
  var isReady: Bool { connectionState == .ready && profile != nil && credential != nil }
  var playbackSnapshot: HuePlaybackSnapshot { playback.snapshot }
  var eventStreamStatus: String {
    guard isReady else { return "Unavailable" }
    if eventStreamConnected { return "Receiving updates" }
    if eventTask != nil { return "Connecting" }
    return "Paused"
  }
  var isLiveRunning: Bool {
    (playback.snapshot.mode == .liveForeground || playback.snapshot.mode == .liveContinued)
      && playback.snapshot.phase == .running
  }
  var canSwitchArea: Bool { !hasRestorePoint && !isLiveRunning && !isBusy }
  var canUseEverydayControls: Bool {
    isReady && !requiresRecovery && playback.snapshot.mode != .bridge
      && !isLiveRunning && !isBusy
  }
  var canTurnOffNow: Bool { isReady && !foreignRecoveryPending && !emergencyOffInFlight }
  var requiresRecovery: Bool {
    foreignRecoveryPending
      || playback.snapshot.phase == .uncertain
      || playback.snapshot.mode == .stopping
      || (playback.snapshot.phase == .failed && hasRestorePoint)
  }
  var canPlayScene: Bool {
    isReady && !isLiveRunning && !isBusy && !requiresRecovery
      && (!hasRestorePoint || restoreAreaID == selectedAreaID)
  }
  var canStartLive: Bool {
    guard isReady, !hasRestorePoint, playback.snapshot.mode != .bridge,
          !requiresRecovery, !isBusy, roomLayoutIssue == nil,
          let area = selectedArea, let roomLayout else { return false }
    guard !roomLayout.selectedEntries(in: area).isEmpty else { return false }
    if isCueSequenceEnabled {
      let sequence = HueCueSequence(
        presetIDs: cueIDs,
        holdSeconds: cueHoldSeconds,
        order: cueOrder,
        seed: studioSettings.seed
      )
      return (try? sequence.validate(contract: contract)) != nil
    }
    return true
  }
  var canEditRoomLayout: Bool {
    isReady && !isBusy && !isLiveRunning && !hasRestorePoint
      && playback.snapshot.mode != .bridge && !requiresRecovery && !foreignRecoveryPending
  }
  var canForgetBridge: Bool {
    profile != nil && !hasRestorePoint && !foreignRecoveryPending && !isLiveRunning && !isBusy
  }
  func preservedOutputCeilings() -> [HueResourceID: Double] {
    var limits: [HueResourceID: Double] = [:]
    for light in areas.flatMap(\.lights) where limits[light.id] == nil {
      limits[light.id] = light.outputLimit
    }
    return limits
  }

  var effectiveDynamicBrightness: Double {
    PhysicalLightSafetyPolicy.clampedBrightness(
      brightness,
      settings: safetySettings
    )
  }
}
