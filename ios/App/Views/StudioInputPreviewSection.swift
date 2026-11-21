import AVKit
import HueBoardKit
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct StudioInputPreviewSection: View {
  @Environment(AppModel.self) private var model
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var choosingFile = false

  private var limitsLightMotion: Bool { model.safetySettings.reduceLightMotion || model.systemLightMotion.isEnabled }
  private var manualReadings: Bool { reduceMotion || limitsLightMotion }
  private var selectionLocked: Bool { model.isBusy || model.isLiveRunning }

  var body: some View {
    let preview = model.studioInputPreview
    VStack(alignment: .leading, spacing: 10) {
      Picker("Input", selection: Binding(
        get: { model.studioLiveInput },
        set: { input in
          guard model.studioLiveInput != input else { return }
          preview.stop()
          model.studioLiveInput = input
        }
      )) {
        Text("Patterns").tag(AppModel.StudioLiveInput.engine)
        Text("Microphone").tag(AppModel.StudioLiveInput.microphone)
        Text("Audio or video file").tag(AppModel.StudioLiveInput.media)
      }
      .pickerStyle(.menu)
      .accessibilityIdentifier("studio-live-input")
      .disabled(selectionLocked)

      if model.studioLiveInput == .media {
        Button("Choose audio or video", systemImage: "folder") {
          preview.stop()
          choosingFile = true
        }
        .accessibilityIdentifier("studio-choose-media")
        .disabled(selectionLocked)

        if let url = model.studioMediaURL {
          Label(url.lastPathComponent, systemImage: "doc")
            .font(.subheadline)
            .fixedSize(horizontal: false, vertical: true)
        }
      }

      if model.studioLiveInput != .engine {
        Text(model.studioLiveInput == .microphone
          ? "Preview uses this iPhone’s microphone. Audio stays in memory."
          : "Preview plays the file on this iPhone. Sound changes brightness and video supplies color.")
          .font(.caption)
          .foregroundStyle(.secondary)
        Button {
          if preview.canStop { preview.stop() }
          else { model.previewStudioInput(manualReadings: manualReadings) }
        } label: {
          if preview.canStop {
            Label("Stop preview", systemImage: "stop.circle")
          } else if preview.phase == .stopping {
            Label("Stopping preview…", systemImage: "stop.circle")
          } else {
            Label("Preview input", systemImage: "waveform")
          }
        }
        .buttonStyle(.bordered)
        .accessibilityIdentifier("studio-input-preview")
        .disabled(!preview.canStop && !model.canPreviewStudioInput)

        if preview.phase == .opening {
          Text("Opening input…").font(.caption)
        }
        if let reading = preview.signal {
          let percent = Int((reading.level * 100).rounded())
          VStack(alignment: .leading, spacing: 4) {
            Text("Input level \(percent)%")
              .font(.subheadline.monospacedDigit())
            ProgressView(value: reading.level)
              .accessibilityHidden(true)
          }
          .accessibilityElement(children: .combine)
          .accessibilityIdentifier("studio-input-level")
          if let color = reading.color { tint(color) }
          if preview.manualReadings {
            Button("Refresh reading", systemImage: "arrow.clockwise") { preview.refreshReading() }
              .accessibilityHint("Updates the input level and sampled color once.")
          }
        } else if let message = preview.message {
          Text(message).font(.subheadline).fixedSize(horizontal: false, vertical: true)
        }

        if model.studioLiveInput == .media, model.studioMedia.hasVideo,
           model.isLiveRunning, let player = model.studioMedia.player {
          VideoPlayer(player: player)
            .frame(height: 180)
            .clipShape(.rect(cornerRadius: 12))
            .allowsHitTesting(false)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Selected video playback")
        }
        Text(limitsLightMotion
          ? "Choose Patterns for playback while light motion is reduced."
          : "Keep Hue Board open while playing this input on lights.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .onChange(of: manualReadings) { _, value in preview.setManualReadings(value) }
    .fileImporter(isPresented: $choosingFile, allowedContentTypes: [.audio, .movie, .video]) { result in
      switch result {
      case .success(let url): model.studioMediaURL = url
      case .failure(let error):
        if (error as? CocoaError)?.code != .userCancelled {
          model.errorMessage = "Could not select media. \(error.localizedDescription)"
        }
      }
    }
  }

  private func tint(_ rgb: RGB) -> some View {
    let color = Color(.sRGB, red: rgb.red, green: rgb.green, blue: rgb.blue)
    let components = [rgb.red, rgb.green, rgb.blue].map { Int(($0 * 255).rounded()) }
    let hex = String(format: "#%02X%02X%02X", components[0], components[1], components[2])
    return Label {
      Text("Sampled color · \(Self.colorName(rgb))").font(.subheadline)
    } icon: {
      Circle().fill(color).overlay(Circle().strokeBorder(.secondary)).frame(width: 20, height: 20)
    }
    .accessibilityValue(hex)
    .accessibilityIdentifier("studio-input-tint")
  }

  private static func colorName(_ rgb: RGB) -> String {
    let uiColor = UIColor(red: rgb.red, green: rgb.green, blue: rgb.blue, alpha: 1)
    var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0
    uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: nil)
    if brightness < 0.10 { return "Black" }
    if saturation < 0.12 { return brightness > 0.9 ? "White" : "Gray" }
    switch hue * 360 {
    case 15..<45: return "Orange"
    case 45..<75: return "Yellow"
    case 75..<165: return "Green"
    case 165..<195: return "Cyan"
    case 195..<260: return "Blue"
    case 260..<295: return "Purple"
    case 295..<345: return "Pink"
    default: return "Red"
    }
  }
}
