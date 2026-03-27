import Foundation

enum BackendAPIReachability: Equatable {
    case reachable
    case unreachable
}

protocol BackendAPIHealthChecking {
    func checkAPIReachability() async throws -> BackendAPIReachability
}

struct BackendAPIHealthChecker: BackendAPIHealthChecking {
    let urlSession: URLSession
    private let configProvider: @Sendable () -> AppConfig

    init(
        urlSession: URLSession = .shared,
        configProvider: @escaping @Sendable () -> AppConfig = { AppConfig.default }
    ) {
        self.urlSession = urlSession
        self.configProvider = configProvider
    }

    init(
        urlSession: URLSession = .shared,
        config: AppConfig
    ) {
        self.urlSession = urlSession
        configProvider = { config }
    }

    func checkAPIReachability() async throws -> BackendAPIReachability {
        let config = configProvider()
        var request = URLRequest(url: config.backendModelsURL)
        request.timeoutInterval = config.backendAPITimeout
        if !config.apiKey.isEmpty {
            request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        }

        let (_, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        return (200 ..< 300).contains(httpResponse.statusCode) ? .reachable : .unreachable
    }
}
