import CoreMedia
import Foundation
import Observation
@preconcurrency import ScreenCaptureKit

/// The picker hands its filter to the main actor once. The callback never mutates it.
private struct PickerGrant: @unchecked Sendable { let filter: SCContentFilter }

/// One observer and output per picker activation, so a late callback cannot affect the next run.
private final class ProbeCallbacks: NSObject, SCContentSharingPickerObserver, SCStreamDelegate,
                                    SCStreamOutput, @unchecked Sendable {
  let id = UUID()
  let readings = ProbeReadings()
  let queue = DispatchQueue(label: "HueBoard.ScreenInputProbe.samples", qos: .utility)
  private weak var owner: ProbeCapture?

  init(_ owner: ProbeCapture) { self.owner = owner }

  func contentSharingPicker(_ picker: SCContentSharingPicker, didUpdateWith filter: SCContentFilter,
                            for stream: SCStream?) {
    let grant = PickerGrant(filter: filter)
    let updated = stream != nil
    Task { @MainActor [weak owner, id = self.id] in await owner?.grant(grant, id: id, updated: updated) }
  }

  func contentSharingPicker(_ picker: SCContentSharingPicker, didCancelFor stream: SCStream?) {
    Task { @MainActor [weak owner, id = self.id] in owner?.pickerEnded(id, reason: "Picker canceled.") }
  }

  func contentSharingPickerStartDidFailWithError(_ error: any Error) {
    Task { @MainActor [weak owner, id = self.id] in owner?.pickerEnded(id, reason: "System picker unavailable.") }
  }

  func stream(_ stream: SCStream, didStopWithError error: any Error) {
    readings.close()
    let notice = ProcessInfo.processInfo.systemUptime
    Task { @MainActor [weak owner, id = self.id] in await owner?.systemStopped(id, at: notice) }
  }

  func streamDidBecomeInactive(_ stream: SCStream) {
    readings.close()
    Task { @MainActor [weak owner, id = self.id] in owner?.streamInactive(id) }
  }

  func stream(_ stream: SCStream, didOutputSampleBuffer buffer: CMSampleBuffer, of type: SCStreamOutputType) {
    readings.consume(buffer, type: type)
  }
}

@MainActor
@Observable
final class ProbeCapture {
  enum Phase: String { case idle = "Idle", choosing = "Choose content", opening = "Starting",
                            active = "Capturing", stopping = "Stopping", uncertain = "Stop unconfirmed" }
  private(set) var phase: Phase = .idle
  private(set) var snapshot = ProbeSnapshot()
  private(set) var message = ""
  private(set) var result = ""
  let calibrated = ProbeNullSink.calibrate()
  var source: ProbeSource = .color
  var scope: ProbeScope = .app
  @ObservationIgnored private let picker = SCContentSharingPicker.shared
  @ObservationIgnored private var callbacks: ProbeCallbacks?
  @ObservationIgnored private var stream: SCStream?
  @ObservationIgnored private var opening: Task<Void, Never>?
  @ObservationIgnored private var resources = ProbeResources()
  @ObservationIgnored private var stoppingAt: Double?

  func choose() {
    guard phase == .idle, calibrated else { return }
    guard picker.isAvailable else { message = "Screen sharing is unavailable on this device."; return }
    let callbacks = ProbeCallbacks(self)
    self.callbacks = callbacks
    resources = ProbeResources()
    stoppingAt = nil
    snapshot = ProbeSnapshot()
    message = ""
    result = ""
    var config = SCContentSharingPickerConfiguration()
    config.showsMicrophoneControl = false
    config.showsCameraControl = false
    picker.defaultConfiguration = config
    picker.add(callbacks)
    picker.isActive = true
    phase = .choosing
    print("PROBE_ATTEMPT_AUDIT_ACTIVE positiveControl=1")
    if scope == .app { picker.presentForCurrentApplication() } else { picker.present() }
  }

