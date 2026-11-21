import SwiftUI
import UniformTypeIdentifiers
import HueBoardKit

struct PortableDataSection: View {
    @Environment(AppModel.self) private var model
    @State private var isImporting = false
    @State private var isExporting = false
    @State private var isReadingFile = false
    @State private var review: ImportReview?
    @State private var setupSheet: SetupSheet?
    @State private var exportFile: HuePortableFile?
    @State private var exportName = "Hue Board"
    @State private var feedback: String?
    @State private var failure: String?

    #if DEBUG && targetEnvironment(simulator)
    @State private var didOpenSampleSetup = false
    #endif

    private enum SetupSheet: Identifiable {
        case export, review(HueSetupDocument)

        var id: String {
            switch self {
            case .export: "export"
            case .review: "review"
            }
        }
    }

    private struct ImportReview {
        let value: HuePortableData
        let message: String
    }

    var body: some View {
        Section {
            Button("Export setup", systemImage: "square.and.arrow.up") {
                setupSheet = .export
            }
            .accessibilityIdentifier("setup-export")

            Button("Import setup or file", systemImage: "square.and.arrow.down") {
                isImporting = true
            }
            .disabled(!model.canImportPortableData || isReadingFile)
            .accessibilityIdentifier("setup-import")

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
                Label("Export one section", systemImage: "square.and.arrow.up")
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
            Text("Setup files can include your room layout and lighting limits. You choose what to share.")
        }
        .sheet(item: $setupSheet) { sheet in
            switch sheet {
            case .export:
                SetupExportView(available: model.availableSetupExportSections) {
                    feedback = "Setup exported."
                }
            case .review(let setup):
                SetupImportReviewView(setup: setup) {
                    feedback = "Setup imported."
                }
            }
        }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json], onCompletion: readFile)
        .fileExporter(isPresented: $isExporting, document: exportFile, contentType: .json, defaultFilename: exportName) { result in
            if case .failure(let error) = result, !HuePortableFile.isCancellation(error) {
                failure = error.localizedDescription
            }
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
        #if DEBUG && targetEnvironment(simulator)
        .task {
            let env = ProcessInfo.processInfo.environment
            guard !didOpenSampleSetup, env["HUE_BOARD_UI_TEST_MODE"] == "1",
                  env["HUE_BOARD_SETUP_FIXTURE"] == "limits" else { return }
            didOpenSampleSetup = true
            do {
                let fixture = HueSetupDocument(favorites: ["ion-eclipse"],
                                               safety: .init(reduceLightMotion: true, maximumDynamicBrightness: 95))
                try openImportReview(HuePortableDataCodec.encode(.setup(fixture), contract: model.contract))
            } catch {
                failure = error.localizedDescription
            }
        }
        #endif
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
                try openImportReview(data)
            } catch {
                if !HuePortableFile.isCancellation(error) { failure = error.localizedDescription }
            }
        }
    }

    private func openImportReview(_ data: Data) throws {
        let value = try HuePortableDataCodec.decode(data, contract: model.contract)
        if case .setup(let setup) = value {
            setupSheet = .review(setup)
        } else {
            review = .init(value: value, message: try model.reviewPortableImport(value))
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

extension HuePortableFile {
    static func isCancellation(_ error: Error) -> Bool {
        let cocoa = error as NSError
        return cocoa.domain == NSCocoaErrorDomain && cocoa.code == NSUserCancelledError
    }
}
