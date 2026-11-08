import HueBoardKit
import SwiftUI

struct LightsView: View {
  @Environment(AppModel.self) private var model
  @State private var draftBrightness = 60.0

  var body: some View {
    Group {
      if model.isReady {
        List {
          Section {
            Picker("Area", selection: areaSelection) {
              ForEach(model.areas) { area in
                Text("\(area.name) · \(area.lights.count)")
                  .tag(area.id)
              }
            }
            .disabled(!model.canSwitchArea)
          }

          Section("Everyday control") {
            HStack(spacing: 12) {
              Button {
                Task { await model.setAreaPower(true) }
              } label: {
                Label("Turn on", systemImage: "power")
                  .frame(maxWidth: .infinity)
              }
              .buttonStyle(.borderedProminent)
              .disabled(!model.canUseEverydayControls)

              Button {
                Task { await model.turnOffNow() }
              } label: {
                Label("Turn off now", systemImage: "power")
                  .frame(maxWidth: .infinity)
              }
              .buttonStyle(.bordered)
              .disabled(!model.canTurnOffNow)
            }

            Text(
              "During playback, Turn off now cancels Native Live and turns off only lights covered by the saved baseline, so restoration remains complete. Otherwise it turns off the current area."
            )
            .font(.caption)
            .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 10) {
              HStack {
                Label("Brightness", systemImage: "sun.max.fill")
                Spacer()
                Text("\(Int(draftBrightness))%")
                  .monospacedDigit()
                  .foregroundStyle(.secondary)
              }
              Slider(
                value: $draftBrightness,
                in: 1...100,
                step: 1,
                onEditingChanged: { editing in
                  if !editing { Task { await model.setAreaBrightness(draftBrightness) } }
                }
              )
              .disabled(!model.canUseEverydayControls)
              .accessibilityValue("\(Int(draftBrightness)) percent")
            }
          }

          Section("Lights") {
            ForEach(model.selectedArea?.lights ?? []) { light in
              LightRow(light: light)
            }
          }

          Section {
            Text(
              "State shown here is Bridge API readback and may lag physical output. Hue Board never overrides a light owned by an Entertainment stream."
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
          }
        }
      } else {
        ContentUnavailableView {
          Label("Connect a Hue Bridge", systemImage: "lightbulb.2")
        } description: {
          Text("Pair once on trusted Wi-Fi. Opening Hue Board never changes lights.")
        } actions: {
          Button("Connect") { model.isConnectionSheetPresented = true }
            .buttonStyle(.borderedProminent)
        }
      }
    }
    .navigationTitle(model.selectedArea?.name ?? "Hue Board")
    .toolbar {
      ToolbarItemGroup(placement: .topBarTrailing) {
        Button {
          Task { await model.refreshInventory() }
        } label: {
          Label("Refresh", systemImage: "arrow.clockwise")
        }
        .disabled(!model.isReady || model.isBusy)

        Button {
          model.isConnectionSheetPresented = true
        } label: {
          Label("Bridge", systemImage: "network")
        }
      }
    }
    .onAppear { draftBrightness = model.brightness }
    .onChange(of: model.brightness) { _, value in draftBrightness = value }
  }

  private var areaSelection: Binding<HueResourceID> {
    Binding(
      get: { model.selectedAreaID ?? HueResourceID(rawValue: "") },
      set: { id in Task { await model.selectArea(id) } }
    )
  }
}

private struct LightRow: View {
  let light: HueLight

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: light.isOn ? "lightbulb.fill" : "lightbulb")
        .font(.title3)
        .foregroundStyle(light.isOn ? Color.accentColor : Color.secondary)
        .frame(width: 32)
      VStack(alignment: .leading, spacing: 3) {
        Text(light.name).font(.body.weight(.medium))
        HStack(spacing: 5) {
          Text(light.isOn ? "On" : "Off")
          if let brightness = light.brightness { Text("· \(Int(brightness.rounded()))%") }
          if light.capabilities.streaming { Text("· Streaming") }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
      }
      Spacer()
      HStack(spacing: 5) {
        if light.capabilities.dynamicPalette {
          Image(systemName: "sparkles").accessibilityLabel("Dynamic palette")
        }
        if light.capabilities.color {
          Image(systemName: "paintpalette.fill").accessibilityLabel("Color")
        } else if light.capabilities.colorTemperature {
          Image(systemName: "thermometer.medium").accessibilityLabel("Adjustable white")
        }
      }
      .foregroundStyle(.tertiary)
    }
    .accessibilityElement(children: .combine)
  }
}
