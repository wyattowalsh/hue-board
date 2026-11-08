import Foundation
import HueBoardKit
import HueBoardNativeCore

@MainActor
extension AppModel {
  func startNativeLive() async {
    guard canStartLive, let profile, let credential, let area = selectedArea,
      let preset = selectedPreset
    else { return }
    isBusy = true
    defer { isBusy = false }
    do {
      let freshAreas = try await client.inventory(profile: profile, credential: credential)
      guard let freshArea = freshAreas.first(where: { $0.id == area.id }) else {
        throw HueBoardError.missingResource("The selected area is no longer available.")
      }
      let touched = Set(
        freshArea.lights.filter {
          $0.capabilities.color && $0.capabilities.dimming && !$0.capabilities.streaming
        }.map(\.id))
      try await ensureRestoreJournal(profile: profile, area: freshArea, touchedIDs: touched)

      let runner = NativeLiveRunner(client: client, engine: engine)
      let duration = liveDuration
      let brightness = brightness
      let descriptor = LiveSessionDescriptor(
        profile: profile,
        area: freshArea,
        presetID: preset.id,
        brightness: brightness,
        duration: duration
      )
      try await persistence.saveLiveDescriptor(descriptor)

      let persistence = persistence
      let work: ContinuedLiveCoordinator.Work = { [weak self, persistence] update in
        do {
          try await runner.run(
            profile: profile,
            credential: credential,
            area: freshArea,
            preset: preset,
            brightness: brightness,
            duration: duration
          ) { progress in
            update(
              progress.fraction,
              "\(Int(progress.fraction * 100))% · \(Int(progress.remaining))s remaining"
            )
            try? await persistence.saveLiveStatus(
              .init(
                sessionID: descriptor.id,
                state: .running,
                progress: progress.fraction,
                message: "Native Live · \(Int(progress.fraction * 100))%",
                updatedAt: Date()
              )
            )
            await MainActor.run {
              self?.liveProgress = progress.fraction
              self?.playback.updateLiveProgress(progress.fraction)
              self?.note = "Native Live · \(Int(progress.fraction * 100))%"
            }
          }
          try? await persistence.saveLiveStatus(
            .init(
              sessionID: descriptor.id,
              state: .completed,
              progress: 1,
              message: "Native Live completed.",
              updatedAt: Date()
            )
          )
          await MainActor.run {
            self?.playback.finishLive()
            self?.note = "Native Live finished. Restore the saved baseline when ready."
          }
        } catch is CancellationError {
          let progress = await MainActor.run { self?.liveProgress ?? 0 }
          try? await persistence.saveLiveStatus(
            .init(
              sessionID: descriptor.id,
              state: .cancelled,
              progress: progress,
              message: "Native Live was cancelled.",
              updatedAt: Date()
            )
          )
          await MainActor.run {
            guard let self, self.isLiveRunning else { return }
            self.playback.fail(
              "Native Live was cancelled by iOS. Restore the saved baseline before retrying.")
            self.note = self.playback.snapshot.message
          }
          throw CancellationError()
        } catch {
          let progress = await MainActor.run { self?.liveProgress ?? 0 }
          try? await persistence.saveLiveStatus(
            .init(
              sessionID: descriptor.id,
              state: .failed,
              progress: progress,
              message: error.localizedDescription,
              updatedAt: Date()
            )
          )
          await MainActor.run {
            self?.playback.fail(error.localizedDescription)
            self?.errorMessage = error.localizedDescription
          }
          throw error
        }
      }

      if #available(iOS 26.0, *) {
        do {
          _ = playback.beginLive(presetID: preset.id, duration: duration, continued: true)
          try ContinuedLiveCoordinator.shared.submit(
            title: "Hue Board Native Live",
            subtitle: preset.name,
            work: work
          )
          note = "Native Live requested system continued processing. iOS can cancel or expire it."
        } catch {
          _ = playback.beginLive(presetID: preset.id, duration: duration, continued: false)
          startForegroundLive(work: work, reason: error.localizedDescription)
        }
      } else {
        _ = playback.beginLive(presetID: preset.id, duration: duration, continued: false)
        startForegroundLive(work: work, reason: "iOS 26 is required for continued processing.")
      }
    } catch {
      playback.fail(error.localizedDescription)
      errorMessage = error.localizedDescription
    }
  }

  func stopAndRestore() async {
    guard let profile, let credential, !isBusy else { return }
    isBusy = true
    playback.beginStopping()
    foregroundLiveTask?.cancel()
    foregroundLiveTask = nil
    ContinuedLiveCoordinator.shared.cancel()
    defer { isBusy = false }
    do {
      guard let journal = try await persistence.loadRestoreJournal() else {
        playback.stop("No saved restore point was available.")
        hasRestorePoint = false
        restoreAreaID = nil
        return
      }
      guard journal.bridgeID == profile.bridgeID else {
        throw HueBoardError.invalidResponse("Saved restore state belongs to a different Bridge.")
      }
      var failures: [HueResourceID] = []
      for snapshot in journal.snapshots {
        do {
          try await client.updateLight(
            id: snapshot.lightID,
            action: snapshot.action,
            profile: profile,
            credential: credential
          )
        } catch {
          failures.append(snapshot.lightID)
        }
      }
      if failures.isEmpty {
        try await persistence.saveRestoreJournal(nil)
        try await persistence.saveLiveDescriptor(nil)
        try await persistence.saveLiveStatus(.idle)
        hasRestorePoint = false
        restoreAreaID = nil
        liveProgress = 0
        playback.stop("Static restore commands accepted for \(journal.snapshots.count) lights.")
        note = playback.snapshot.message
        try await loadInventory(profile: profile, credential: credential)
      } else {
        playback.fail("Restore failed for \(failures.count) lights; the baseline was retained.")
        errorMessage = playback.snapshot.message
      }
    } catch {
      playback.fail(error.localizedDescription)
      errorMessage = error.localizedDescription
    }
  }
}
