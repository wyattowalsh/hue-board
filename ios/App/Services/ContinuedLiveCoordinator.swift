@preconcurrency import BackgroundTasks
import Foundation

final class ContinuedLiveCoordinator: @unchecked Sendable {
    static let shared = ContinuedLiveCoordinator()
    static let identifier = "com.wyattowalsh.HueBoard.live"

    typealias ProgressUpdate = @Sendable (_ fraction: Double, _ subtitle: String) -> Void
    typealias Work = @Sendable (_ update: @escaping ProgressUpdate) async throws -> Void

    private let lock = NSLock()
    private var pending: Work?
    private var running: Task<Void, Never>?
    private var registered = false

    private init() {}

    func register() {
        guard !registered else { return }
        registered = true
        if #available(iOS 26.0, *) {
            BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.identifier, using: nil) { [weak self] task in
                guard let task = task as? BGContinuedProcessingTask else {
                    task.setTaskCompleted(success: false)
                    return
                }
                self?.launch(task)
            }
        }
    }

    @available(iOS 26.0, *)
    func submit(title: String, subtitle: String, work: @escaping Work) throws {
        lock.withLock { pending = work }
        let request = BGContinuedProcessingTaskRequest(
            identifier: Self.identifier,
            title: title,
            subtitle: subtitle
        )
        request.strategy = .fail
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            lock.withLock { pending = nil }
            throw error
        }
    }

    func cancel() {
        let task = lock.withLock { () -> Task<Void, Never>? in
            let task = running
            running = nil
            pending = nil
            return task
        }
        task?.cancel()
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.identifier)
    }

    @available(iOS 26.0, *)
    private func launch(_ backgroundTask: BGContinuedProcessingTask) {
        guard let work = lock.withLock({ pending }) else {
            backgroundTask.setTaskCompleted(success: false)
            return
        }
        backgroundTask.progress.totalUnitCount = 1_000
        let task = Task { [weak self] in
            do {
                try await work { fraction, subtitle in
                    backgroundTask.progress.completedUnitCount = Int64(max(0, min(1, fraction)) * 1_000)
                    backgroundTask.updateTitle(backgroundTask.title, subtitle: subtitle)
                }
                backgroundTask.progress.completedUnitCount = 1_000
                backgroundTask.setTaskCompleted(success: true)
            } catch {
                backgroundTask.setTaskCompleted(success: false)
            }
            if let self {
                self.lock.withLock {
                    self.pending = nil
                    self.running = nil
                }
            }
        }
        lock.withLock { running = task }
        backgroundTask.expirationHandler = { task.cancel() }
    }
}

private extension NSLock {
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}
