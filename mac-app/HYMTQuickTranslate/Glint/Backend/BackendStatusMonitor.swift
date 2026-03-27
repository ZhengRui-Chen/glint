import Foundation

struct BackendStatusMonitor {
    let apiChecker: any BackendAPIHealthChecking

    init(
        apiChecker: any BackendAPIHealthChecking = BackendAPIHealthChecker()
    ) {
        self.apiChecker = apiChecker
    }

    func refresh() async -> BackendStatusSnapshot {
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
