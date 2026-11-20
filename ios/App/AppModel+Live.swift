import Foundation
import HueBoardKit
import HueBoardNativeCore

@MainActor
extension AppModel {
  func startNativeLive() async {
    guard canStartLive, let profile, let credential, let area = selectedArea,
      let preset = selectedPreset, let spatialSnapshot = roomLayout
    else { return }
    guard !requiresDynamicLightConsent(for: .ambient) else { return }
    isBusy = true
    defer { isBusy = false }
    var lease: PlaybackWriterLease?

    do {
      let freshAreas = try await client.inventory(
        profile: profile,
        credential: credential,
        outputLimits: preservedOutputCeilings()
      )
      guard let freshArea = freshAreas.first(where: { $0.id == area.id }) else {
        throw HueBoardError.missingResource("The selected area is no longer available.")
      }
      try spatialSnapshot.validate(for: freshArea)
      let touched = Set(
        spatialSnapshot.selectedEntries(in: freshArea).map { $0.0.id }
      )
      guard !touched.isEmpty else {
        throw HueBoardError.unsupported(
          "No selected color lights remain eligible for this Studio layout."
        )
      }
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
      let brightness = effectiveDynamicBrightness
      let safetySettings = safetySettings
      let cueSnapshot: HueCueSequence? = isCueSequenceEnabled
        ? HueCueSequence(
            presetIDs: cueIDs,
            holdSeconds: cueHoldSeconds,
            order: cueOrder,
            seed: studioSettings.seed
          )
        : nil
      if let cueSnapshot {
        try cueSnapshot.validate(contract: contract)
      }
      let contract = contract
      let studioSnapshot: HueEngineSettings = {
        var captured = studioSettings
        captured.brightness = brightness
        return captured
      }()
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
            layout: spatialSnapshot,
            settings: studioSnapshot,
            cueSequence: cueSnapshot,
            contract: contract,
            duration: duration,
            safetySettings: safetySettings,
            submit: { frame in
              try await playbackCoordinator.submit(frame, lease: ownedLease)
            }
          ) { progress in
            guard await playbackCoordinator.isCurrent(ownedLease) else { return }
            let cueLabel = progress.cue.map { cue -> String in
              let name = contract.preset(id: cue.presetID)?.name ?? "Unknown cue"
              return "Cue \(cue.position + 1)/\(cue.count): \(name) · \(Int(cue.remaining))s"
            }
            update(
              progress.fraction,
              cueLabel ?? "\(Int(progress.fraction * 100))% · \(Int(progress.remaining))s remaining"
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
              model.value?.currentCueStatus = cueLabel
              model.value?.playback.updateLiveProgress(progress.fraction)
              model.value?.note = cueLabel ?? "Studio Live · \(Int(progress.fraction * 100))%"
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
            model.value?.currentCueStatus = nil
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
    currentCueStatus = nil
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
        var accepted = journal
        accepted.restoreAcceptedAt = Date()
        try await persistence.saveRestoreJournal(accepted)
        try await persistence.saveLiveDescriptor(nil)
        try await persistence.saveLiveStatus(.idle)
        liveProgress = 0
        try await loadInventory(profile: profile, credential: credential)
        if hasRestorePoint {
          playback.fail("Static restore commands accepted. The baseline stays until Bridge readback matches it.")
          note = playback.snapshot.message
        }
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
