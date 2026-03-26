import Foundation

protocol BackendControlServicing {
    func start() async throws
    func stop() async throws
    func restart() async throws
}

enum BackendControlServiceError: Error {
    case commandFailed(scriptPath: String, terminationStatus: Int32)
}

struct BackendControlService: BackendControlServicing {
    let commandRunner: any ShellCommandRunning

    init(commandRunner: any ShellCommandRunning = ShellCommandRunner()) {
        self.commandRunner = commandRunner
    }

    func start() async throws {
        try await runScript(at: "scripts/start_omlx_tmux.sh")
    }

    func stop() async throws {
        try await runScript(at: "scripts/stop_omlx.sh")
    }

    func restart() async throws {
        try await runScript(at: "scripts/restart_omlx.sh")
    }

    private func runScript(at path: String) async throws {
        let result = try await commandRunner.run(
            URL(fileURLWithPath: "/bin/zsh"),
            arguments: [path]
        )
        guard result.terminationStatus == 0 else {
            throw BackendControlServiceError.commandFailed(
                scriptPath: path,
                terminationStatus: result.terminationStatus
            )
        }
    }
}
