import Foundation

struct BackendStatusMonitor {
    private let configProvider: @Sendable () -> AppConfig
    let apiChecker: any BackendAPIHealthChecking

    init(
        configProvider: @escaping @Sendable () -> AppConfig = { AppConfig.default },
        apiChecker: any BackendAPIHealthChecking = BackendAPIHealthChecker()
    ) {
        self.configProvider = configProvider
        self.apiChecker = apiChecker
    }

    func refresh() async -> BackendStatusSnapshot {
        if configProvider().provider == .system {
            return .system(detail: L10n.systemTranslationReady)
        }

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
