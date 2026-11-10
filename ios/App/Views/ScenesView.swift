import SwiftUI

struct ScenesView: View {
  @Environment(AppModel.self) private var model
  var body:some View{
    Group{
      if !model.isReady { ConnectPrompt() }
      else {
        ScrollView{
          LazyVStack(spacing:14){
            StatusCard()
            ForEach(model.contract.presets){preset in
              VStack(alignment:.leading,spacing:10){
                ScenePreview(preset:preset,contract:model.contract,selected:model.selectedPresetID==preset.id)
                HStack(alignment:.top){
                  VStack(alignment:.leading,spacing:3){
                    Text(preset.name).font(.headline)
                    Text(preset.category).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Text(preset.description).font(.subheadline).foregroundStyle(.secondary)
                  }
                  Spacer()
                  Button("Select"){model.selectedPresetID=preset.id}
                }
                Button {
                  Task{await model.play(preset)}
                } label:{Label("Play on Bridge",systemImage:"play.fill").frame(maxWidth:.infinity)}
                  .buttonStyle(.borderedProminent).disabled(!model.canPlayScene)
              }
              .padding()
              .background(.quaternary.opacity(0.45),in:RoundedRectangle(cornerRadius:20))
            }
            if !model.canPlayScene {
              Text("Stop and restore existing playback before starting another scene. Unsupported areas never fall back silently to Ambient Live.")
                .font(.footnote).foregroundStyle(.secondary).padding(.horizontal)
            }
          }.padding()
        }
      }
    }.navigationTitle("Scenes")
  }
}
