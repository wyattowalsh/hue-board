@preconcurrency import BackgroundTasks
import Foundation

final class ContinuedLiveCoordinator: @unchecked Sendable {
    static let shared = ContinuedLiveCoordinator()
    static let identifier = "com.wyattowalsh.HueBoard.live"
    typealias ProgressUpdate = @Sendable (_ fraction: Double, _ subtitle: String) -> Void
    typealias Work = @Sendable (_ update: @escaping ProgressUpdate) async throws -> Void
    private struct PendingWork { let work: Work }
    private final class RunningLease: @unchecked Sendable {
        private let lock = NSLock(); private var task: Task<Void, Never>?; private var cancelled = false
        func install(_ task: Task<Void, Never>) { if lock.withLock({ if cancelled { return true }; self.task = task; return false }) { task.cancel() } }
        func cancel() { lock.withLock { cancelled = true; return task }?.cancel() }
    }
    private let lock = NSLock(); private var pending: PendingWork?; private var running: RunningLease?; private var registered = false
    private init() {}
    func register() {
        let shouldRegister = lock.withLock { guard !registered else { return false }; registered = true; return true }
        guard shouldRegister else { return }
        if #available(iOS 26.0, *) {
            BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.identifier, using: nil) { [weak self] task in
                guard let task = task as? BGContinuedProcessingTask else { task.setTaskCompleted(success: false); return }
                self?.launch(task)
            }
        }
    }
    @available(iOS 26.0, *)
    func submit(title: String, subtitle: String, work: @escaping Work) throws {
        try lock.withLock { guard pending == nil, running == nil else { throw ContinuedLiveCoordinatorError.busy }; pending = PendingWork(work: work) }
        let request = BGContinuedProcessingTaskRequest(identifier: Self.identifier, title: title, subtitle: subtitle)
        request.strategy = .fail
        do { try BGTaskScheduler.shared.submit(request) } catch { lock.withLock { pending = nil }; throw error }
    }
    func cancel() {
        let lease = lock.withLock { pending = nil; let value = running; running = nil; return value }
        lease?.cancel(); BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.identifier)
    }
    @available(iOS 26.0, *)
    private func launch(_ backgroundTask: BGContinuedProcessingTask) {
        let pair = lock.withLock { () -> (PendingWork, RunningLease)? in
            guard running == nil, let pending else { return nil }; let lease = RunningLease(); self.pending = nil; running = lease; return (pending, lease)
        }
        guard let (pending, lease) = pair else { backgroundTask.setTaskCompleted(success: false); return }
        backgroundTask.progress.totalUnitCount = 1_000
        let task = Task { [weak self, lease] in
            let success: Bool
            do {
                try await pending.work { fraction, subtitle in
                    backgroundTask.progress.completedUnitCount = Int64(max(0, min(1, fraction)) * 1_000)
                    backgroundTask.updateTitle(backgroundTask.title, subtitle: subtitle)
                }
                try Task.checkCancellation(); backgroundTask.progress.completedUnitCount = 1_000; success = true
            } catch { success = false }
            backgroundTask.setTaskCompleted(success: success); self?.finish(lease)
        }
        lease.install(task); backgroundTask.expirationHandler = { lease.cancel() }
    }
    private func finish(_ lease: RunningLease) { lock.withLock { if running === lease { running = nil } } }
}

enum ContinuedLiveCoordinatorError: Error, LocalizedError {
    case busy
    var errorDescription: String? { "A continued Ambient Live request is already pending or running." }
}

private extension NSLock {
    func withLock<T>(_ body: () throws -> T) rethrows -> T { lock(); defer { unlock() }; return try body() }
}