  fileprivate func grant(_ grant: PickerGrant, id: UUID, updated: Bool) async {
    guard let callbacks, callbacks.id == id else { return }
    guard !updated, phase == .choosing else {
      if updated { stop(reason: "Selection changed. Choose a new scope to continue.") }
      return
    }
    let filter = grant.filter
    guard !filter.isMicrophoneEnabled, !filter.isCameraEnabled else {
      stop(reason: "The system selection requested a different input.")
      return
    }
    let config = SCStreamConfiguration()
    config.width = 192
    config.height = 108
    config.capturesAudio = source == .audio
    if source == .audio {
      config.sampleRate = 48_000
      config.channelCount = 1
      config.excludesCurrentProcessAudio = false
    }
    let stream = SCStream(filter: filter, configuration: config, delegate: callbacks)
    do {
      try stream.addStreamOutput(callbacks, type: source == .audio ? .audio : .screen,
                                 sampleHandlerQueue: callbacks.queue)
    } catch {
      stop(reason: "The selected output is unavailable.")
      return
    }
    self.stream = stream
    phase = .opening
    opening = Task {
      do {
        try await stream.startCapture()
        guard self.callbacks?.id == id, phase == .opening else { return }
        phase = .active
      } catch {
        guard self.callbacks?.id == id, phase == .opening else { return }
        finish(id, reason: "iOS could not start this capture scope.")
      }
    }
  }

  fileprivate func pickerEnded(_ id: UUID, reason: String) {
    guard callbacks?.id == id, phase == .choosing else { return }
    stop(reason: reason)
  }

  fileprivate func streamInactive(_ id: UUID) {
    guard callbacks?.id == id else { return }
    stop(reason: "Capture became inactive. Choose content to begin a new session.")
  }

  fileprivate func systemStopped(_ id: UUID, at notice: Double) async {
    guard let callbacks, callbacks.id == id else { return }
    if stoppingAt == nil { stoppingAt = notice }
    phase = .stopping
    await withCheckedContinuation { continuation in
      callbacks.queue.async { continuation.resume() }
    }
    finish(id, reason: "iOS ended sharing.")
  }

  func setBackgrounded(_ value: Bool) {
    callbacks?.readings.setBackgrounded(value)
    if value, scope == .app || phase == .choosing {
      stop(reason: "In-app preview or pending selection ended.")
    }
  }

  func refresh() {
    if let callbacks { snapshot = callbacks.readings.snapshot() }
  }

  func stop(reason: String = "Stopped.") {
    guard let callbacks, phase != .stopping else { return }
    let id = callbacks.id
    callbacks.readings.close()
    snapshot = callbacks.readings.snapshot()
    stoppingAt = ProcessInfo.processInfo.systemUptime
    phase = .stopping
    guard let stream else { finish(id, reason: reason); return }
    let start = opening
    Task {
      await start?.value
      guard self.callbacks?.id == id else { return }
      do {
        try await stream.stopCapture()
        await withCheckedContinuation { continuation in
          callbacks.queue.async { continuation.resume() }
        }
        if self.callbacks?.id == id { finish(id, reason: reason) }
      } catch {
        guard self.callbacks?.id == id else { return }
        phase = .uncertain
        message = "Signal intake is closed. Use Stop Sharing in iOS or retry Stop."
      }
    }
  }

  private func finish(_ id: UUID, reason: String) {
    guard let callbacks, callbacks.id == id else { return }
    callbacks.readings.close()
    snapshot = callbacks.readings.snapshot()
    picker.remove(callbacks)
    picker.isActive = false
    self.callbacks = nil
    stream = nil
    opening = nil
    let end = ProbeResources()
    let seconds = max(0.001, end.uptime - resources.uptime)
    let cpuPercent = (end.cpuSeconds - resources.cpuSeconds) * 100 / seconds
    let stop = stoppingAt.map { String(Int((end.uptime - $0) * 1000)) } ?? "system"
    let fields = "seen=\(snapshot.seen) reduced=\(snapshot.delivered) throttled=\(snapshot.throttled) unavailable=\(snapshot.unavailable) stale=\(snapshot.stale) maxReduceMs=\(snapshot.maxMillisecondsToReduce) stopMs=\(stop) elapsedS=\(Int(seconds)) avgCPUPercent=\(Int(cpuPercent)) processPeakBytes=\(end.processPeakBytes) thermal=\(ProcessInfo.processInfo.thermalState.rawValue) attempts=\(callbacks.readings.sink.attempts)"
    let background = "bgRed=\(snapshot.backgroundRed) bgBlue=\(snapshot.backgroundBlue) bgQuiet=\(snapshot.backgroundQuiet) bgTone=\(snapshot.backgroundTone)"
    result = fields + " " + background
    print("PROBE_ATTEMPT_AUDIT_END \(result)")
    stoppingAt = nil
    message = reason
    phase = .idle
  }
}
