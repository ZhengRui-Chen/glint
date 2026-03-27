import Foundation

enum BackendStatusSnapshot: Equatable {
    case notChecked(
        detail: String = String(
            localized: "Backend status has not been checked yet",
            comment: "Backend status detail before the first explicit status check"
        )
    )
    case checking(detail: String = L10n.checkingBackendAvailability)
    case available(detail: String)
    case starting(detail: String)
    case unavailable(detail: String)
    case error(detail: String)

    var headline: String {
        switch self {
        case .notChecked:
            String(
                localized: "Service Status: Not Checked",
                comment: "Backend status headline before the first explicit status check"
            )
        case .checking:
            L10n.serviceStatusChecking
        case .available:
            L10n.serviceStatusAvailable
        case .starting:
            L10n.serviceStatusStarting
        case .unavailable:
            L10n.serviceStatusUnavailable
        case .error:
            L10n.serviceStatusError
        }
    }

    var detail: String {
        switch self {
        case let .notChecked(detail),
             let .checking(detail),
             let .available(detail),
             let .starting(detail),
             let .unavailable(detail),
             let .error(detail):
            detail
        }
    }

    var canTranslate: Bool {
        if case .available = self {
            return true
        }
        return false
    }

    var canStartService: Bool {
        switch self {
        case .notChecked:
            true
        case .available, .starting, .checking:
            false
        case .unavailable, .error:
            true
        }
    }

    var canStopService: Bool {
        switch self {
        case .available, .starting:
            true
        case .notChecked, .checking, .unavailable, .error:
            false
        }
    }

    var canRestartService: Bool {
        switch self {
        case .notChecked, .starting, .checking:
            false
        case .available, .unavailable, .error:
            true
        }
    }

    var canRefreshStatus: Bool {
        switch self {
        case .starting, .checking:
            false
        case .notChecked, .available, .unavailable, .error:
            true
        }
    }
}
