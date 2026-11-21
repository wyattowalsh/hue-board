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
    let remaining = journal.snapshotsAwaitingRestoreReadback(in: readback)
    guard remaining.count != journal.snapshots.count else { return }
    if remaining.isEmpty {
      do { try await persistence.saveRestoreJournal(nil) } catch { return }
      hasRestorePoint = false
      foreignRecoveryPending = false
      restoreAreaID = nil
      playback.stop("Bridge readback matches the saved baseline for the restored lights.")
      note = playback.snapshot.message
      return
    }
    journal.snapshots = remaining
    do { try await persistence.saveRestoreJournal(journal) } catch { return }
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
    let touched = area.lights.filter { touchedIDs.contains($0.id) }
    guard !touched.isEmpty else { throw HueBoardError.unsupported("No compatible lights are selected.") }
    if var existing = try await persistence.loadRestoreJournal() {
      guard existing.bridgeID == profile.bridgeID, existing.areaID == area.id else {
        throw HueBoardError.unsupported("Restore the previous area before starting new playback.")
      }
      if try existing.captureMissing(from: area, touchedIDs: touchedIDs) > 0 {
        try await persistence.saveRestoreJournal(existing)
      }
      hasRestorePoint = true
      restoreAreaID = existing.areaID
      return
    }
    let journal = RestoreJournal(bridgeID: profile.bridgeID, area: area, lights: touched)
    try await persistence.saveRestoreJournal(journal)
    hasRestorePoint = true
    restoreAreaID = area.id
  }

  func startForegroundLive(work: @escaping ContinuedLiveCoordinator.Work, reason: String) {
    note = "Ambient Live is foreground-only: \(reason)"
    foregroundLiveTask = Task {
      _ = try? await work { _, _ in }
    }
  }
}
