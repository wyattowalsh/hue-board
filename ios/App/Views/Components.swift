import SwiftUI
import HueBoardKit

struct ConnectPrompt: View {
  @Environment(AppModel.self) private var model
  var body: some View {
    ContentUnavailableView {
      Label("No Bridge connected", systemImage: "lightbulb.2")
    } description: {
      Text("Connect your Hue Bridge to control lights and arrange your room.")
    } actions: {
      Button("Connect Bridge") { model.presentConnection() }.buttonStyle(.borderedProminent)
    }
  }
}

struct AreaPicker: View {
  @Environment(AppModel.self) private var model
  var body: some View {
    Picker("Room or zone",selection: Binding(get:{model.selectedAreaID},set:{id in if let id{Task{await model.selectArea(id)}}})){
      ForEach(model.areas){area in Text(area.name).tag(Optional(area.id))}
    }
    .disabled(!model.canSwitchArea)
  }
}

struct PlaybackBanner: View {
  @Environment(AppModel.self) private var model
  var body: some View {
    if model.playbackSnapshot.mode != .idle || model.hasRestorePoint || model.foreignRecoveryPending {
      VStack(alignment:.leading,spacing:8){
        VStack(alignment:.leading,spacing:2){
          Text(title).font(.headline)
          if model.foreignRecoveryPending {
            Text("Connect the original Bridge in Settings to restore its lights.")
              .font(.caption)
          } else if model.playbackSnapshot.mode != .idle {
            Text(model.playbackSnapshot.message)
              .font(.caption)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
        .accessibilityElement(children:.combine)
        if showsRestore && !model.isReady {
          Text("Reconnect the saved Bridge to restore the baseline.")
            .font(.caption)
            .foregroundStyle(.secondary)
          Button("Reconnect Bridge") { model.presentConnection() }
            .buttonStyle(.bordered)
            .disabled(model.isBusy)
        }
        ViewThatFits(in: .horizontal) {
          HStack {
            actions
          }
          VStack(alignment: .leading, spacing: 8) {
            actions
          }
        }
        if model.playbackSnapshot.phase == .running && model.playbackSnapshot.progress > 0 {
          ProgressView(value:model.playbackSnapshot.progress)
        }
      }
      .padding(12)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(.ultraThinMaterial)
    }
  }

  private var showsRestore: Bool {
    !model.foreignRecoveryPending
      && (model.hasRestorePoint || model.playbackSnapshot.phase == .running || model.requiresRecovery)
  }

  @ViewBuilder private var actions: some View {
    if model.foreignRecoveryPending {
      Button("Bridge settings") { model.presentConnection() }
    }
    if showsRestore {
      Button(model.playbackSnapshot.mode == .idle || model.playbackSnapshot.mode == .failed
             ? "Restore lights" : "Stop & restore") { Task { await model.stopAndRestore() } }
        .buttonStyle(.borderedProminent)
        .disabled(!model.canStopAndRestore)
        .accessibilityIdentifier("restore-lights")
    }
    if !model.foreignRecoveryPending {
      Button("Turn off now", role: .destructive) { Task { await model.turnOffNow() } }
        .buttonStyle(.bordered)
        .disabled(!model.canTurnOffNow)
        .accessibilityHint("Stops playback and turns eligible lights off. Their previous settings stay available to restore.")
    }
  }

  private var title: String {
    if model.foreignRecoveryPending { return "Another Bridge needs restoration" }
    return switch model.playbackSnapshot.mode {
    case .bridge: "Scene playback"
    case .liveForeground, .liveContinued: "Studio playback"
    case .stopping: "Restoring lights"
    case .idle: "Previous light settings saved"
    case .failed: "Check your lights"
    }
  }
}

struct LightRow: View {
  let light:HueLight
  var body:some View{
    HStack(spacing:12){
      Circle().fill(swiftUIColor(light.color)).frame(width:30,height:30)
        .overlay(Circle().stroke(.primary.opacity(0.15)))
      Text(light.name)
      Spacer()
      if light.capabilities.streaming { Label("Streaming",systemImage:"waveform").font(.caption).foregroundStyle(.orange) }
      else { Text(light.isOn ? (light.brightness.map { "\(Int($0))%" } ?? "On") : "Off").font(.callout.monospacedDigit()) }
    }
    .accessibilityElement(children:.combine)
  }
}

func swiftUIColor(_ xy:HueXY?)->Color{
  guard let xy else{return Color.secondary.opacity(0.35)}
  let x=min(max(xy.x,0),1),y=min(max(xy.y,0.0001),1),z=max(0,1-x-y)
  let Y=1.0,X=Y/y*x,Z=Y/y*z
  func gamma(_ v:Double)->Double{let v=max(0,v);return v<=0.0031308 ? 12.92*v : 1.055*pow(v,1/2.4)-0.055}
  return Color(red:min(1,gamma(1.656492*X-0.354851*Y-0.255038*Z)),green:min(1,gamma(-0.707196*X+1.655397*Y+0.036152*Z)),blue:min(1,gamma(0.051713*X-0.121364*Y+1.011530*Z)))
}

struct ScenePreview: View {
    @Environment(AppModel.self) private var model
    @State private var sampledFrames: [HueLightFrame] = []

    let preset: HuePreset
    let contract: HueBoardContract
    var compact = false

    private var fallbackColors: [RGB] {
        (try? contract.palette(index: preset.palette)?.decodedColors()) ?? []
    }

    private var previewID: String {
        "\(preset.id):\(Int(model.effectiveDynamicBrightness)):\(model.safetySettings.reduceLightMotion)"
    }

    var body: some View {
        Group {
            if compact {
                let colors = sampledFrames.isEmpty
                    ? fallbackColors.map { displayColor($0) }
                    : sampledFrames.map { displayColor($0.color) }
                LinearGradient(colors: colors.isEmpty ? [.secondary] : colors,
                               startPoint: .bottomLeading, endPoint: .topTrailing)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                HStack(alignment: .bottom, spacing: 4) {
                    if sampledFrames.isEmpty {
                        ForEach(Array(fallbackColors.enumerated()), id: \.offset) { _, color in
                            RoundedRectangle(cornerRadius: 5)
                                .fill(displayColor(color))
                                .frame(maxWidth: .infinity)
                                .frame(height: 58)
                        }
                    } else {
                        ForEach(Array(sampledFrames.enumerated()), id: \.offset) { _, frame in
                            RoundedRectangle(cornerRadius: 5)
                                .fill(displayColor(frame.color))
                                .frame(maxWidth: .infinity)
                                .frame(height: max(12, min(67, frame.brightness)))
                        }
                    }
                }
                .padding(10)
                .frame(height: 85, alignment: .bottom)
                .frame(maxWidth: .infinity)
                .background(Color(red: 0.08, green: 0.09, blue: 0.15),
                            in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Color preview for \(preset.name)")
        .task(id: previewID) {
            sampledFrames = []
            let settings = PhysicalLightSafetyPolicy.adjustedEngineSettings(
                HueEngineSettings.from(
                    preset: preset,
                    brightness: model.effectiveDynamicBrightness
                ),
                safety: model.safetySettings
            )
            var samples: [HueLightFrame] = []
            for index in 0..<8 {
                if Task.isCancelled { return }
                do {
                    samples.append(try await model.engine.sample(
                        time: 19,
                        position: Double(index) / 8,
                        settings: settings,
                        surge: 0
                    ))
                } catch {
                    return
                }
            }
            if !Task.isCancelled { sampledFrames = samples }
        }
    }

    private func displayColor(_ color: RGB) -> Color {
        Color(red: min(max(color.red, 0), 1),
              green: min(max(color.green, 0), 1),
              blue: min(max(color.blue, 0), 1))
    }
}
