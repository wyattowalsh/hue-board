import Foundation
import HueBoardKit
import Observation

struct RoomDiscoveryScope: Hashable {
    let bridgeID: String
    let areaID: HueResourceID
    let fixtureIDs: Set<HueResourceID>
    let revision: UInt64
}

@MainActor
@Observable
final class RoomDiscoverySession {
    enum State: Equatable {
        case idle
        case loading
        case loaded(HueRoomDiscovery)
        case failed(String)
    }

    private(set) var state = State.idle
    private(set) var scope: RoomDiscoveryScope?
    private var revision = 0
    private var generation: UInt64 = 0

    func invalidate() {
        generation &+= 1
        scope = nil
        state = .idle
    }

    func read(
        scope next: RoomDiscoveryScope?,
        revision nextRevision: Int,
        using fetch: @MainActor (RoomDiscoveryScope) async throws -> HueRoomDiscovery
    ) async {
        guard !Task.isCancelled else { return }
        guard let next else { invalidate(); return }
        guard next != scope || nextRevision != revision || state == .idle else { return }
        generation &+= 1
        let current = generation
        scope = next
        revision = nextRevision
        state = .loading
        do {
            let result = try await fetch(next)
            try Task.checkCancellation()
            guard generation == current else { return }
            state = .loaded(result)
        } catch {
            guard generation == current else { return }
            if Task.isCancelled || error is CancellationError {
                invalidate()
            } else {
                state = .failed(error.localizedDescription)
            }
        }
    }
}
