import SwiftUI
import HueBoardKit
import HueBoardNativeCore

struct StudioRehearsalView: View {
  @Environment(AppModel.self) private var model
  @Environment(\.scenePhase) private var scenePhase
  @State private var visible = false
  @State private var elapsed: Double = 0
  @State private var presentation = StudioRehearsalPresentation()
  @Environment(\.dynamicTypeSize) private var typeSize

  var body: some View {
    let room = model.studioRehearsalRoom
    let request = visible && scenePhase == .active && model.selectedTab == .live ? room.map { model.studioRehearsalRequest(in: $0, at: elapsed) } : nil
    let matchingComposition = request.map { presentation.renderedRequest?.hasSameComposition(as: $0) == true } ?? false
    let visibleFrame = matchingComposition ? presentation.frame : nil
    VStack(alignment: .leading, spacing: 12) {
      ViewThatFits(in: .horizontal) {
        HStack {
          previewTitle
          Spacer()
          Text(room?.area.name ?? "").foregroundStyle(.secondary)
        }
        VStack(alignment: .leading) {
          previewTitle
          Text(room?.area.name ?? "").foregroundStyle(.secondary)
        }
      }
      if let room {
        if let issue = presentation.issue, presentation.renderedRequest == request {
          Text(issue).font(.footnote).foregroundStyle(.secondary)
        } else {
          roomMap(room, frame: visibleFrame)
          if let visibleFrame {
            if visibleFrame.ended {
              Text("End of session")
            } else if visibleFrame.targets.isEmpty {
              Text("No selected color lights can play at this brightness.")
            } else if let cue = visibleFrame.cue {
              let name = model.contract.preset(id: cue.presetID)?.name ?? cue.presetID
              Text("Cue \(cue.position + 1) of \(cue.count) · \(name)")
            }
          }
          if model.liveDuration.isFinite, (0...86_400).contains(model.liveDuration), model.liveDuration > 0 {
            timeline
          }
          if !room.area.lights.isEmpty {
            let placements = Dictionary(grouping: room.layout.placements, by: \.id)
            DisclosureGroup("Light details") {
              VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(room.area.lights.enumerated()), id: \.element.id) { index, light in
                  let target = visibleFrame?.targets[light.id]
                  let rowLayout = typeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
                    : AnyLayout(HStackLayout(alignment: .firstTextBaseline))
                  rowLayout {
                    VStack(alignment: .leading, spacing: 2) {
                      Text("\(index + 1). \(light.name)").fixedSize(horizontal: false, vertical: true)
                      if let placement = placements[light.id]?.first {
                        Text("X \(Int((placement.x * 100).rounded()))%, Y \(Int((placement.y * 100).rounded()))%")
                          .font(.caption).foregroundStyle(.secondary)
                      }
                    }
                    if !typeSize.isAccessibilitySize { Spacer() }
                    if let target {
                      Text("\(target.brightness.formatted(.number.precision(.fractionLength(0...1))))% · \(rgbHex(target.color))")
                        .monospacedDigit()
                    } else if visibleFrame?.ended == true {
                      Text("Ended")
                    } else if visibleFrame == nil {
                      Text("Pending")
                    } else {
                      Text("Excluded")
                    }
                  }
                  .accessibilityElement(children: .combine)
                }
              }
              .padding(.top, 6)
            }
            .accessibilityIdentifier("studio-rehearsal-fixtures")
          }
        }
      } else {
        Text(model.roomLayoutIssue ?? "Choose a room with a saved layout to preview its lights.")
      }
    }
    .onAppear { visible = true }
    .onChange(of: request, initial: true) { _, next in
      presentation.update(next) { try await model.studioRehearsalFrame($0) }
    }
    .onDisappear {
      visible = false
      presentation.clear()
    }
    .onChange(of: model.liveDuration) { _, duration in
      elapsed = duration.isFinite && duration > 0 ? min(elapsed, duration) : 0
    }
  }

  private var previewTitle: some View {
    Text("Preview")
      .font(.headline)
      .accessibilityAddTraits(.isHeader)
      .accessibilityIdentifier("studio-preview-title")
  }

  private var timeline: some View {
    let duration = model.liveDuration
    let step = model.isCueSequenceEnabled ? max(1, model.cueHoldSeconds) : 5
    return VStack(spacing: 0) {
      Slider(value: $elapsed, in: 0...max(1, duration), step: 1)
        .accessibilityLabel("Preview time")
        .accessibilityValue("\(Int(elapsed)) seconds")
        .accessibilityIdentifier("studio-rehearsal-time")
      HStack {
        Button {
          elapsed = max(0, model.isCueSequenceEnabled ? (ceil(elapsed / step) - 1) * step : elapsed - step)
        } label: {
          Image(systemName: model.isCueSequenceEnabled ? "backward.end.fill" : "gobackward.5")
            .frame(width: 44, height: 44)
        }
        .accessibilityLabel(model.isCueSequenceEnabled ? "Previous cue" : "Back 5 seconds")
        .disabled(elapsed <= 0)
        .accessibilityIdentifier("studio-rehearsal-previous")
        Spacer()
        Text("\(Duration.seconds(elapsed).formatted(.time(pattern: .minuteSecond))) / \(Duration.seconds(duration).formatted(.time(pattern: .minuteSecond)))")
          .font(.caption.monospacedDigit())
          .foregroundStyle(.secondary)
          .accessibilityHidden(true)
        Spacer()
        Button {
          elapsed = min(duration, model.isCueSequenceEnabled ? (floor(elapsed / step) + 1) * step : elapsed + step)
        } label: {
          Image(systemName: model.isCueSequenceEnabled ? "forward.end.fill" : "goforward.5")
            .frame(width: 44, height: 44)
        }
        .accessibilityLabel(model.isCueSequenceEnabled ? "Next cue" : "Forward 5 seconds")
        .disabled(elapsed >= duration)
        .accessibilityIdentifier("studio-rehearsal-next")
      }
      .buttonStyle(.borderless)
    }
  }

  private func rgbHex(_ color: RGB) -> String {
    let channels = color.components.map { Int((min(1, max(0, $0)) * 255).rounded()) }
    return String(format: "#%02X%02X%02X", channels[0], channels[1], channels[2])
  }

  private func roomMap(_ room: StudioRehearsalRoom, frame: StudioPlannedFrame?) -> some View {
    let placements = Dictionary(grouping: room.layout.placements, by: \.id)
    return GeometryReader { proxy in
      ZStack(alignment: .topLeading) {
        RoundedRectangle(cornerRadius: 12).fill(.black.opacity(0.85))
        ForEach(Array(room.area.lights.enumerated()), id: \.element.id) { index, light in
          if let placement = placements[light.id]?.first {
            let target = frame?.targets[light.id]
            let color = target.map { Color(red: $0.color.red, green: $0.color.green, blue: $0.color.blue) }
            ZStack {
              Circle().fill(color?.opacity(0.25 + 0.75 * (target?.brightness ?? 0) / 100) ?? Color.clear)
              Circle().strokeBorder(.white.opacity(target == nil ? 0.35 : 0.8), lineWidth: 1.5)
              Text("\(index + 1)").font(.caption2.bold()).foregroundStyle(.white)
                .padding(.horizontal, 2).background(.black.opacity(0.7), in: Capsule())
            }
            .frame(width: 26, height: 26)
            .position(x: 13 + placement.x * max(0, proxy.size.width - 26),
                      y: 13 + placement.y * max(0, proxy.size.height - 26))
          }
        }
      }
    }
    .frame(height: 110)
    .accessibilityHidden(true)
  }
}
