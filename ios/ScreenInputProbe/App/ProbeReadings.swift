import AudioToolbox
import CoreImage
import CoreMedia
import Darwin
import Foundation
import os
@preconcurrency import ScreenCaptureKit

enum ProbeSource: String, CaseIterable { case color = "Screen color", audio = "App audio" }
enum ProbeScope: String, CaseIterable { case app = "This app", display = "Full display" }

enum ProbeMeasurement: Equatable, Sendable {
  case tint(UInt8, UInt8, UInt8)
  case level(Double)
}

struct ProbeSnapshot: Sendable {
  var value: ProbeMeasurement?
  var seen = 0
  var throttled = 0
  var unavailable = 0
  var stale = 0
  var delivered = 0
  var maxMillisecondsToReduce = 0
  var backgroundRed = 0
  var backgroundBlue = 0
  var backgroundQuiet = 0
  var backgroundTone = 0
}

/// A positive control can exercise the same attempt hook, in a fresh sink, without any I/O.
final class ProbeNullSink: Sendable {
  private let count = OSAllocatedUnfairLock(initialState: 0)
  var attempts: Int { count.withLock { $0 } }
  func attempt() { count.withLock { $0 += 1 } }

  static func calibrate() -> Bool {
    let control = ProbeNullSink()
    let observedZero = control.attempts == 0
    control.attempt()
    return observedZero && control.attempts == 1
  }
}

struct ProbeResources {
  let uptime = ProcessInfo.processInfo.systemUptime
  let cpuSeconds: Double
  let processPeakBytes: Int

  init() {
    var usage = rusage()
    if getrusage(RUSAGE_SELF, &usage) == 0 {
      cpuSeconds = Double(usage.ru_utime.tv_sec + usage.ru_stime.tv_sec)
        + (Double(usage.ru_utime.tv_usec) + Double(usage.ru_stime.tv_usec)) / 1_000_000
      processPeakBytes = Int(usage.ru_maxrss)
    } else {
      cpuSeconds = 0
      processPeakBytes = 0
    }
  }
}

/// The serial output queue reduces buffers synchronously. Only the latest scalar or RGB is retained.
final class ProbeReadings: @unchecked Sendable {
  private struct State: Sendable {
    var open = true
    var nextRead = 0.0
    var measuredAt = 0.0
    var backgroundSince: Double?
    var snapshot = ProbeSnapshot()
  }

  private let state = OSAllocatedUnfairLock(initialState: State())
  private let context = CIContext(options: [.cacheIntermediates: false])
  let sink = ProbeNullSink()

  /// Also checked after expensive decoding in case the system or user stopped the stream.
  func consume(_ buffer: CMSampleBuffer, type: SCStreamOutputType) {
    let started = ProcessInfo.processInfo.systemUptime
    let eligible = state.withLock { state -> Bool in
      guard state.open else { return false }
      state.snapshot.seen += 1
      guard started >= state.nextRead else {
        state.snapshot.throttled += 1
        return false
      }
      state.nextRead = started + 0.25
      return true
    }
    guard eligible else { return }
    let age = CMTimeGetSeconds(CMTimeSubtract(CMClockGetTime(CMClockGetHostTimeClock()),
                                             CMSampleBufferGetPresentationTimeStamp(buffer)))
    let value: ProbeMeasurement?
    if age.isFinite, (-0.1..<2).contains(age) {
      switch type {
      case .screen: value = color(in: buffer)
      case .audio: value = Self.level(in: buffer)
      default: value = nil
      }
    } else {
      value = nil
    }
    let finished = ProcessInfo.processInfo.systemUptime
    state.withLock { state in
      guard state.open else { return }
      state.snapshot.maxMillisecondsToReduce = max(
        state.snapshot.maxMillisecondsToReduce, Int((finished - started) * 1000)
      )
      guard let value, finished - started + max(0, age) < 2 else {
        state.snapshot.unavailable += 1
        state.snapshot.value = nil
        return
      }
      state.measuredAt = started - max(0, age)
      state.snapshot.value = value
      state.snapshot.delivered += 1
      // Count only samples whose presentation began after the host backgrounded.
      // These four bounded aggregate counts survive the return to the probe UI.
      if let since = state.backgroundSince, state.measuredAt >= since {
        switch value {
        case .tint(let r, let g, let b):
          if Int(r) - max(Int(g), Int(b)) > 20 { state.snapshot.backgroundRed += 1 }
          if Int(b) - max(Int(r), Int(g)) > 20 { state.snapshot.backgroundBlue += 1 }
        case .level(let rms):
          if rms < 0.002 { state.snapshot.backgroundQuiet += 1 }
          if rms > 0.015 { state.snapshot.backgroundTone += 1 }
        }
      }
    }
  }

