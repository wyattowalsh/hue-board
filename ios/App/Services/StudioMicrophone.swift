import Accelerate
import AVFoundation
import Foundation
import HueBoardNativeCore
import UIKit
import os

@MainActor
final class StudioMicrophone {
  private struct MeterState: Sendable {
    var captureID: UUID?
    var level = 0.0
  }

  private enum CaptureError: LocalizedError {
    case alreadyStartingOrRunning, permissionDenied, notForeground, inputUnavailable

    var errorDescription: String? {
      switch self {
      case .alreadyStartingOrRunning: "Studio is already using the microphone."
      case .permissionDenied: "Allow microphone access for Hue Board in Settings to use Microphone mode."
      case .notForeground: "Keep Hue Board on screen to use Microphone mode."
      case .inputUnavailable: "No microphone is available for Studio."
      }
    }
  }

  private nonisolated let meter = OSAllocatedUnfairLock(initialState: MeterState())
  private var captureID: UUID?
  private var engine: AVAudioEngine?
  private var audioSessionActive = false
  private var observers: [NSObjectProtocol] = []

  nonisolated var isCapturing: Bool { meter.withLock { $0.captureID != nil } }

  nonisolated func signal() -> HueLiveSignal {
    HueLiveSignal(level: meter.withLock { $0.level })
  }

  func start() async throws {
    guard captureID == nil else { throw CaptureError.alreadyStartingOrRunning }
    guard UIApplication.shared.applicationState == .active else { throw CaptureError.notForeground }
    let id = UUID()
    captureID = id
    observe(UIApplication.didEnterBackgroundNotification, id: id)
    do {
      let allowed = await AVAudioApplication.requestRecordPermission()
      try Task.checkCancellation()
      guard captureID == id else { throw CancellationError() }
      guard allowed else { throw CaptureError.permissionDenied }
      guard UIApplication.shared.applicationState == .active else { throw CaptureError.notForeground }

      let session = AVAudioSession.sharedInstance()
      try session.setCategory(.playAndRecord, mode: .measurement, options: [.mixWithOthers, .defaultToSpeaker])
      try session.setActive(true)
      audioSessionActive = true
      guard session.isInputAvailable else { throw CaptureError.inputUnavailable }

      let engine = AVAudioEngine()
      let input = engine.inputNode
      let format = input.outputFormat(forBus: 0)
      guard format.sampleRate > 0, format.channelCount > 0 else { throw CaptureError.inputUnavailable }

      let meter = self.meter
      meter.withLock { $0 = MeterState(captureID: id) }
      input.installTap(onBus: 0, bufferSize: 1024, format: nil) { @Sendable buffer, _ in
        let level = Self.level(in: buffer)
        meter.withLock { state in
          guard state.captureID == id else { return }
          let response = level > state.level ? 0.45 : 0.16
          state.level += response * (level - state.level)
        }
      }
      self.engine = engine
      observeCaptureLifecycle(id: id)
      engine.prepare()
      try engine.start()
    } catch {
      if captureID == id { stop() }
      throw error
    }
  }

  func stop() {
    captureID = nil
    meter.withLock { $0 = MeterState() }

    for observer in observers {
      NotificationCenter.default.removeObserver(observer)
    }
    observers.removeAll()
    if let engine {
      engine.stop()
      engine.inputNode.removeTap(onBus: 0)
      self.engine = nil
    }
    if audioSessionActive {
      try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
      audioSessionActive = false
    }
  }

  private func observeCaptureLifecycle(id: UUID) {
    observe(UIApplication.willResignActiveNotification, id: id)
    observe(AVAudioSession.mediaServicesWereResetNotification, id: id)
    observe(AVAudioSession.interruptionNotification, id: id) { notification in
      let type = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
      return type == AVAudioSession.InterruptionType.began.rawValue
    }
    observe(AVAudioSession.routeChangeNotification, id: id) { notification in
      let reason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
      return reason != AVAudioSession.RouteChangeReason.categoryChange.rawValue
    }
  }

  private func observe(
    _ name: Notification.Name,
    id: UUID,
    when shouldStop: @escaping @Sendable (Notification) -> Bool = { _ in true }
  ) {
    let meter = self.meter
    let observer = NotificationCenter.default.addObserver(forName: name, object: nil, queue: nil) {
      [weak self] notification in
      guard shouldStop(notification) else { return }
      meter.withLock {
        if $0.captureID == id { $0 = MeterState() }
      }
      Task { @MainActor [weak self] in
        guard let self, self.captureID == id else { return }
        self.stop()
      }
    }
    observers.append(observer)
  }

  private nonisolated static func level(in buffer: AVAudioPCMBuffer) -> Double {
    guard buffer.frameLength > 0, let samples = buffer.floatChannelData?.pointee else { return 0 }
    var meanSquare: Float = 0
    vDSP_measqv(samples, vDSP_Stride(buffer.stride), &meanSquare, vDSP_Length(buffer.frameLength))
    return normalizedLevel(meanSquare: meanSquare)
  }

  nonisolated static func normalizedLevel(meanSquare: Float) -> Double {
    guard meanSquare.isFinite, meanSquare > 0 else { return 0 }
    // 10 log10(meanSquare) is the RMS amplitude expressed in decibels.
    let decibels = 10 * log10(Double(meanSquare))
    return min(1, max(0, (decibels + 55) / 43))
  }
}
