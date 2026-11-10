import SwiftUI

struct LightsView: View {
  @Environment(AppModel.self) private var model
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
              Button("Turn off now",role:.destructive){Task{await model.turnOffNow()}}
                .buttonStyle(.bordered)
                .disabled(!model.canTurnOffNow)
            }
            .disabled(!model.canUseEverydayControls)
            VStack(alignment:.leading){
              HStack{Text("Brightness");Spacer();Text("\(Int(model.brightness))%").monospacedDigit()}
              Slider(value:$model.brightness,in:1...100,step:1){editing in if !editing { Task{await model.setAreaBrightness(model.brightness)} }}
                .disabled(!model.canUseEverydayControls)
            }
            if !model.canUseEverydayControls && model.isReady {
              Text("Stop and restore active playback before using ordinary controls. Turn off now remains available and retains the baseline.")
                .font(.caption).foregroundStyle(.secondary)
            }
          }
          if let area=model.selectedArea {
            Section("\(area.name) · \(area.lights.count) lights"){
              ForEach(area.lights){LightRow(light:$0)}
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
    .toolbar {
      ToolbarItem(placement:.topBarTrailing){Button{model.isConnectionSheetPresented=true}label:{Image(systemName:"dot.radiowaves.left.and.right")}.accessibilityLabel("Bridge connection")}
      ToolbarItem(placement:.topBarTrailing){Button{Task{await model.refreshInventory()}}label:{Image(systemName:"arrow.clockwise")}.disabled(!model.isReady||model.isBusy).accessibilityLabel("Refresh Bridge state")}
    }
  }
}
