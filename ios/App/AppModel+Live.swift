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
    let startID = UUID()
    let input = studioLiveInput
    let mediaURL = studioMediaURL
    let requestedDuration = liveDuration
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
    let contract = contract
    let studioSnapshot: HueEngineSettings = {
      var captured = studioSettings
      captured.brightness = brightness
      return captured
    }()

    isBusy = true
    liveStartupID = startID
    if input != .engine { studioCaptureSessionID = startID }
    var launched = false
    defer {
      if !launched { stopStudioCapture(sessionID: startID) }
      if liveStartupID == startID {
        liveStartupID = nil
        isBusy = false
      }
    }
    var lease: PlaybackWriterLease?
    var startupDescriptorID: UUID?

    do {
      if let cueSnapshot { try cueSnapshot.validate(contract: contract) }
      let freshAreas = try await client.inventory(
        profile: profile,
        credential: credential,
        outputLimits: preservedOutputCeilings()
      )
      try checkStudioLiveStartup(startID)
      guard let freshArea = freshAreas.first(where: { $0.id == area.id }) else {
        throw HueBoardError.missingResource("The selected area is no longer available.")
      }
      try spatialSnapshot.validate(for: freshArea)
      let selected = spatialSnapshot.selectedEntries(in: freshArea).filter {
        $0.0.minimumBrightness <= safetySettings.maximumDynamicBrightness
      }
      guard !selected.isEmpty else {
        throw HueBoardError.unsupported(
          "No selected color lights are available within the current brightness limit."
        )
      }
      if input != .engine, !selected.contains(where: { !$0.1.role.isStatic }) {
        throw HueBoardError.unsupported("Select a fixture with a moving role in Room to use a Live input.")
      }

      let duration: TimeInterval
      let signal: (@Sendable (TimeInterval) async throws -> HueLiveSignal)?
      let verifyInput: @Sendable () async throws -> Void
      switch input {
      case .engine:
        duration = requestedDuration
        signal = nil
        verifyInput = {}
      case .microphone:
        let microphone = studioMicrophone
        try await microphone.start()
        duration = requestedDuration
        signal = { _ in
          guard microphone.isCapturing else {
            throw HueBoardError.unsupported("Microphone capture ended. Restore the saved baseline before starting again.")
          }
          return microphone.signal()
        }
        verifyInput = {
          guard microphone.isCapturing else { throw CancellationError() }
        }
      case .media:
        guard let mediaURL else {
          throw HueBoardError.missingResource("Choose a local audio or video file in Studio.")
        }
        let media = studioMedia
        duration = min(requestedDuration, try await media.start(url: mediaURL))
        signal = { _ in try await media.signal() }
        verifyInput = { try await media.verifyPlayback() }
      }
      try checkStudioLiveStartup(startID)

      let touched = Set(selected.map { $0.0.id })
      try await ensureRestoreJournal(profile: profile, area: freshArea, touchedIDs: touched)
      try checkStudioLiveStartup(startID)

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
        duration: duration
      )
      let ownedLease = try await playbackCoordinator.begin(request, using: transport)
      lease = ownedLease
      try checkStudioLiveStartup(startID)

      let runner = NativeLiveRunner(engine: engine)
      let descriptor = LiveSessionDescriptor(
        profile: profile,
        area: freshArea,
        presetID: preset.id,
        brightness: brightness,
        duration: requestedDuration,
        mediaDuration: input == .media ? duration : nil
      )
      try await persistence.beginLiveSession(descriptor)
      startupDescriptorID = descriptor.id
      try checkStudioLiveStartup(startID)
      activePlaybackLease = ownedLease

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
            signal: signal,
            submit: { frame in
              try await verifyInput()
              try await playbackCoordinator.submit(frame, lease: ownedLease)
            }
          ) { progress in
            guard !Task.isCancelled, await playbackCoordinator.isCurrent(ownedLease) else { return }
            let cueLabel = progress.cue.map { cue -> String in
              let name = contract.preset(id: cue.presetID)?.name ?? "Unknown cue"
              return "Cue \(cue.position + 1)/\(cue.count): \(name) · \(Int(cue.remaining))s"
            }
            update(
              progress.fraction,
              cueLabel ?? "\(Int(progress.fraction * 100))% · \(Int(progress.remaining))s remaining"
            )
            _ = try? await persistence.saveLiveStatusIfCurrent(
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
          await MainActor.run {
            if let app = model.value { app.stopStudioCapture(sessionID: startID) }
          }
          _ = try? await persistence.saveLiveStatusIfCurrent(
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
        } catch let failure where failure is CancellationError || Task.isCancelled {
          await MainActor.run {
            if let app = model.value { app.stopStudioCapture(sessionID: startID) }
          }
          _ = await playbackCoordinator.stopCurrent(reason: .cancelled, matching: ownedLease)
          let progress = await MainActor.run { model.value?.liveProgress ?? 0 }
          _ = try? await persistence.saveLiveStatusIfCurrent(
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
              input == .engine
                ? "Ambient Live was cancelled by iOS. Restore the saved baseline before retrying."
                : "Studio Live input stopped. Restore the saved baseline before starting again."
            )
            model.note = model.playback.snapshot.message
          }
          throw CancellationError()
        } catch {
          await MainActor.run {
            if let app = model.value { app.stopStudioCapture(sessionID: startID) }
          }
          _ = await playbackCoordinator.stopCurrent(reason: .failed, matching: ownedLease)
          let progress = await MainActor.run { model.value?.liveProgress ?? 0 }
          _ = try? await persistence.saveLiveStatusIfCurrent(
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

      if input != .engine {
        _ = playback.beginLive(presetID: preset.id, duration: duration, continued: false)
        if input == .media { studioMedia.play() }
        startForegroundLive(work: work, reason: "\(input.rawValue) stops when Hue Board moves to the background.")
      } else if #available(iOS 26.0, *) {
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
      launched = true
    } catch {
      if let lease {
        _ = await playbackCoordinator.stopCurrent(reason: .failed, matching: lease)
      }
      if let startupDescriptorID {
        _ = try? await persistence.saveLiveStatusIfCurrent(
          .init(sessionID: startupDescriptorID, state: .cancelled, progress: 0,
                message: "Ambient Live startup was cancelled.", updatedAt: Date())
        )
      }
      guard liveStartupID == startID else { return }
      activePlaybackLease = nil
      if hasRestorePoint { playback.fail(error.localizedDescription) }
      if error is CancellationError { return }
      errorMessage = error.localizedDescription
    }
  }

  private func checkStudioLiveStartup(_ startID: UUID) throws {
    try Task.checkCancellation()
    guard liveStartupID == startID else { throw CancellationError() }
  }

  private func stopStudioCapture(sessionID: UUID? = nil) {
    guard let current = studioCaptureSessionID, sessionID == nil || sessionID == current else { return }
    studioCaptureSessionID = nil
    studioMicrophone.stop()
    studioMedia.stop()
  }

  func cancelStudioLiveSetupAndCapture() {
    liveStartupID = nil
    stopStudioCapture()
  }

  func setStudioSceneBackgrounded(_ backgrounded: Bool) {
    studioSceneIsBackgrounded = backgrounded
    guard backgrounded, studioCaptureSessionID != nil else { return }
    if liveStartupID != nil { isBusy = false }
    cancelStudioLiveSetupAndCapture()
    foregroundLiveTask?.cancel()
    foregroundLiveTask = nil
  }

  func stopAndRestore() async {
    guard !isBusy, !emergencyOffInFlight else { return }
    guard !foreignRecoveryPending else {
      errorMessage = "Reconnect the original Bridge to restore its saved baseline."
      return
    }
    guard canStopAndRestore, let profile, let credential else {
      errorMessage = "Reconnect the saved Bridge before trying to restore."
      return
    }
    isBusy = true
    playback.beginStopping()
    currentCueStatus = nil
    cancelStudioLiveSetupAndCapture()
    foregroundLiveTask?.cancel()
    foregroundLiveTask = nil
    ContinuedLiveCoordinator.shared.cancel()
    await stopCoordinatedPlayback(reason: .recovery)
    defer { isBusy = false }

    do {
      guard var journal = try await persistence.loadRestoreJournal() else {
        playback.stop("No saved restore point was available.")
        hasRestorePoint = false
        restoreAreaID = nil
        return
      }
      guard journal.bridgeID == profile.bridgeID else {
        throw HueBoardError.invalidResponse("Saved restore state belongs to a different Bridge.")
      }

      let freshAreas = try await client.inventory(
        profile: profile,
        credential: credential,
        outputLimits: preservedOutputCeilings()
      )
      guard !emergencyOffInFlight, playback.snapshot.mode == .stopping else { return }
      let eligible = journal.snapshotsEligibleForRestore(in: freshAreas)
      guard !eligible.isEmpty else {
        throw HueBoardError.unsupported(
          "The saved lights are unavailable, streaming, or no longer support their saved settings. The saved baseline is retained."
        )
      }
      if journal.restoreAcceptedAt != nil {
        // A new attempt supersedes prior acknowledgments but preserves every
        // remaining snapshot until this attempt is accepted and verified.
        journal.restoreAcceptedAt = nil
        try await persistence.saveRestoreJournal(journal)
      }
      guard !emergencyOffInFlight, playback.snapshot.mode == .stopping else { return }
      let lease = try await beginDirectControl(
        profile: profile,
        credential: credential,
        areaID: journal.areaID,
        allowedLightIDs: Set(eligible.map(\.lightID)),
        purpose: "restore-baseline"
      )
      let skipped = journal.snapshots.count - eligible.count
      var failures = 0
      for (index, snapshot) in eligible.enumerated() {
        do {
          try await playbackCoordinator.submit(
            .init(
              sequence: UInt64(index + 1),
              actions: [snapshot.lightID: snapshot.action]
            ),
            lease: lease
          )
        } catch {
          failures += 1
        }
      }
      await finishDirectControl(lease)
      guard !emergencyOffInFlight, playback.snapshot.mode == .stopping else { return }

      if failures == 0, skipped == 0 {
        var accepted = journal
        accepted.restoreAcceptedAt = Date()
        try await persistence.saveRestoreJournal(accepted)
        try await persistence.clearLiveSession()
        liveProgress = 0
        try await loadInventory(profile: profile, credential: credential)
        if hasRestorePoint {
          playback.fail("Static restore commands accepted. The baseline stays until Bridge readback matches it.")
          note = playback.snapshot.message
        }
      } else {
        playback.fail(
          "Restore incomplete. \(skipped) lights were unavailable or unsupported and \(failures) commands failed. The saved baseline is retained."
        )
        note = playback.snapshot.message
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
