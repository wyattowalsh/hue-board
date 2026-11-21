import SwiftUI
import HueBoardKit

struct RoomSweepSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var failure: String?
    let preview: RoomSweepPreview

    var body: some View {
        NavigationStack {
            List {
                if preview.proposal.distinctPositionCount < 2 {
                    Text("Place at least two selected moving lights at different horizontal positions to build a sweep.")
                } else if preview.proposal.changes.isEmpty {
                    Text("The moving lights already follow this sweep.")
                } else {
                    Section("Left-to-right sweep") {
                        ForEach(preview.proposal.changes) { change in
                            if let light = preview.area.lights.first(where: { $0.id == change.id }) {
                                LabeledContent(light.name) {
                                    Text("\(change.previous, format: .percent.precision(.fractionLength(0))) → \(change.phase, format: .percent.precision(.fractionLength(0)))")
                                }
                            }
                        }
                    }
                    Text("Saving updates these animation phases in this room.")
                    if !model.canSaveRoomSweep(preview) {
                        Text("The room or its moving fixtures changed. Close and preview the sweep again.")
                    }
                }
                if let failure { Text(failure) }
            }
            .navigationTitle("Preview sweep")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save phases") {
                        do { try model.saveRoomSweep(preview); dismiss() }
                        catch { failure = error.localizedDescription }
                    }
                    .disabled(!model.canSaveRoomSweep(preview))
                }
            }
        }
    }
}
