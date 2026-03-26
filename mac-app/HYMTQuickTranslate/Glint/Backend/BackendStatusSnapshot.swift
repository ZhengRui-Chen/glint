import Foundation

enum BackendStatusSnapshot: Equatable {
    case checking(detail: String = "Checking backend availability")
    case available(detail: String)
    case starting(detail: String)
    case unavailable(detail: String)
    case error(detail: String)

    var headline: String {
        switch self {
        case .checking:
            "Service Status: Checking..."
        case .available:
            "Service Status: Available"
        case .starting:
            "Service Status: Starting"
        case .unavailable:
            "Service Status: Unavailable"
        case .error:
            "Service Status: Error"
        }
    }

    var detail: String {
        switch self {
        case let .checking(detail),
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
        case .checking, .unavailable, .error:
            false
        }
    }

    var canRestartService: Bool {
        switch self {
        case .starting, .checking:
            false
        case .available, .unavailable, .error:
            true
        }
    }

    var canRefreshStatus: Bool {
        switch self {
        case .starting, .checking:
            false
        case .available, .unavailable, .error:
            true
        }
    }
}
