import Foundation

enum BackendActionKind: Equatable, Sendable {
    case start
    case restart
}

struct BackendActionContext: Equatable, Sendable {
    let action: BackendActionKind
    let requestedAt: Date
}

enum BackendStatusMonitorError: Error {
    case processCheckFailed
}

struct BackendStatusMonitor: Sendable {
    let apiChecker: any BackendAPIHealthChecking
    let processChecker: any BackendProcessChecking
    let now: @Sendable () -> Date
    let startupGracePeriod: TimeInterval
    let checksProcessWhenAPIIsUnreachable: Bool

    init(
        apiChecker: any BackendAPIHealthChecking = BackendAPIHealthChecker(),
        processChecker: any BackendProcessChecking = BackendProcessChecker(),
        now: @escaping @Sendable () -> Date = Date.init,
        startupGracePeriod: TimeInterval = 15,
        checksProcessWhenAPIIsUnreachable: Bool = true
    ) {
        self.apiChecker = apiChecker
        self.processChecker = processChecker
        self.now = now
        self.startupGracePeriod = startupGracePeriod
        self.checksProcessWhenAPIIsUnreachable = checksProcessWhenAPIIsUnreachable
    }

    func refresh(
        actionContext: BackendActionContext? = nil
    ) async -> BackendStatusSnapshot {
        do {
            let apiReachability = try await apiChecker.checkAPIReachability()
            if apiReachability == .reachable {
                return .available(detail: L10n.backendReachable)
            }

            return .unavailable(detail: L10n.backendCurrentlyUnavailable)
        } catch {
            return .error(detail: L10n.unableVerifyBackendStatus)
        }
    }
}
