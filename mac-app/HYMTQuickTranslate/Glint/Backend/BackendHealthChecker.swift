import Foundation

enum BackendAPIReachability: Equatable {
    case reachable
    case unreachable
}

protocol BackendAPIHealthChecking: Sendable {
    func checkAPIReachability() async throws -> BackendAPIReachability
}

protocol BackendProcessChecking: Sendable {
    func isBackendProcessRunning() async throws -> Bool
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
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        return (200 ..< 300).contains(httpResponse.statusCode) ? .reachable : .unreachable
    }
}

struct BackendProcessChecker: BackendProcessChecking {
    let commandRunner: ShellCommandRunning
    let processPattern: String

    init(
        commandRunner: ShellCommandRunning = ShellCommandRunner(),
        processPattern: String = "omlx serve --model-dir"
    ) {
        self.commandRunner = commandRunner
        self.processPattern = processPattern
    }

    func isBackendProcessRunning() async throws -> Bool {
        let result = try await commandRunner.run(
            URL(fileURLWithPath: "/usr/bin/pgrep"),
            arguments: ["-f", processPattern]
        )
        switch result.terminationStatus {
        case 0:
            return true
        case 1:
            return false
        default:
            throw BackendStatusMonitorError.processCheckFailed
        }
    }
}

struct StaticBackendProcessChecker: BackendProcessChecking {
    let isRunning: Bool

    func isBackendProcessRunning() async throws -> Bool {
        isRunning
    }
}
