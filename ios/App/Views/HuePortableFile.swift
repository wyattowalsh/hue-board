import Foundation
import SwiftUI
import UniformTypeIdentifiers
import HueBoardKit

struct HuePortableFile: FileDocument {
    static let readableContentTypes: [UTType] = [.json]
    let data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }

    static func read(from url: URL) throws -> Data {
        let hasScopedAccess = url.startAccessingSecurityScopedResource()
        defer { if hasScopedAccess { url.stopAccessingSecurityScopedResource() } }
        let input = try FileHandle(forReadingFrom: url)
        defer { try? input.close() }

        let limit = HuePortableDataCodec.maximumFileSize
        var data = Data()
        while data.count <= limit {
            let remaining = limit + 1 - data.count
            guard let chunk = try input.read(upToCount: min(remaining, 64 * 1024)), !chunk.isEmpty else { break }
            data.append(chunk)
        }
        guard data.count <= limit else {
            throw HueBoardError.unsupported("Hue Board files must be 512 KB or smaller.")
        }
        return data
    }
}
