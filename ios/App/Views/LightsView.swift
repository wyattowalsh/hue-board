import SwiftUI
import HueBoardKit

struct LightsView: View {
  @Environment(AppModel.self) private var model
  @State private var selectedLight: HueLight?
  var body:some View{
    @Bindable var model=model
    Group{
      if !model.isReady { ConnectPrompt() }
      else {
        List{
          Section { StatusCard(); AreaPicker() }
          Section("Everyday control"){
            HStack{
              Button("Turn on"){Task{await model.setAreaPower(true)}}.buttonStyle(.borderedProminent)
              Button("Turn off"){Task{await model.setAreaPower(false)}}.buttonStyle(.bordered)
              Spacer()
            }
            .disabled(!model.canUseEverydayControls)
            Button("Turn off now",role:.destructive){Task{await model.turnOffNow()}}
              .buttonStyle(.bordered)
              .disabled(!model.canTurnOffNow)
              .accessibilityHint("Stops Hue Board playback and turns eligible lights off. The saved baseline stays available.")
            VStack(alignment:.leading){
              HStack{Text("Brightness");Spacer();Text("\(Int(model.brightness))%").monospacedDigit()}
              Slider(value: $model.brightness, in: 1...100, step: 1)
                .disabled(!model.canUseEverydayControls)
              Button("Apply brightness & turn on") {
                Task { await model.setAreaBrightness(model.brightness) }
              }
              .buttonStyle(.borderedProminent)
              .disabled(!model.canUseEverydayControls)
              .accessibilityHint("Sends the selected brightness only after this button is pressed.")
              Text("Moving the slider edits the value only. It never writes to lights until Apply is pressed.")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            if model.foreignRecoveryPending {
              Text("A saved baseline for another Bridge is still pending. Reconnect that Bridge and restore it before changing lights here.")
                .font(.caption).foregroundStyle(.secondary)
            } else if !model.canUseEverydayControls && model.isReady {
              Text("Stop and restore active playback before using ordinary controls. Turn off now remains available and retains the baseline.")
                .font(.caption).foregroundStyle(.secondary)
            }
          }
          if let area=model.selectedArea {
            Section("\(area.name) · \(area.lights.count) lights"){
              ForEach(area.lights) { light in
                Button {
                  selectedLight = light
                } label: {
                  HStack {
                    LightRow(light: light)
                    Image(systemName: "slider.horizontal.3")
                      .font(.caption)
                      .foregroundStyle(.secondary)
                  }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Edit \(light.name)")
              }
            }
          }
          Section {
            Text("State shown here is Bridge API readback and may lag physical output. Hue Board never overrides a light owned by an Entertainment stream.")
              .font(.footnote).foregroundStyle(.secondary)
          }
        }
      }
    }
    .navigationTitle("Lights")
    .sheet(item: $selectedLight) { light in
      LightDetailSheet(light: light).environment(model)
    }
    .toolbar {
      ToolbarItem(placement:.topBarTrailing){Button{model.isConnectionSheetPresented=true}label:{Image(systemName:"dot.radiowaves.left.and.right")}.accessibilityLabel("Bridge connection")}
      ToolbarItem(placement:.topBarTrailing){Button{Task{await model.refreshInventory()}}label:{Image(systemName:"arrow.clockwise")}.disabled(!model.isReady||model.isBusy).accessibilityLabel("Refresh Bridge state")}
      ToolbarItem(placement:.topBarTrailing){Button{model.isSettingsPresented=true}label:{Image(systemName:"gearshape.fill")}.accessibilityLabel("Settings")}
    }
  }
}
