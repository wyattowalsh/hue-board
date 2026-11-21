import AVFAudio
import Foundation
import SwiftUI

@main
struct ScreenInputProbeApp: App {
  @State private var capture = ProbeCapture()

  var body: some Scene {
    WindowGroup { ProbeView(capture: capture) }
  }
}

private struct ProbeView: View {
  @Bindable var capture: ProbeCapture
  @Environment(\.scenePhase) private var scenePhase
  @State private var blue = false
  @State private var tone: AVAudioPlayer?
  @State private var toneIssue: String?

  var body: some View {
    NavigationStack {
      Form {
        Section {
          Picker("System picker scope", selection: $capture.scope) {
            ForEach(ProbeScope.allCases, id: \.self) { Text($0.rawValue).tag($0) }
          }
          Picker("Measure", selection: $capture.source) {
            ForEach(ProbeSource.allCases, id: \.self) { Text($0.rawValue).tag($0) }
          }
        }.disabled(capture.phase != .idle)
        Section {
          if capture.phase == .idle {
            Button("Choose content", systemImage: "rectangle.dashed") { capture.choose() }
          } else {
            Button("Stop", systemImage: "stop.circle") {
              tone?.stop()
              capture.stop()
            }.disabled(capture.phase == .stopping)
          }
          LabeledContent("Capture", value: capture.phase.rawValue)
          LabeledContent("Latest reading", value: reading)
          if !capture.message.isEmpty { Text(capture.message) }
        }

        Section("Synthetic reference") {
          if capture.source == .color {
            Rectangle().fill(blue ? Color.blue : .red).frame(height: 180)
              .accessibilityLabel(blue ? "Blue reference" : "Red reference")
            Button(blue ? "Show red reference" : "Show blue reference") { blue.toggle() }
          } else {
            Button("Play two-second test tone", systemImage: "speaker.wave.1") {
              do {
                let player = try AVAudioPlayer(data: Self.referenceTone)
                player.prepareToPlay()
                tone?.stop()
                tone = player
                toneIssue = player.play() ? nil : "Playback is unavailable."
              } catch { toneIssue = "Playback is unavailable." }
            }
            if let toneIssue { Text(toneIssue) }
          }
        }

        if !capture.result.isEmpty {
          Section("Last run · aggregate counters") {
            Text(capture.result).font(.footnote.monospacedDigit()).textSelection(.enabled)
          }
        }
      }
      .navigationTitle("Screen input probe")
      .task {
        while !Task.isCancelled {
          capture.refresh()
          do { try await Task.sleep(for: .milliseconds(250)) } catch { break }
        }
      }
      .onChange(of: scenePhase) { _, phase in
        if phase == .background { tone?.stop(); capture.setBackgrounded(true) }
        if phase == .active { capture.setBackgrounded(false) }
      }
      .onChange(of: capture.phase) { _, phase in
        if phase == .idle || phase == .stopping { tone?.stop() }
      }
    }
  }

  private var reading: String {
    switch capture.snapshot.value {
    case .tint(let r, let g, let b): String(format: "#%02X%02X%02X", r, g, b)
    case .level(let level): String(format: "%.3f RMS", level)
    case nil: "Unavailable"
    }
  }

  // A low-amplitude, ramped 440 Hz sine generated in memory on first explicit use.
  private static let referenceTone: Data = {
    let rate = 16_000
    let samples = 2 * rate
    var bytes = Data()
    func text(_ value: String) { bytes.append(contentsOf: value.utf8) }
    func integer<T: FixedWidthInteger>(_ value: T) {
      withUnsafeBytes(of: value.littleEndian) { bytes.append(contentsOf: $0) }
    }
    text("RIFF"); integer(UInt32(36 + samples * 2)); text("WAVEfmt ")
    integer(UInt32(16)); integer(UInt16(1)); integer(UInt16(1)); integer(UInt32(rate))
    integer(UInt32(rate * 2)); integer(UInt16(2)); integer(UInt16(16))
    text("data"); integer(UInt32(samples * 2))
    for index in 0..<samples {
      let ramp = min(1, Double(min(index, samples - index - 1)) / 320)
      integer(Int16(1500 * ramp * sin(2 * .pi * 440 * Double(index) / Double(rate))))
    }
    return bytes
  }()
}