  func setBackgrounded(_ value: Bool) {
    state.withLock { $0.backgroundSince = value ? ProcessInfo.processInfo.systemUptime : nil }
  }

  func close() {
    state.withLock { state in
      state.open = false
      state.snapshot.value = nil
    }
  }

  func snapshot() -> ProbeSnapshot {
    let now = ProcessInfo.processInfo.systemUptime
    return state.withLock { state in
      if state.snapshot.value != nil, now - state.measuredAt >= 2 {
        state.snapshot.value = nil
        state.snapshot.stale += 1
      }
      return state.snapshot
    }
  }

  private func color(in buffer: CMSampleBuffer) -> ProbeMeasurement? {
    guard CMSampleBufferIsValid(buffer), CMSampleBufferDataIsReady(buffer),
          let imageBuffer = CMSampleBufferGetImageBuffer(buffer),
          let attachments = CMSampleBufferGetSampleAttachmentsArray(buffer, createIfNecessary: false)
            as? [[SCStreamFrameInfo: Any]],
          let rawStatus = attachments.first?[.status] as? NSNumber,
          SCFrameStatus(rawValue: rawStatus.intValue) == .complete else { return nil }
    let image = CIImage(cvPixelBuffer: imageBuffer)
    guard !image.extent.isEmpty, !image.extent.isInfinite else { return nil }
    let average = image.applyingFilter("CIAreaAverage", parameters: [
      kCIInputExtentKey: CIVector(cgRect: image.extent)
    ])
    var pixel = [UInt8](repeating: 0, count: 4)
    let rendered = pixel.withUnsafeMutableBytes { bytes -> Bool in
      guard let base = bytes.baseAddress else { return false }
      context.render(average, toBitmap: base, rowBytes: 4,
                     bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                     format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB))
      return true
    }
    return rendered ? .tint(pixel[0], pixel[1], pixel[2]) : nil
  }

  private static func level(in buffer: CMSampleBuffer) -> ProbeMeasurement? {
    guard CMSampleBufferIsValid(buffer), CMSampleBufferDataIsReady(buffer),
          let description = CMSampleBufferGetFormatDescription(buffer),
          let format = CMAudioFormatDescriptionGetStreamBasicDescription(description)?.pointee,
          format.mFormatID == kAudioFormatLinearPCM,
          format.mFormatFlags & kAudioFormatFlagIsBigEndian == 0 else { return nil }
    let float = format.mFormatFlags & kAudioFormatFlagIsFloat != 0 && format.mBitsPerChannel == 32
    let int16 = format.mFormatFlags & kAudioFormatFlagIsSignedInteger != 0 && format.mBitsPerChannel == 16
    guard float || int16 else { return nil }
    let stride = float ? 4 : 2
    return try? buffer.withAudioBufferList { buffers, _ -> ProbeMeasurement? in
      guard let first = buffers.first, let base = first.mData else { return nil }
      let raw = UnsafeRawBufferPointer(start: base, count: Int(first.mDataByteSize))
      let count = min(1024, raw.count / stride)
      guard count > 0 else { return nil }
      var energy = 0.0
      for index in 0..<count {
        let sample = float
          ? Double(raw.loadUnaligned(fromByteOffset: index * stride, as: Float.self))
          : Double(raw.loadUnaligned(fromByteOffset: index * stride, as: Int16.self)) / 32_768
        guard sample.isFinite else { return nil }
        energy += sample * sample
      }
      return .level(min(1, sqrt(energy / Double(count))))
    }
  }
}
