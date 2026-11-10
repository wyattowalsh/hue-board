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
    var lease: PlaybackWriterLease?

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

      let transport = RestAmbientTransport(
        client: client,
        profile: profile,
        credential: credential,
        allowedLightIDs: touched
      )
      let request = LightingPlaybackRequest(
        scope: .init(bridgeID: profile.bridgeID, areaID: freshArea.id),
        transport: .restAmbient,
        presetID: preset.id,
        duration: liveDuration
      )
      let ownedLease = try await playbackCoordinator.begin(request, using: transport)
      lease = ownedLease
      activePlaybackLease = ownedLease

      let runner = NativeLiveRunner(engine: engine)
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
      let playbackCoordinator = playbackCoordinator
      let model = WeakAppModelReference(self)
      let work: ContinuedLiveCoordinator.Work = { [model, persistence] update in
        do {
          try await runner.run(
            area: freshArea,
            preset: preset,
            brightness: brightness,
            duration: duration,
            submit: { frame in
              try await playbackCoordinator.submit(frame, lease: ownedLease)
            }
          ) { progress in
            guard await playbackCoordinator.isCurrent(ownedLease) else { return }
            update(
              progress.fraction,
              "\(Int(progress.fraction * 100))% · \(Int(progress.remaining))s remaining"
            )
            try? await persistence.saveLiveStatus(
              .init(
                sessionID: descriptor.id,
                state: .running,
                progress: progress.fraction,
                message: "Ambient Live · \(Int(progress.fraction * 100))%",
                updatedAt: Date()
              )
            )
            await MainActor.run {
              guard model.value?.activePlaybackLease == ownedLease else { return }
              model.value?.liveProgress = progress.fraction
              model.value?.playback.updateLiveProgress(progress.fraction)
              model.value?.note = "Ambient Live · \(Int(progress.fraction * 100))%"
            }
          }
          try await playbackCoordinator.finish(ownedLease)
          try? await persistence.saveLiveStatus(
            .init(
              sessionID: descriptor.id,
              state: .completed,
              progress: 1,
              message: "Ambient Live completed.",
              updatedAt: Date()
            )
          )
          await MainActor.run {
            guard model.value?.activePlaybackLease == ownedLease else { return }
            model.value?.activePlaybackLease = nil
            model.value?.playback.finishLive()
            model.value?.note = "Ambient Live finished. Restore the saved baseline when ready."
          }
        } catch is CancellationError {
          if await playbackCoordinator.isCurrent(ownedLease) {
            _ = await playbackCoordinator.stopCurrent(reason: .cancelled)
          }
          let progress = await MainActor.run { model.value?.liveProgress ?? 0 }
          try? await persistence.saveLiveStatus(
            .init(
              sessionID: descriptor.id,
              state: .cancelled,
              progress: progress,
              message: "Ambient Live was cancelled.",
              updatedAt: Date()
            )
          )
          await MainActor.run {
            guard let model = model.value, model.activePlaybackLease == ownedLease else { return }
            model.activePlaybackLease = nil
            model.playback.fail(
              "Ambient Live was cancelled by iOS. Restore the saved baseline before retrying."
            )
            model.note = model.playback.snapshot.message
          }
          throw CancellationError()
        } catch {
          if await playbackCoordinator.isCurrent(ownedLease) {
            _ = await playbackCoordinator.stopCurrent(reason: .failed)
          }
          let progress = await MainActor.run { model.value?.liveProgress ?? 0 }
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
            guard model.value?.activePlaybackLease == ownedLease else { return }
            model.value?.activePlaybackLease = nil
            model.value?.playback.fail(error.localizedDescription)
            model.value?.errorMessage = error.localizedDescription
          }
          throw error
        }
      }

      if #available(iOS 26.0, *) {
        do {
          _ = playback.beginLive(presetID: preset.id, duration: duration, continued: true)
          try ContinuedLiveCoordinator.shared.submit(
            title: "Hue Board Ambient Live",
            subtitle: preset.name,
            work: work
          )
          note = "Ambient Live requested system continued processing. iOS can cancel or expire it."
        } catch {
          _ = playback.beginLive(presetID: preset.id, duration: duration, continued: false)
          startForegroundLive(work: work, reason: error.localizedDescription)
        }
      } else {
        _ = playback.beginLive(presetID: preset.id, duration: duration, continued: false)
        startForegroundLive(work: work, reason: "iOS 26 is required for continued processing.")
      }
    } catch {
      if let lease, await playbackCoordinator.isCurrent(lease) {
        _ = await playbackCoordinator.stopCurrent(reason: .failed)
      }
      activePlaybackLease = nil
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
    await stopCoordinatedPlayback(reason: .recovery)
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

      let lease = try await beginDirectControl(
        profile: profile,
        credential: credential,
        areaID: journal.areaID,
        allowedLightIDs: journal.capturedLightIDs,
        purpose: "restore-baseline"
      )
      var failures: [HueResourceID] = []
      for (index, snapshot) in journal.snapshots.enumerated() {
        do {
          try await playbackCoordinator.submit(
            .init(
              sequence: UInt64(index + 1),
              actions: [snapshot.lightID: snapshot.action]
            ),
            lease: lease
          )
        } catch {
          failures.append(snapshot.lightID)
        }
      }
      await finishDirectControl(lease)

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


private final class WeakAppModelReference: @unchecked Sendable {
  weak var value: AppModel?

  init(_ value: AppModel) {
    self.value = value
  }
}
