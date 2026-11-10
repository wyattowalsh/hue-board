import SwiftUI
import HueBoardKit

struct ConnectPrompt: View {
  @Environment(AppModel.self) private var model
  var body: some View {
    ContentUnavailableView {
      Label("Connect a Hue Bridge", systemImage: "dot.radiowaves.left.and.right")
    } description: {
      Text("Discovery and pairing never change lights. The physical Bridge button is required before a local key is stored in Keychain.")
    } actions: {
      Button("Connect Bridge") { model.isConnectionSheetPresented=true }.buttonStyle(.borderedProminent)
    }
  }
}

struct AreaPicker: View {
  @Environment(AppModel.self) private var model
  var body: some View {
    @Bindable var model=model
    Picker("Room or zone",selection: Binding(get:{model.selectedAreaID},set:{id in if let id{Task{await model.selectArea(id)}}})){
      ForEach(model.areas){area in Text(area.name).tag(Optional(area.id))}
    }
    .disabled(!model.canSwitchArea)
  }
}

struct PlaybackBanner: View {
  @Environment(AppModel.self) private var model
  var body: some View {
    if model.playbackSnapshot.mode != .idle || model.hasRestorePoint {
      VStack(alignment:.leading,spacing:8){
        HStack{
          VStack(alignment:.leading,spacing:2){
            Text(title).font(.headline)
            Text(model.playbackSnapshot.message).font(.caption).foregroundStyle(.secondary).lineLimit(3)
          }
          Spacer()
          if model.hasRestorePoint || model.playbackSnapshot.phase == .running || model.requiresRecovery {
            Button("Stop & restore") { Task{await model.stopAndRestore()} }
              .buttonStyle(.borderedProminent)
              .disabled(model.isBusy)
          }
        }
        if model.playbackSnapshot.phase == .running && model.playbackSnapshot.progress > 0 {
          ProgressView(value:model.playbackSnapshot.progress)
        }
      }
      .padding(12)
      .background(.ultraThinMaterial)
      .accessibilityElement(children:.combine)
    }
  }
  private var title:String{
    switch model.playbackSnapshot.mode{
    case .bridge:"Bridge Play"
    case .liveForeground:"Ambient Live · foreground"
    case .liveContinued:"Ambient Live · continued"
    case .stopping:"Restoring"
    case .idle:"Recovery"
    }
  }
}

struct StatusCard: View {
  @Environment(AppModel.self) private var model
  var body: some View {
    VStack(alignment:.leading,spacing:8){
      Label(model.connectionState == .ready ? "Bridge connected" : "Bridge disconnected",systemImage:model.connectionState == .ready ? "checkmark.circle.fill":"exclamationmark.triangle.fill")
        .font(.headline)
      Text(model.note).font(.subheadline).foregroundStyle(.secondary)
      if let profile=model.profile {
        Text("\(profile.displayHost) · \(profile.bridgeID)").font(.caption.monospaced()).foregroundStyle(.secondary)
      }
      if model.isReady {
        HStack(spacing:6){
          Image(systemName:model.eventStreamConnected ? "dot.radiowaves.left.and.right":"pause.circle")
          Text("Push readback: \(model.eventStreamStatus)")
        }
        .font(.caption.weight(.semibold))
        Text(model.eventStreamDetail).font(.caption2).foregroundStyle(.secondary)
        if let lastEventAt=model.lastEventAt {
          Text("Last push update \(lastEventAt.formatted(date:.omitted,time:.standard))")
            .font(.caption2).foregroundStyle(.secondary)
        }
      }
    }
    .padding()
    .background(.quaternary.opacity(0.55),in:RoundedRectangle(cornerRadius:18))
  }
}

struct LightRow: View {
  let light:HueLight
  var body:some View{
    HStack(spacing:12){
      Circle().fill(swiftUIColor(light.color)).frame(width:30,height:30)
        .overlay(Circle().stroke(.primary.opacity(0.15)))
      VStack(alignment:.leading){
        Text(light.name)
        Text(lightSubtitle).font(.caption).foregroundStyle(.secondary)
      }
      Spacer()
      if light.capabilities.streaming { Label("Streaming",systemImage:"waveform").font(.caption).foregroundStyle(.orange) }
      else { Text(light.isOn ? "\(Int(light.brightness))%":"Off").font(.callout.monospacedDigit()) }
    }
    .accessibilityElement(children:.combine)
  }
  private var lightSubtitle:String{
    var parts:[String]=[]
    if light.capabilities.color { parts.append("Color") }
    if light.capabilities.colorTemperature { parts.append("White ambiance") }
    if light.capabilities.dimming { parts.append("Dimmable") }
    return parts.isEmpty ? "Basic fixture" : parts.joined(separator:" · ")
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
  let preset:HuePreset
  let contract:HueBoardContract
  let selected:Bool
  var body:some View{
    TimelineView(.animation(minimumInterval:1.0/20.0,paused:false)){context in
      Canvas{graphics,size in
        let settings=HueEngineSettings.from(preset:preset,brightness:75)
        for index in 0..<9 {
          let position=Double(index)/9
          let frame=HueEngine.sample(time:context.date.timeIntervalSinceReferenceDate,position:position,settings:settings)
          let width=size.width/9
          graphics.fill(Path(roundedRect:CGRect(x:CGFloat(index)*width,y:0,width:width+1,height:size.height),cornerRadius:4),with:.color(Color(red:frame.color.red,green:frame.color.green,blue:frame.color.blue)))
        }
      }
    }
    .frame(height:74)
    .clipShape(RoundedRectangle(cornerRadius:16))
    .overlay(RoundedRectangle(cornerRadius:16).stroke(selected ? .primary : .clear,lineWidth:2))
  }
}
