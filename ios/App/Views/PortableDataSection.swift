import SwiftUI
import UniformTypeIdentifiers
import HueBoardKit

struct PortableDataSection: View {
    @Environment(AppModel.self) private var model
    @State private var isImporting = false
    @State private var isExporting = false
    @State private var isReadingFile = false
    @State private var review: ImportReview?
    @State private var exportFile: HuePortableFile?
    @State private var exportName = "Hue Board"
    @State private var feedback: String?
    @State private var failure: String?

    private struct ImportReview {
        let value: HuePortableData
        let message: String
    }

    var body: some View {
        Section {
            Button("Import file", systemImage: "square.and.arrow.down") {
                isImporting = true
            }
            .disabled(!model.canImportPortableData || isReadingFile)

            Menu {
                Button("Studio draft") { export(model.portableStudioDraft, name: "Studio Draft") }
                Button("Custom palette") { export(.customPalette(model.studioSettings.customColors), name: "Custom Palette") }
                Button("Cue sequence") { export(model.portableCues, name: "Cue Sequence") }
                Button("Saved mixes") { export(.mixLibrary(model.savedStudioDocuments), name: "Saved Mixes") }
                    .disabled(model.studioLibraryIssue != nil || model.savedStudioDocuments.isEmpty)
                Button("Scene favorites") { export(.favorites(model.favoritePresetIDs.sorted()), name: "Favorites") }
                if let layout = model.roomLayout, model.roomLayoutIssue == nil {
                    Button("Selected room layout") { export(.roomLayout(layout), name: "Room Layout") }
                }
                Button("Physical-light safety preferences") { export(model.portableSafety, name: "Safety Preferences") }
            } label: {
                Label("Export file", systemImage: "square.and.arrow.up")
            }

            if isReadingFile {
                ProgressView("Reading file…")
            } else if let feedback {
                Text(feedback)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityAddTraits(.updatesFrequently)
            }
        } header: {
            Text("Import and export")
        } footer: {
            Text("Files transfer local data. A layout can be imported into its original room or zone.")
        }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json], onCompletion: readFile)
        .fileExporter(isPresented: $isExporting, document: exportFile, contentType: .json, defaultFilename: exportName) { result in
            if case .failure(let error) = result { failure = error.localizedDescription }
        }
        .alert("Import Hue Board file", isPresented: reviewPresented, presenting: review) { pending in
            Button("Import") {
                Task {
                    do {
                        // A changed inventory or local setting needs a new confirmation.
                        let currentMessage = try model.reviewPortableImport(pending.value)
                        guard pending.message == currentMessage else {
                            failure = "Local data changed while you reviewed this file. Open the file again to see the current changes."
                            return
                        }
                        try await model.applyPortableImport(pending.value)
                        feedback = "File imported. Your lights were untouched."
                    } catch {
                        failure = error.localizedDescription
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { pending in
            Text(pending.message)
        }
        .alert("Couldn’t transfer file", isPresented: failurePresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(failure ?? "Try the transfer again.")
        }
    }

    private var reviewPresented: Binding<Bool> {
        Binding(get: { review != nil }, set: { if !$0 { review = nil } })
    }

    private var failurePresented: Binding<Bool> {
        Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })
    }

    private func readFile(_ result: Result<URL, Error>) {
        feedback = nil
        isReadingFile = true
        Task {
            defer { isReadingFile = false }
            do {
                let url = try result.get()
                let data = try await Task.detached(priority: .userInitiated) { try HuePortableFile.read(from: url) }.value
                let value = try HuePortableDataCodec.decode(data, contract: model.contract)
                review = .init(value: value, message: try model.reviewPortableImport(value))
            } catch {
                failure = error.localizedDescription
            }
        }
    }

    private func export(_ value: HuePortableData, name: String) {
        do {
            exportFile = .init(data: try HuePortableDataCodec.encode(value, contract: model.contract))
            exportName = "Hue Board \(name)"
            isExporting = true
        } catch {
            failure = error.localizedDescription
        }
    }
}
