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
        try await runScript(named: "start_omlx_tmux.sh")
    }

    func stop() async throws {
        try await runScript(named: "stop_omlx.sh")
    }

    func restart() async throws {
        try await runScript(named: "restart_omlx.sh")
    }

    private func runScript(named scriptName: String) async throws {
        let scriptPath = Self.scriptsDirectoryURL
            .appending(path: scriptName, directoryHint: .notDirectory)
            .path
        let result = try await commandRunner.run(
            URL(fileURLWithPath: "/bin/zsh"),
            arguments: [scriptPath]
        )
        guard result.terminationStatus == 0 else {
            throw BackendControlServiceError.commandFailed(
                scriptPath: scriptPath,
                terminationStatus: result.terminationStatus
            )
        }
    }

    private static let scriptsDirectoryURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appending(path: "scripts", directoryHint: .isDirectory)
}
