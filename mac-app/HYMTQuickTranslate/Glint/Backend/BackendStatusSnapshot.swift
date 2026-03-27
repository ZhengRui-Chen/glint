import Foundation

enum BackendStatusSnapshot: Equatable {
    case checking(detail: String = L10n.checkingBackendAvailability)
    case available(detail: String)
    case unavailable(detail: String)
    case error(detail: String)

    var headline: String {
        switch self {
        case .checking:
            L10n.serviceStatusChecking
        case .available:
            L10n.serviceStatusAvailable
        case .unavailable:
            L10n.serviceStatusUnavailable
        case .error:
            L10n.serviceStatusError
        }
    }

    var detail: String {
        switch self {
        case let .checking(detail),
             let .available(detail),
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

    var canRefreshStatus: Bool {
        switch self {
        case .checking:
            false
        case .available, .unavailable, .error:
            true
        }
    }
}
