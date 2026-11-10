import Foundation
import HueBoardKit
import HueBoardNativeCore

@MainActor
extension AppModel {
  func loadRecoveryState() async throws {
    guard let profile else {
      hasRestorePoint = false
      restoreAreaID = nil
      return
    }
    let journal = try await persistence.loadRestoreJournal()
    hasRestorePoint = journal?.bridgeID == profile.bridgeID
    restoreAreaID = hasRestorePoint ? journal?.areaID : nil
    if let journal, journal.bridgeID == profile.bridgeID {
      playback = HuePlaybackMachine(snapshot: .init(mode: .failed, phase: .uncertain,
        message: "A saved baseline from \(journal.createdAt.formatted()) needs review before new playback."))
      note = playback.snapshot.message
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
    foregroundLiveTask = Task { [weak self] in
      do { try await work { _, _ in } }
      catch is CancellationError { await MainActor.run { self?.note = "Ambient Live stopped." } }
      catch { await MainActor.run { self?.playback.fail(error.localizedDescription); self?.errorMessage = error.localizedDescription } }
    }
  }
}
