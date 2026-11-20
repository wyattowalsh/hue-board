import SwiftUI
import HueBoardKit

struct StudioLibrarySection: View {
    @Environment(AppModel.self) private var model
    @State private var mixName = ""
    @State private var pendingDeletionID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Your saved mixes", systemImage: "square.stack.3d.up.fill")
                .font(.headline)

            if let issue = model.studioLibraryIssue {
                Label("Saved mixes could not be validated. Existing storage is preserved: \(issue)", systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            } else {
                HStack {
                    TextField("Name this mix", text: $mixName)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: mixName) { _, value in
                            if value.count > 80 { mixName = String(value.prefix(80)) }
                        }
                    Button("Save") {
                        if model.saveStudioMix(named: mixName) {
                            mixName = ""
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(mixName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                              || model.isLiveRunning)
                }

                if model.savedStudioDocuments.isEmpty {
                    Text("Nothing saved yet. Your Studio draft stays local until you name and save it.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.savedStudioDocuments, id: \.documentId) { document in
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(document.name)
                                    .font(.subheadline.weight(.medium))
                                Text("Saved composition · no Bridge target")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Load") {
                                model.loadStudioMix(id: document.documentId)
                            }
                            .buttonStyle(.bordered)
                            .disabled(model.isLiveRunning)
                            Button(role: .destructive) {
                                pendingDeletionID = document.documentId
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.bordered)
                            .accessibilityLabel("Delete \(document.name)")
                        }
                    }
                }
            }
            Text("Mixes are stored on this iPhone as validated, scope-free Hue Board scene documents. They contain no Bridge credentials or fixture targets.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 20))
        .confirmationDialog(
            "Delete this saved mix?",
            isPresented: Binding(
                get: { pendingDeletionID != nil },
                set: { if !$0 { pendingDeletionID = nil } }
            )
        ) {
            Button("Delete mix", role: .destructive) {
                if let id = pendingDeletionID {
                    model.deleteStudioMix(id: id)
                }
                pendingDeletionID = nil
            }
            Button("Cancel", role: .cancel) { pendingDeletionID = nil }
        } message: {
            Text("This removes the local saved copy. It never changes Hue Bridge scenes or lights.")
        }
    }
}
