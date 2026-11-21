import SwiftUI

struct SettingsView: View {
  @Environment(AppModel.self) private var model
  @State private var confirmForget=false
  @State private var confirmDestructiveReset=false
  @State private var confirmForeignBaseline=false
  var body:some View{
    @Bindable var model=model
    Form{
      Section("Bridge"){
        if let profile=model.profile {
          LabeledContent("Bridge ID",value:profile.bridgeID)
          LabeledContent("Address",value:profile.displayHost)
          if let modelID=profile.modelID {LabeledContent("Model",value:modelID)}
          if let apiVersion=profile.apiVersion {LabeledContent("API",value:apiVersion)}
          if let fingerprint=profile.displayCertificateSHA256 {
            VStack(alignment:.leading,spacing:4){Text("Pinned certificate SHA-256").font(.caption).foregroundStyle(.secondary);Text(fingerprint).font(.caption2.monospaced()).textSelection(.enabled)}
          }
          Button("Forget Bridge",role:.destructive){confirmForget=true}.disabled(!model.canForgetBridge)
          if model.hasRestorePoint {
            Button("Discard recovery & forget Bridge",role:.destructive){confirmDestructiveReset=true}.disabled(model.isBusy)
            Text("Last resort for a permanently unreachable or replaced Bridge. This deletes the only saved baseline without restoring those lights.").font(.caption).foregroundStyle(.secondary)
          }
          if model.foreignRecoveryPending {
            Button("Discard the other Bridge's baseline",role:.destructive){confirmForeignBaseline=true}.disabled(model.isBusy)
            Text("The saved baseline belongs to a different Bridge. Reconnect that Bridge to restore its lights, or discard the baseline if that Bridge cannot be recovered. This Bridge stays paired.").font(.caption).foregroundStyle(.secondary)
          }
        } else {Button("Connect Bridge"){model.presentConnection()}}
      }
      Section("Physical-light safety") {
        Toggle(
          "Reduce Light Motion",
          isOn: Binding(
            get: { model.safetySettings.reduceLightMotion },
            set: { value in Task { await model.setReduceLightMotion(value) } }
          )
        )
        if model.systemLightMotion.isEnabled {
          Text("iOS Dim Flashing Lights is enabled. New playback sessions use reduced light motion.")
            .font(.footnote)
        }
        Text(
          "Uses slower Ambient Live transitions and pattern timing, bounds engine speed, energy, depth, and phase movement, and caps Bridge Play speed. The Bridge may still move a recalled scene."
        )
        .font(.caption)
        .foregroundStyle(.secondary)

        VStack(alignment: .leading, spacing: 8) {
          HStack {
            Text("Maximum dynamic brightness")
            Spacer()
            Text("\(Int(model.safetySettings.maximumDynamicBrightness))%")
              .monospacedDigit()
          }
          Slider(
            value: Binding(
              get: { model.safetySettings.maximumDynamicBrightness },
              set: { value in Task { await model.setMaximumDynamicBrightness(value) } }
            ),
            in: 10...100,
            step: 5
          )
        }
        Button("Show dynamic-light warning again") {
          Task { await model.showDynamicLightSafetyAgain() }
        }
        Text(
          "These controls reduce motion and output by product policy; they are not a medical guarantee. Stop dynamic output immediately if anyone feels discomfort."
        )
        .font(.caption)
        .foregroundStyle(.secondary)
      }
      .disabled(!model.canEditPhysicalSafetySettings)
      if model.isLiveRunning || model.playbackSnapshot.mode == .bridge {
        Text("Stop and restore playback before changing its motion or brightness limits.")
          .font(.footnote)
      }

      PortableDataSection()

      Section("Security"){
        Text("The native client accepts only private LAN IPv4 or trusted .local hosts, rejects redirects, verifies the certificate Bridge ID, and pins the leaf SHA-256 after first contact. The application key remains in Keychain.")
        Text("First contact is trust on first use. Verify the physical Bridge on a trusted home network. Certificate rotation or Bridge replacement requires deliberate re-verification.")
      }.font(.footnote).foregroundStyle(.secondary)
      Section("Playback contract"){
        Text("Play recalls a Bridge-native dynamic palette and can continue without the phone after accepted recall.")
        Text("Ambient Live executes on the phone over conservative REST transitions. It remains bounded and is not Entertainment streaming.")
        Text("A successful Hue API response is not a measurement of emitted light. Restore points are static snapshots; review timestamps and competing-controller changes.")
      }.font(.footnote).foregroundStyle(.secondary)
    }
    .navigationTitle("Settings")
    .toolbar {
      ToolbarItem(placement:.confirmationAction){Button("Done"){model.isSettingsPresented=false}}
    }
    .confirmationDialog("Remove this Bridge from Hue Board?",isPresented:$confirmForget,titleVisibility:.visible){Button("Forget Bridge",role:.destructive){Task{await model.forgetBridge()}}}message:{Text("This removes the Hue application key, certificate pin, and Hue Board scene registry from this device. Active recovery must be restored first.")}
    .confirmationDialog("Permanently discard the saved baseline?",isPresented:$confirmDestructiveReset,titleVisibility:.visible){Button("Discard recovery & forget",role:.destructive){Task{await model.discardRecoveryAndForgetBridge()}}}message:{Text("Hue Board will not restore the affected lights. This permanently deletes the application key, certificate pin, scene registry, and the only saved baseline for this Bridge. Use only if the original Bridge is unreachable or has been replaced.")}
    .confirmationDialog("Delete the other Bridge's baseline?",isPresented:$confirmForeignBaseline,titleVisibility:.visible){Button("Discard unrestored baseline",role:.destructive){Task{await model.discardForeignBaseline()}}}message:{Text("Hue Board will not restore those lights. This permanently deletes the only saved baseline for the other Bridge. The Bridge you are connected to now stays paired.")}
  }
}
