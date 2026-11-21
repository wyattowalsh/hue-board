#if os(macOS) || os(Linux)
#if os(macOS)
import Darwin
#else
import Glibc
#endif
import Foundation
import XCTest
@testable import HueBoardKit

final class SetupImportProcessDeathTests: XCTestCase {
    private typealias Import = SetupImportTransaction
    private enum Boundary: String, CaseIterable {
        case prepared, partial, committed

        func matches(_ point: Import.Checkpoint) -> Bool {
            switch (self, point) {
            case (.prepared, .prepared), (.partial, .applied(0)), (.committed, .committed): true
            default: false
            }
        }
    }

    private static let idKey = "HUE_BOARD_TEST_SETUP_CRASH_UUID"
    private static let protected = [
        "hue-board.native.state.v2", "hue-board.native.recovery.v2", "hue-board.native.legacy-backup.v1"
    ]

    func testImportSurvivesProcessDeath() throws {
        let environment = ProcessInfo.processInfo.environment
        if let token = environment[Self.idKey] {
            guard let id = UUID(uuidString: token), let role = environment["HUE_BOARD_TEST_SETUP_ROLE"],
                  let boundary = Boundary(rawValue: environment["HUE_BOARD_TEST_SETUP_BOUNDARY"] ?? ""),
                  let parent = environment["HUE_BOARD_TEST_SETUP_PARENT"], parent == String(getppid()) else {
                throw Failure("Invalid subprocess arguments")
            }
            let context = try Context(id)
            switch role {
            case "write": try writeUntilKilled(context, boundary: boundary)
            case "read": try verifyInFreshProcess(context, boundary: boundary)
            default: throw Failure("Unknown subprocess role")
            }
            return
        }

        #if os(macOS)
        let runner = try xctestRunner()
        let bundle = Bundle(for: Self.self).bundleURL
        guard bundle.pathExtension == "xctest" else { throw Failure("The macOS package test bundle could not be located") }
        let selector = "\(NSStringFromClass(Self.self))/testImportSurvivesProcessDeath"
        let arguments = ["-XCTest", selector, bundle.path]
        #else
        // swift-corelibs-xctest embeds the test runner in the SwiftPM executable.
        let path = try FileManager.default.destinationOfSymbolicLink(atPath: "/proc/self/exe")
        let runner = URL(fileURLWithPath: path)
        guard FileManager.default.isExecutableFile(atPath: runner.path) else {
            throw Failure("The current Linux XCTest executable could not be located")
        }
        let arguments = ["\(String(reflecting: Self.self))/testImportSurvivesProcessDeath"]
        #endif
        for boundary in Boundary.allCases {
            let context = try Context(UUID())
            try FileManager.default.createDirectory(at: context.directory, withIntermediateDirectories: false,
                                                   attributes: [.posixPermissions: 0o700])
            defer {
                context.defaults.removePersistentDomain(forName: context.suite)
                _ = context.defaults.synchronize()
                try? FileManager.default.removeItem(at: context.directory)
            }
            try Import.saveFavorites(["before"], defaults: context.defaults)
            context.defaults.set(Data("before".utf8), forKey: Import.Section.library.preferenceKey)
            for key in Self.protected { context.defaults.set(Data(key.utf8), forKey: key) }
            guard context.defaults.synchronize() else { throw Failure("Could not seed isolated preferences") }

            func runChild(_ role: String) throws -> Process {
                let process = Process()
                process.executableURL = runner
                process.arguments = arguments
                var env = environment
                // This standalone runner gets its selector on the command line, independently of the parent test session.
                env.removeValue(forKey: "XCTestConfigurationFilePath")
                env.removeValue(forKey: "XCTestSessionIdentifier")
                env[Self.idKey] = context.id.uuidString
                env["HUE_BOARD_TEST_SETUP_PARENT"] = String(getpid())
                env["HUE_BOARD_TEST_SETUP_ROLE"] = role
                env["HUE_BOARD_TEST_SETUP_BOUNDARY"] = boundary.rawValue
                process.environment = env
                let logURL = context.directory.appendingPathComponent("\(role).log")
                guard FileManager.default.createFile(atPath: logURL.path, contents: nil) else {
                    throw Failure("Could not open the synthetic subprocess log")
                }
                let log = try FileHandle(forWritingTo: logURL)
                defer { try? log.close() }
                process.standardOutput = log
                process.standardError = log
                try run(process, timeout: 40)
                let tail = (try? String(contentsOf: logURL, encoding: .utf8))?.suffix(2048) ?? ""
                let writer = role == "write"
                guard process.terminationReason == (writer ? .uncaughtSignal : .exit),
                      process.terminationStatus == (writer ? SIGKILL : 0) else {
                    throw Failure("\(role) process at \(boundary.rawValue) exited with \(process.terminationStatus). \(tail)")
                }
                let witness = try String(contentsOf: context.witness(role), encoding: .utf8)
                XCTAssertEqual(witness, "\(process.processIdentifier) \(boundary.rawValue)")
                return process
            }
            let writer = try runChild("write")
            let reader = try runChild("read")
            XCTAssertNotEqual(writer.processIdentifier, reader.processIdentifier)
        }
    }

