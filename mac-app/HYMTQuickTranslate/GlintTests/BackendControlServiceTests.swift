import XCTest
@testable import Glint

final class BackendControlServiceTests: XCTestCase {
    func test_control_service_runs_start_script() async throws {
        let runner = RecordingCommandRunner()
        let service = BackendControlService(commandRunner: runner)

        try await service.start()
        let commands = await runner.commands

        XCTAssertEqual(
            commands,
            [["/bin/zsh", backendScriptsDirectoryURL().appending(path: "start_omlx_tmux.sh").path]]
        )
    }

    func test_control_service_runs_stop_script() async throws {
        let runner = RecordingCommandRunner()
        let service = BackendControlService(commandRunner: runner)

        try await service.stop()
        let commands = await runner.commands

        XCTAssertEqual(
            commands,
            [["/bin/zsh", backendScriptsDirectoryURL().appending(path: "stop_omlx.sh").path]]
        )
    }

    func test_control_service_runs_restart_script() async throws {
        let runner = RecordingCommandRunner()
        let service = BackendControlService(commandRunner: runner)

        try await service.restart()
        let commands = await runner.commands

        XCTAssertEqual(
            commands,
            [["/bin/zsh", backendScriptsDirectoryURL().appending(path: "restart_omlx.sh").path]]
        )
    }
}

private actor RecordingCommandRunner: ShellCommandRunning {
    private(set) var commands: [[String]] = []

    func run(_ executableURL: URL, arguments: [String]) async throws -> ShellCommandResult {
        commands.append([executableURL.path] + arguments)
        return ShellCommandResult(
            terminationStatus: 0,
            standardOutput: "",
            standardError: ""
        )
    }
}

private func backendScriptsDirectoryURL() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appending(path: "scripts", directoryHint: .isDirectory)
}
