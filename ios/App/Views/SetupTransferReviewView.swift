import HueBoardKit
import SwiftUI
import UniformTypeIdentifiers

struct SetupExportView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var selection: Set<HueSetupSection>
    @State private var exportFile: HuePortableFile?
    @State private var choosingDestination = false
    @State private var errorMessage: String?
    let didExport: () -> Void

    init(available: Set<HueSetupSection>, didExport: @escaping () -> Void) {
        _selection = State(initialValue: available.subtracting([.layout, .safety]))
        self.didExport = didExport
    }

    var body: some View {
        NavigationStack {
            Form {
                SetupSectionPicker(
                    available: model.availableSetupExportSections,
                    selection: $selection,
                    roomName: model.selectedArea?.name
                )
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }
            .navigationTitle("Export setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Choose location") { chooseLocation() }
                        .accessibilityIdentifier("setup-export-location")
                        .disabled(selection.isDisjoint(with: model.availableSetupExportSections))
                }
            }
        }
        .onChange(of: model.roomLayoutScope) { _, _ in
            if selection.remove(.layout) != nil {
                errorMessage = "The selected room changed. Choose its layout again to include it."
            }
        }
        .fileExporter(
            isPresented: $choosingDestination, document: exportFile,
            contentType: .json, defaultFilename: "Hue Board Setup"
        ) { result in
            switch result {
            case .success:
                didExport()
                dismiss()
            case .failure(let error):
                if !HuePortableFile.isCancellation(error) { errorMessage = error.localizedDescription }
            }
        }
    }

    private func chooseLocation() {
        do {
            let value = try model.exportSetup(sections: selection)
            exportFile = try HuePortableFile(data: HuePortableDataCodec.encode(value, contract: model.contract))
            errorMessage = nil
            choosingDestination = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct SetupImportReviewView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let setup: HueSetupDocument
    let didImport: () -> Void
    @State private var selection: Set<HueSetupSection>
    @State private var review: HueSetupReview?
    @State private var failure: String?
    @State private var isSaving = false

    init(setup: HueSetupDocument, didImport: @escaping () -> Void) {
        self.setup = setup
        self.didImport = didImport
        _selection = State(initialValue: setup.availableSections.subtracting([.layout, .safety]))
    }

    var body: some View {
        NavigationStack {
            Form {
                SetupSectionPicker(
                    available: setup.availableSections,
                    selection: Binding(get: { selection }, set: { next in
                        selection = next
                        refreshReview()
                    })
                )
                .disabled(isSaving)
                Section("Changes on this iPhone") {
                    if let review {
                        ForEach(Array(review.lines.enumerated()), id: \.offset) { _, line in
                            Text(verbatim: line)
                                .accessibilityLabel(line.replacingOccurrences(of: " → ", with: " to "))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    } else if selection.isEmpty {
                        Text("Choose a section to review its changes.")
                    }
                    if let failure {
                        Text(failure).foregroundStyle(.red)
                    }
                    if !selection.isEmpty {
                        Button("Review again", action: refreshReview)
                            .disabled(isSaving)
                    }
                }
                if isSaving { ProgressView("Importing setup…") }
            }
            .navigationTitle("Review setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") {
                        guard !isSaving, model.canImportPortableData, let review, review.canApply else { return }
                        isSaving = true
                        Task { await apply(review) }
                    }
                    .disabled(review?.canApply != true || isSaving || !model.canImportPortableData)
                    .accessibilityIdentifier("setup-confirm-import")
                }
            }
        }
        .onAppear(perform: refreshReview)
        .interactiveDismissDisabled(isSaving)
    }

    private func refreshReview() {
        review = nil
        failure = nil
        guard !selection.isEmpty else { return }
        do {
            review = try model.reviewSetup(setup, sections: selection)
        } catch {
            failure = error.localizedDescription
        }
    }

    private func apply(_ confirmed: HueSetupReview) async {
        defer { isSaving = false }
        do {
            try await model.applySetup(setup, sections: selection, review: confirmed)
            didImport()
            dismiss()
        } catch {
            review = nil
            failure = error.localizedDescription
        }
    }
}

private struct SetupSectionPicker: View {
    let available: Set<HueSetupSection>
    @Binding var selection: Set<HueSetupSection>
    var roomName: String?

    var body: some View {
        Section("Include") {
            ForEach(HueSetupSection.allCases.filter(available.contains), id: \.self) { section in
                Toggle(isOn: Binding(
                    get: { selection.contains(section) },
                    set: { include in
                        var next = selection
                        if include { next.insert(section) } else { next.remove(section) }
                        selection = next
                    }
                )) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(section.title)
                        if section == .layout, let roomName {
                            Text(roomName).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
                .accessibilityIdentifier("setup-section-\(section.rawValue)")
            }
        }
    }
}
