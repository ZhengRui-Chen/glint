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
    let config: AppConfig

    init(
        urlSession: URLSession = .shared,
        config: AppConfig = .default
    ) {
        self.urlSession = urlSession
        self.config = config
    }

    func checkAPIReachability() async throws -> BackendAPIReachability {
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
