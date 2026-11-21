import Foundation
import HueBoardKit
import HueBoardNativeCore

@MainActor
extension AppModel {
  var canPreviewStudioInput: Bool {
    guard selectedTab == .live, !isSettingsPresented, !isConnectionSheetPresented,
          !studioSceneIsBackgrounded, !isBusy, !isLiveRunning, liveStartupID == nil,
          studioCaptureSessionID == nil, studioInputPreview.isIdle else { return false }
    switch studioLiveInput {
    case .engine: return false
    case .microphone: return true
    case .media: return studioMediaURL != nil
    }
  }

  func previewStudioInput(manualReadings: Bool) {
    guard canPreviewStudioInput else { return }
    let preview = studioInputPreview
    switch studioLiveInput {
    case .engine:
      return
    case .microphone:
      let microphone = studioMicrophone
      preview.start(manualReadings: manualReadings, interval: .milliseconds(200)) {
        try await microphone.start()
      } sample: {
        guard microphone.isCapturing else { throw CancellationError() }
        return microphone.signal()
      } close: {
        microphone.stop()
      }
    case .media:
      guard let url = studioMediaURL else { return }
      let media = studioMedia
      // Each read decodes a bounded audio window and, for video, one small frame.
      // Await it before scheduling the next reading, even for slow file providers.
      preview.start(manualReadings: manualReadings, interval: .milliseconds(600)) {
        _ = try await media.start(url: url)
        try Task.checkCancellation()
        media.play()
      } sample: {
        try await media.signal()
      } close: {
        media.stop()
      }
    }
  }
}
