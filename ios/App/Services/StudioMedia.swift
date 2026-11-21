import AVFoundation
import Foundation
import HueBoardNativeCore
import Observation
import os

@MainActor
@Observable
final class StudioMedia {
  private final class Clip {
    let id = UUID()
    let available = OSAllocatedUnfairLock(initialState: true)
    let sampler: NativeMediaSampler
    private let url: URL
    private let hasScopedAccess: Bool

    init(url: URL) {
      self.url = url
      hasScopedAccess = url.startAccessingSecurityScopedResource()
      sampler = NativeMediaSampler(url: url)
    }

    deinit {
      if hasScopedAccess { url.stopAccessingSecurityScopedResource() }
    }
  }

  private enum ClipError: LocalizedError {
    case localFileRequired, unplayable

    var errorDescription: String? {
      switch self {
      case .localFileRequired: "Choose an audio or video file from Files."
      case .unplayable: "Hue Board couldn’t play the selected audio or video file."
      }
    }
  }

  private(set) var player: AVPlayer?
  private(set) var hasVideo = false
  @ObservationIgnored private var clip: Clip?
  @ObservationIgnored private var duration: TimeInterval = 0
  @ObservationIgnored private var observers: [NSObjectProtocol] = []

  func start(url: URL) async throws -> TimeInterval {
    try Task.checkCancellation()
    guard url.isFileURL else { throw ClipError.localFileRequired }
    stop()

    let opening = Clip(url: url)
    clip = opening
    observeInterruptions(for: opening)
    do {
      let metadata = try await opening.sampler.prepare()
      try Task.checkCancellation()
      guard clip === opening, opening.available.withLock({ $0 }) else { throw CancellationError() }
      guard metadata.duration.isFinite, metadata.duration > 0,
            metadata.hasAudio || metadata.hasVideo else { throw ClipError.unplayable }

      let player = AVPlayer(url: url)
      duration = metadata.duration
      hasVideo = metadata.hasVideo
      self.player = player
      return metadata.duration
    } catch {
      guard clip === opening else { throw CancellationError() }
      stop()
      try Task.checkCancellation()
      throw error
    }
  }

  func play() {
    if clip?.available.withLock({ $0 }) == true { player?.play() }
  }

  func verifyPlayback() throws {
    try Task.checkCancellation()
    guard let player, clip?.available.withLock({ $0 }) == true else { throw CancellationError() }
    if player.status == .failed || player.currentItem?.status == .failed {
      throw player.currentItem?.error ?? player.error ?? ClipError.unplayable
    }
    let elapsed = CMTimeGetSeconds(player.currentTime())
    if elapsed >= duration || player.timeControlStatus == .paused { throw CancellationError() }
  }

  func signal() async throws -> HueLiveSignal {
    try verifyPlayback()
    guard let clip, let player else { throw CancellationError() }
    if player.timeControlStatus == .waitingToPlayAtSpecifiedRate { return HueLiveSignal(level: 0) }
    let elapsed = CMTimeGetSeconds(player.currentTime())

    do {
      let signal = try await clip.sampler.signal(at: elapsed.isFinite ? max(0, elapsed) : 0)
      guard self.clip === clip, clip.available.withLock({ $0 }) else { throw CancellationError() }
      try verifyPlayback()
      try Task.checkCancellation()
      return signal
    } catch {
      guard self.clip === clip, !Task.isCancelled else { throw CancellationError() }
      throw error
    }
  }

  func stop() {
    clip?.available.withLock { $0 = false }
    for observer in observers { NotificationCenter.default.removeObserver(observer) }
    observers.removeAll()
    player?.pause()
    player?.replaceCurrentItem(with: nil)
    player = nil
    hasVideo = false
    duration = 0
    // In-flight preparation and samples keep their own access until they finish.
    clip = nil
  }

  private func observeInterruptions(for clip: Clip) {
    let id = clip.id
    let available = clip.available
    for name in [AVAudioSession.interruptionNotification,
                 AVAudioSession.routeChangeNotification,
                 AVAudioSession.mediaServicesWereResetNotification] {
      let observer = NotificationCenter.default.addObserver(forName: name, object: nil, queue: nil) {
        [weak self] notification in
        if notification.name == AVAudioSession.interruptionNotification {
          let type = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
          guard type == AVAudioSession.InterruptionType.began.rawValue else { return }
        }
        if notification.name == AVAudioSession.routeChangeNotification {
          let reason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
          guard reason == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue else { return }
        }
        available.withLock { $0 = false }
        Task { @MainActor [weak self] in
          guard self?.clip?.id == id else { return }
          self?.stop()
        }
      }
      observers.append(observer)
    }
  }
}