    private func writeUntilKilled(_ context: Context, boundary: Boundary) throws {
        let changes: [Import.Section: Import.Value] = [
            .favorites: .identifiers(["after"]), .library: .data(Data("after".utf8))
        ]
        let expected = try Import.fingerprint(for: Set(changes.keys), defaults: context.defaults)
        try Import.commit(changes, expected: expected, defaults: context.defaults) { point in
            guard boundary.matches(point) else { return }
            // A partial write can reach disk before a process dies. Force that case deterministically.
            guard context.defaults.synchronize() else { throw Failure("Could not flush writer checkpoint") }
            try context.mark("write", boundary)
            guard kill(getpid(), SIGKILL) == 0 else { throw Failure("Could not terminate the writer") }
            _exit(90)  // A normal exit here would fail the parent's signal assertion.
        }
        throw Failure("Writer completed without its selected termination point")
    }

    private func verifyInFreshProcess(_ context: Context, boundary: Boundary) throws {
        let defaults = context.defaults
        let favoriteKey = Import.Section.favorites.preferenceKey
        let libraryKey = Import.Section.library.preferenceKey
        let marker = "hue-board.native.setup-import-transaction.v1"
        let rawFavorites = defaults.stringArray(forKey: favoriteKey)
        let rawLibrary = defaults.data(forKey: libraryKey)
        // Sorted target keys place favorites before library; this raw view proves the mid-write
        // case reached disk before any ordinary reader enters the recovery gate.
        guard defaults.data(forKey: marker) != nil,
              rawFavorites == [boundary == .prepared ? "before" : "after"],
              rawLibrary == Data((boundary == .committed ? "after" : "before").utf8) else {
            throw Failure("The fresh process did not observe the selected durable checkpoint")
        }
        let expected = boundary == .committed ? "after" : "before"
        guard try Import.loadFavorites(defaults: defaults) == [expected],
              defaults.data(forKey: libraryKey) == Data(expected.utf8),
              defaults.object(forKey: marker) == nil,
              Self.protected.allSatisfy({ defaults.data(forKey: $0) == Data($0.utf8) }) else {
            throw Failure("Ordinary recovery failed to yield the complete expected state")
        }
        try context.mark("read", boundary)
    }

    #if os(macOS)
    private func xctestRunner() throws -> URL {
        if let executable = Bundle.main.executableURL, executable.lastPathComponent == "xctest" { return executable }
        let lookup = Process()
        lookup.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        lookup.arguments = ["--find", "xctest"]
        let output = Pipe()
        lookup.standardOutput = output
        try run(lookup, timeout: 20)
        let path = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard lookup.terminationStatus == 0, path.hasPrefix("/"), FileManager.default.isExecutableFile(atPath: path)
        else { throw Failure("The selected Xcode has no usable xctest runner") }
        return URL(fileURLWithPath: path)
    }
    #endif

    private func run(_ process: Process, timeout: Int) throws {
        let ended = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in ended.signal() }
        try process.run()
        guard ended.wait(timeout: .now() + .seconds(timeout)) == .success else {
            if process.isRunning { _ = kill(process.processIdentifier, SIGKILL) }
            throw Failure("The synthetic subprocess timed out")
        }
    }

    private struct Context {
        let id: UUID
        let suite: String
        let defaults: UserDefaults
        let directory: URL
        init(_ id: UUID) throws {
            self.id = id
            suite = "HueBoard.SetupProcessTest.\(id.uuidString)"
            guard let store = UserDefaults(suiteName: suite) else { throw Failure("Could not open isolated defaults") }
            defaults = store
            directory = FileManager.default.temporaryDirectory.appendingPathComponent(suite, isDirectory: true)
        }
        func witness(_ role: String) -> URL { directory.appendingPathComponent("\(role).checkpoint") }
        func mark(_ role: String, _ boundary: Boundary) throws {
            try "\(getpid()) \(boundary.rawValue)".write(to: witness(role), atomically: true, encoding: .utf8)
        }
    }

    private struct Failure: LocalizedError {
        let detail: String
        init(_ detail: String) { self.detail = detail }
        var errorDescription: String? { detail }
    }
}
#endif
