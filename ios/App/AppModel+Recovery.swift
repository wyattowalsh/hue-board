import Foundation
import HueBoardKit
import HueBoardNativeCore

@MainActor
extension AppModel {
  var canStopAndRestore: Bool {
    isReady && !isBusy && !emergencyOffInFlight && !foreignRecoveryPending
  }

  func loadRecoveryState() async throws {
    guard let profile else {
      hasRestorePoint = false
      foreignRecoveryPending = false
      restoreAreaID = nil
      return
    }
    let journal = try await persistence.loadRestoreJournal()
    guard let journal else {
      hasRestorePoint = false
      foreignRecoveryPending = false
      restoreAreaID = nil
      return
    }
    if journal.bridgeID == profile.bridgeID {
      hasRestorePoint = true
      foreignRecoveryPending = false
      restoreAreaID = journal.areaID
      playback = HuePlaybackMachine(snapshot: .init(mode: .failed, phase: .uncertain,
        message: "A saved baseline from \(journal.createdAt.formatted()) needs review before new playback."))
      note = playback.snapshot.message
      return
    }
    hasRestorePoint = false
    foreignRecoveryPending = true
    restoreAreaID = nil
    playback = HuePlaybackMachine(snapshot: .init(mode: .failed, phase: .uncertain,
      message: "A saved baseline for Bridge \(journal.bridgeID) is still pending. Reconnect that Bridge and restore it before changing lights on this one."))
    note = playback.snapshot.message
  }

  func reconcileAcceptedRestore(in readback: [HueArea], bridgeID: String) async {
    guard var journal = try? await persistence.loadRestoreJournal(),
          journal.restoreAcceptedAt != nil,
          journal.bridgeID == bridgeID,
          profile?.bridgeID == bridgeID,
          !emergencyOffInFlight,
          playback.snapshot.mode != .stopping else { return }
    let reviewed = journal
    let remaining = journal.snapshotsAwaitingRestoreReadback(in: readback)
    guard remaining.count != journal.snapshots.count else { return }
    if remaining.isEmpty {
      guard (try? await persistence.replaceRestoreJournal(nil, matching: reviewed)) == true else { return }
      hasRestorePoint = false
      foreignRecoveryPending = false
      restoreAreaID = nil
      playback.stop("Bridge readback matches the saved baseline for the restored lights.")
      note = playback.snapshot.message
      return
    }
    journal.snapshots = remaining
    guard (try? await persistence.replaceRestoreJournal(journal, matching: reviewed)) == true else { return }
    hasRestorePoint = true
    foreignRecoveryPending = false
    restoreAreaID = journal.areaID
  }

  func discardForeignBaseline() async {
    guard foreignRecoveryPending, !isBusy, let profile else { return }
    isBusy = true
    defer { isBusy = false }
    do {
      guard let journal = try await persistence.loadRestoreJournal(),
            journal.bridgeID != profile.bridgeID else {
        foreignRecoveryPending = false
        return
      }
      try await persistence.saveRestoreJournal(nil)
      foreignRecoveryPending = false
      hasRestorePoint = false
      restoreAreaID = nil
      playback.stop("The other Bridge's unrestored baseline was deleted. Those lights were not changed.")
      note = playback.snapshot.message
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func ensureRestoreJournal(profile: BridgeProfile, area: HueArea, touchedIDs: Set<HueResourceID>) async throws {
    let journal = try await persistence.captureRestoreBaseline(bridgeID: profile.bridgeID, area: area, touchedIDs: touchedIDs)
    hasRestorePoint = true
    restoreAreaID = journal.areaID
  }

  func startForegroundLive(work: @escaping ContinuedLiveCoordinator.Work, reason: String) {
    note = "Ambient Live is foreground-only: \(reason)"
    foregroundLiveTask = Task {
      _ = try? await work { _, _ in }
    }
  }
}
