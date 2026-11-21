import SwiftUI
import HueBoardKit

struct ConnectionSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var searched = false
    @State private var choosingAnother = false
    @State private var removal: Removal?

    private enum Removal {
        case forget, discardAndForget, discardForeign

        var question: String {
            switch self {
            case .forget: "Forget this Bridge?"
            case .discardAndForget: "Discard recovery and forget this Bridge?"
            case .discardForeign: "Delete the other Bridge’s saved light state?"
            }
        }

        var consequence: String {
            switch self {
            case .forget:
                "Removes the pairing key, certificate pin and Hue Board scene registry from this iPhone. You’ll need the physical Bridge button to pair again."
            case .discardAndForget:
                "This permanently deletes the pairing key, certificate pin, scene registry and the only saved state for restoring these lights. Use this only if the original Bridge is lost or replaced."
            case .discardForeign:
                "Hue Board will not restore those lights. This permanently deletes the other Bridge’s saved light state. The current Bridge stays paired."
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                if let pending = model.pendingProfile, model.credential == nil,
                   model.connectionState == .awaitingBridgeButton {
                    Section {
                        Text("Press the round button on your Hue Bridge, then tap Pair Bridge.")
                        LabeledContent("Address", value: pending.displayHost)
                        Button("Pair Bridge", systemImage: "link") {
                            Task { await model.pairPendingBridge() }
                        }
                        .disabled(model.isBusy)
                    } header: {
                        Text("Pair your Bridge")
                    }
                    DisclosureGroup("Verify Bridge identity") {
                        LabeledContent("Bridge ID", value: pending.bridgeID)
                        if let fingerprint = pending.displayCertificateSHA256 {
                            certificateRow(fingerprint)
                        }
                        Text("Pair on a trusted home network. Hue Board checks the certificate against the Bridge ID and stores the pairing key in Keychain.")
                            .font(.footnote)
                    }
                }

                if model.profile != nil {
                    Section {
                        if let saved = model.profile, model.pendingProfile != nil && !model.isReady {
                            LabeledContent("Saved Bridge", value: saved.displayHost)
                        } else {
                            LabeledContent("Connection", value: model.isReady ? "Connected" : "Disconnected")
                        }
                        if model.isReady {
                            Button("Refresh Bridge state", systemImage: "arrow.clockwise") {
                                Task { await model.refreshInventory() }
                            }
                            .disabled(model.isBusy)
                        } else {
                            Button("Retry saved connection", systemImage: "arrow.clockwise") {
                                Task { await model.reconnectSavedBridge() }
                            }
                            .disabled(model.isBusy)
                        }
                    }
                }

                if !model.isReady {
                    if model.profile == nil && (model.pendingProfile == nil || model.connectionState != .awaitingBridgeButton) {
                        Section { discoveryControls }
                    } else {
                        Section {
                            DisclosureGroup("Find a different Bridge", isExpanded: $choosingAnother) {
                                discoveryControls
                            }
                        }
                    }
                }

                if let profile = model.profile {
                    Section {
                        DisclosureGroup("Connection details") {
                            LabeledContent("Address", value: profile.displayHost)
                            LabeledContent("Bridge ID", value: profile.bridgeID)
                            if let modelID = profile.modelID { LabeledContent("Model", value: modelID) }
                            if let version = profile.apiVersion { LabeledContent("API version", value: version) }
                            if let fingerprint = profile.displayCertificateSHA256 { certificateRow(fingerprint) }
                            Text("The pairing key is kept in Keychain. A changed certificate blocks reconnection. Verify the physical Bridge before pairing again.")
                                .font(.footnote)
                            if model.isReady {
                                LabeledContent("Light updates", value: model.eventStreamStatus)
                                Text(model.eventStreamDetail).font(.footnote)
                                if let date = model.lastEventAt {
                                    LabeledContent("Last update", value: date.formatted(date: .omitted, time: .standard))
                                }
                            }
                            if !model.note.isEmpty { Text(model.note).font(.footnote) }
                        }
                    }
                    Section {
                        Button("Forget Bridge", role: .destructive) { removal = .forget }
                            .disabled(!model.canForgetBridge)
                        if model.hasRestorePoint {
                            Button("Discard recovery & forget Bridge", role: .destructive) {
                                removal = .discardAndForget
                            }
                            .disabled(model.isBusy)
                        }
                        if model.foreignRecoveryPending {
                            Button("Discard the other Bridge's baseline", role: .destructive) {
                                removal = .discardForeign
                            }
                            .disabled(model.isBusy)
                        }
                    } footer: {
                        if model.foreignRecoveryPending || model.hasRestorePoint {
                            Text("Reconnect the original Bridge to restore the saved light state. Discard recovery only if that Bridge is permanently unavailable.")
                        }
                    }
                }
            }
            .onChange(of: model.connectionState) { _, state in
                if state == .awaitingBridgeButton { choosingAnother = false }
            }
            .navigationTitle(model.profile == nil ? "Connect Bridge" : "Hue Bridge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .overlay {
                if model.isBusy {
                    ProgressView()
                        .controlSize(.large)
                        .padding(24)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
                }
            }
            .confirmationDialog(
                removal?.question ?? "Forget Bridge?",
                isPresented: Binding(get: { removal != nil }, set: { if !$0 { removal = nil } }),
                titleVisibility: .visible,
                presenting: removal
            ) { action in
                switch action {
                case .forget:
                    Button("Forget Bridge", role: .destructive) { Task { await model.forgetBridge() } }
                case .discardAndForget:
                    Button("Discard recovery & forget Bridge", role: .destructive) {
                        Task { await model.discardRecoveryAndForgetBridge() }
                    }
                case .discardForeign:
                    Button("Discard unrestored baseline", role: .destructive) {
                        Task { await model.discardForeignBaseline() }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: { action in
                Text(action.consequence)
            }
        }
    }

    @ViewBuilder private var discoveryControls: some View {
        @Bindable var model = model
        Button("Find nearby Bridges", systemImage: "magnifyingglass") {
            Task {
                await model.discoverBridges()
                searched = true
            }
        }
        .disabled(model.isBusy)
        ForEach(model.discoveredBridges) { candidate in
            Button(candidate.port == 443 ? candidate.host : "\(candidate.host):\(candidate.port)") {
                Task { await model.probe(candidate) }
            }
            .disabled(model.isBusy)
        }
        if searched && model.discoveredBridges.isEmpty && model.errorMessage == nil {
            Text("No Bridges found. Check your Wi-Fi or enter the Bridge address.")
                .font(.footnote)
        }
        DisclosureGroup("Enter an address") {
            TextField("IP address or .local hostname", text: $model.manualHost)
                .textContentType(.URL)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button("Verify Bridge") {
                Task { await model.probeManualHost() }
            }
            .disabled(model.manualHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.isBusy)
        }
    }

    private func certificateRow(_ fingerprint: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Certificate fingerprint (SHA-256)").font(.caption)
            Text(fingerprint)
                .font(.caption.monospaced())
                .textSelection(.enabled)
        }
    }
}
