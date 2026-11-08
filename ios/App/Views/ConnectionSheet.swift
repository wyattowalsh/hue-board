import SwiftUI
import HueBoardKit

struct ConnectionSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            Form {
                Section("Find a Hue Bridge") {
                    Button {
                        Task { await model.discoverBridges() }
                    } label: {
                        Label("Discover Hue Bridges", systemImage: "magnifyingglass")
                    }
                    .disabled(model.isBusy)

                    ForEach(model.discoveredBridges) { candidate in
                        Button {
                            Task { await model.probe(candidate) }
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(candidate.host)
                                Text(candidate.id)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .disabled(model.isBusy)
                    }
                }

                Section("Manual address") {
                    TextField("192.168.1.10 or hue-bridge.local", text: $model.manualHost)
                        .textContentType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button {
                        Task { await model.probeManualHost() }
                    } label: {
                        Label("Verify Bridge", systemImage: "checkmark.shield")
                    }
                    .disabled(model.manualHost.isEmpty || model.isBusy)
                }

                if let pending = model.pendingProfile {
                    Section("Ready to pair") {
                        LabeledContent("Bridge", value: pending.bridgeID)
                        LabeledContent("Address", value: pending.displayHost)
                        Text("Press the physical center button on the Bridge, then pair. Hue Board stores the application key in Keychain.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Button {
                            Task { await model.pairPendingBridge() }
                        } label: {
                            Label("Pair now", systemImage: "link.badge.plus")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(model.isBusy)
                    }
                }

                Section {
                    Text("Opening, verifying, pairing, and refreshing never change a light. The current native transport uses standard HTTPS trust, private-LAN host validation, and redirect rejection.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Connect Bridge")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .disabled(!model.isReady && model.manualHost.isEmpty)
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
        }
    }
}
