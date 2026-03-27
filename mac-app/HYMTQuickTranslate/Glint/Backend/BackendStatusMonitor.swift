import Foundation

enum BackendActionKind: Equatable {
    case start
    case restart
}

struct BackendActionContext: Equatable {
    let action: BackendActionKind
    let requestedAt: Date
}

enum BackendStatusMonitorError: Error {
    case processCheckFailed
}

struct BackendStatusMonitor {
    let apiChecker: any BackendAPIHealthChecking
    let processChecker: any BackendProcessChecking
    let now: () -> Date
    let startupGracePeriod: TimeInterval

    init(
        apiChecker: any BackendAPIHealthChecking = BackendAPIHealthChecker(),
        processChecker: any BackendProcessChecking = BackendProcessChecker(),
        now: @escaping () -> Date = Date.init,
        startupGracePeriod: TimeInterval = 15
    ) {
        self.apiChecker = apiChecker
        self.processChecker = processChecker
        self.now = now
        self.startupGracePeriod = startupGracePeriod
    }

    func refresh(
        actionContext: BackendActionContext? = nil
    ) async -> BackendStatusSnapshot {
        do {
            let apiReachability = try await apiChecker.checkAPIReachability()
            if apiReachability == .reachable {
                return .available(detail: L10n.backendReachable)
            }

            let isProcessRunning = try await processChecker.isBackendProcessRunning()
            if isStarting(actionContext: actionContext, isProcessRunning: isProcessRunning) {
                return .starting(detail: L10n.backendStartingPleaseWait)
            }

            return .unavailable(detail: L10n.backendCurrentlyUnavailable)
        } catch {
            return .error(detail: L10n.unableVerifyBackendStatus)
        }
    }

    private func isStarting(
        actionContext: BackendActionContext?,
        isProcessRunning: Bool
    ) -> Bool {
        guard isProcessRunning, let actionContext else {
            return false
        }
        guard actionContext.action == .start || actionContext.action == .restart else {
            return false
        }
        return now().timeIntervalSince(actionContext.requestedAt) <= startupGracePeriod
    }
}
