import AVFoundation
import Foundation
import HueBoardKit
import HueBoardNativeCore
import XCTest
@testable import Hue_Board

@MainActor
final class StudioPreviewLifecycleTests: XCTestCase {
  private func waitUntil(
    _ condition: @MainActor () -> Bool,
    file: StaticString = #filePath, line: UInt = #line
  ) async {
    let deadline = ContinuousClock.now.advanced(by: .seconds(3))
    while !condition() && ContinuousClock.now < deadline {
      try? await Task.sleep(for: .milliseconds(1))
    }
    XCTAssertTrue(condition(), file: file, line: line)
  }

  func testStopDuringOpenDrainsAndCannotCloseNewOwner() async {
    let session = StudioInputPreviewSession()
    var permit: CheckedContinuation<Void, Never>?
    var reads = 0
    var closes = 0
    session.start(manualReadings: false, interval: .seconds(1)) {
      await withCheckedContinuation { permit = $0 }
    } sample: {
      reads += 1
      return HueLiveSignal(level: 0.5)
    } close: { closes += 1 }

    await waitUntil { permit != nil }
    let drain = session.stop()
    XCTAssertEqual(closes, 1)
    XCTAssertEqual(session.phase, .stopping)
    session.start(manualReadings: false, interval: .seconds(1)) {
      XCTFail("A draining input still owns its asynchronous work.")
    } sample: { HueLiveSignal(level: 0) } close: { XCTFail("A second input never opened.") }
    _ = session.stop()
    permit?.resume()
    await drain?.value
    XCTAssertTrue(session.isIdle)
    XCTAssertEqual(reads, 0)
    XCTAssertEqual(closes, 1)
    XCTAssertNil(session.signal)
  }

  func testLateReadingCannotSurviveStopOrRestart() async {
    let session = StudioInputPreviewSession()
    var read: CheckedContinuation<HueLiveSignal, Never>?
    session.start(manualReadings: false, interval: .seconds(1), open: {}) {
      await withCheckedContinuation { read = $0 }
    } close: {}

    await waitUntil { read != nil }
    let drain = session.stop()
    read?.resume(returning: HueLiveSignal(level: 1))
    await drain?.value
    XCTAssertNil(session.signal)
    session.start(manualReadings: false, interval: .seconds(10), open: {}) {
      HueLiveSignal(level: 0.1)
    } close: {}
    await waitUntil { session.signal?.level == 0.1 }
    await session.stop()?.value
    XCTAssertNil(session.signal)
  }

  func testManualReadingsChangeOnlyOnRefreshAndClearOnEnd() async {
    let session = StudioInputPreviewSession()
    var tick = 0
    var release: CheckedContinuation<Void, Never>?
    session.start(manualReadings: true, interval: .zero, open: {}) {
      tick += 1
      if tick == 1 { return HueLiveSignal(level: 0.1) }
      if tick == 2 { return HueLiveSignal(level: 0.9) }
      await withCheckedContinuation { release = $0 }
      throw CancellationError()
    } close: {}

    await waitUntil { release != nil }
    XCTAssertEqual(session.signal?.level, 0.1)
    session.refreshReading()
    XCTAssertEqual(session.signal?.level, 0.9)
    release?.resume()
    await waitUntil { session.isIdle }
    XCTAssertNil(session.signal)
    XCTAssertEqual(session.message, "Preview ended.")
  }

  func testFailedOpenReportsErrorWithoutSamplingOrLeavingResourceOpen() async {
    let session = StudioInputPreviewSession()
    var closes = 0
    session.start(manualReadings: false, interval: .seconds(1)) {
      throw HueBoardError.unsupported("Allow microphone access in Settings.")
    } sample: {
      XCTFail("Permission denial cannot start sampling.")
      return HueLiveSignal(level: 0)
    } close: { closes += 1 }
    await waitUntil { session.isIdle }
    XCTAssertEqual(session.message, "Allow microphone access in Settings.")
    XCTAssertNil(session.signal)
    XCTAssertEqual(closes, 1)
  }

  func testOfflineMissingFileLeavesWriterAndRestoreStateAlone() async {
    let model = AppModel()
    XCTAssertFalse(model.isReady)
    XCTAssertTrue(model.studioInputPreview.isIdle)
    XCTAssertFalse(model.canPreviewStudioInput)
    model.studioLiveInput = .media
    XCTAssertFalse(model.canPreviewStudioInput)
    model.studioMediaURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("absent-\(UUID().uuidString).mp4")
    XCTAssertTrue(model.canPreviewStudioInput)
    model.previewStudioInput(manualReadings: false)
    await waitUntil { model.studioInputPreview.isIdle }
    XCTAssertNotNil(model.studioInputPreview.message)
    XCTAssertNil(model.studioMedia.player)
    XCTAssertFalse(model.studioMicrophone.isCapturing)
    XCTAssertFalse(model.hasRestorePoint)
    let lease = await model.playbackCoordinator.currentLease()
    XCTAssertNil(lease)
    XCTAssertNil(model.liveStartupID)
    XCTAssertNil(model.studioCaptureSessionID)
  }

  func testOfflineLocalPlaybackAndBackgroundCleanupThroughAppModel() async throws {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("synthetic-silence-\(UUID().uuidString).caf")
    defer { try? FileManager.default.removeItem(at: url) }
    let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 8_000, channels: 1))
    let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 32_000))
    buffer.frameLength = buffer.frameCapacity
    let samples = try XCTUnwrap(buffer.floatChannelData?[0])
    for index in 0..<Int(buffer.frameLength) { samples[index] = 0 }
    do {
      let file = try AVAudioFile(forWriting: url, settings: format.settings)
      try file.write(from: buffer)
    }

    let model = AppModel()
    model.selectedTab = .live
    model.studioLiveInput = .media
    model.studioMediaURL = url
    XCTAssertNil(model.studioMedia.player)
    model.previewStudioInput(manualReadings: true)
    await waitUntil {
      model.studioInputPreview.signal?.level == 0 &&
        (model.studioMedia.player?.currentTime().seconds ?? 0) > 0
    }
    XCTAssertNil(model.studioInputPreview.signal?.color)
    XCTAssertFalse(model.studioMicrophone.isCapturing)
    XCTAssertFalse(model.hasRestorePoint)
    let lease = await model.playbackCoordinator.currentLease()
    XCTAssertNil(lease)
    model.setStudioSceneBackgrounded(true)
    await waitUntil { model.studioInputPreview.isIdle }
    XCTAssertNil(model.studioMedia.player)
    XCTAssertNil(model.studioInputPreview.signal)
    model.setStudioSceneBackgrounded(false)
    XCTAssertTrue(model.studioInputPreview.isIdle)
    XCTAssertNil(model.studioMedia.player)
  }
}
