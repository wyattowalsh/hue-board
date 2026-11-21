import Foundation
import HueBoardNativeCore
import Observation

/// Owns one foreground input until its last asynchronous sample has drained.
/// Preview has no Bridge client, persistence store or playback writer.
@MainActor
@Observable
final class StudioInputPreviewSession {
  enum Phase: Equatable { case idle, opening, monitoring, stopping }

  private(set) var phase: Phase = .idle
  private(set) var signal: HueLiveSignal?
  private(set) var message: String?
  private(set) var manualReadings = false

  @ObservationIgnored private var latest: HueLiveSignal?
  @ObservationIgnored private var task: Task<Void, Never>?
  @ObservationIgnored private var close: (@MainActor () -> Void)?

  var isIdle: Bool { phase == .idle }
  var canStop: Bool { phase == .opening || phase == .monitoring }

  func setManualReadings(_ enabled: Bool) {
    manualReadings = enabled
    refreshReading()
  }

  func refreshReading() {
    signal = latest
  }

  func start(
    manualReadings: Bool,
    interval: Duration,
    open: @escaping @MainActor () async throws -> Void,
    sample: @escaping @MainActor () async throws -> HueLiveSignal,
    close: @escaping @MainActor () -> Void
  ) {
    guard isIdle else { return }
    self.manualReadings = manualReadings
    self.close = close
    message = nil
    phase = .opening
    task = Task {
      var result: String?
      do {
        try Task.checkCancellation()
        try await open()
        while true {
          try Task.checkCancellation()
          let reading = try await sample()
          try Task.checkCancellation()
          latest = reading
          if !self.manualReadings || signal == nil {
            signal = reading
          }
          phase = .monitoring
          try await Task.sleep(for: interval)
        }
      } catch is CancellationError {
        if !Task.isCancelled { result = "Preview ended." }
      } catch {
        if !Task.isCancelled { result = error.localizedDescription }
      }
      self.close?()
      self.close = nil
      latest = nil
      signal = nil
      message = result
      phase = .idle
      task = nil
    }
  }

  @discardableResult
  func stop() -> Task<Void, Never>? {
    message = nil
    guard let task else { return nil }
    if canStop {
      phase = .stopping
      task.cancel()
      close?()
      close = nil
      latest = nil
      signal = nil
    }
    return task
  }
}
