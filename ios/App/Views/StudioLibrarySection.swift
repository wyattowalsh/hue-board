import SwiftUI
import UniformTypeIdentifiers
import HueBoardKit

struct StudioLibrarySection: View {
    @Environment(AppModel.self) private var model
    @State private var mixName = ""
    @State private var pendingDeletionID: String?
    @State private var exportFile: HuePortableFile?
    @State private var isExporting = false

    var body: some View {
        Form {
            if let issue = model.studioLibraryIssue {
                Label("Your saved mixes couldn’t be opened. \(issue)", systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            } else {
                Section("Save current mix") {
                    TextField("Mix name", text: $mixName)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: mixName) { _, value in
                            if value.count > 80 { mixName = String(value.prefix(80)) }
                        }
                    Button("Save mix") {
                        if model.saveStudioMix(named: mixName) {
                            mixName = ""
                        }
                    }
                    .disabled(mixName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                              || model.isLiveRunning)
                }

                if !model.savedStudioDocuments.isEmpty {
                    Section("On this iPhone") {
                        ForEach(model.savedStudioDocuments, id: \.documentId) { document in
                            HStack(spacing: 8) {
                                Button(document.name) {
                                    model.loadStudioMix(id: document.documentId)
                                    if model.errorMessage == nil { model.studioPath = [.mix] }
                                }
                                .buttonStyle(.borderless)
                                .disabled(model.isLiveRunning)
                                .accessibilityLabel("Load \(document.name)")
                                Spacer()
                                Menu {
                                    Button("Export mix", systemImage: "square.and.arrow.up") {
                                        exportMix(document)
                                    }
                                    Button(role: .destructive) {
                                        pendingDeletionID = document.documentId
                                    } label: {
                                        Label("Delete mix", systemImage: "trash")
                                    }
                                } label: {
                                    Image(systemName: "ellipsis.circle")
                                        .frame(minWidth: 44, minHeight: 44)
                                }
                                .buttonStyle(.borderless)
                                .accessibilityLabel("Actions for \(document.name)")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Saved mixes")
        .navigationBarTitleDisplayMode(.inline)
        .fileExporter(isPresented: $isExporting, document: exportFile, contentType: .json, defaultFilename: "Hue Board Mix") { result in
            if case .failure(let error) = result { model.errorMessage = error.localizedDescription }
        }
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
        }
    }

    private func exportMix(_ document: HueSceneDocument) {
        do {
            exportFile = .init(data: try HueSceneDocumentCodec.encode(document, contract: model.contract))
            isExporting = true
        } catch {
            model.errorMessage = error.localizedDescription
        }
    }
}
