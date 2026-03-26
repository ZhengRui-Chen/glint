import XCTest
@testable import Glint

final class BackendControlServiceTests: XCTestCase {
    func test_control_service_runs_start_script() async throws {
        let runner = RecordingCommandRunner()
        let service = BackendControlService(commandRunner: runner)

        try await service.start()
        let commands = await runner.commands

        XCTAssertEqual(commands, [["/bin/zsh", "scripts/start_omlx_tmux.sh"]])
    }

    func test_control_service_runs_stop_script() async throws {
        let runner = RecordingCommandRunner()
        let service = BackendControlService(commandRunner: runner)

        try await service.stop()
        let commands = await runner.commands

        XCTAssertEqual(commands, [["/bin/zsh", "scripts/stop_omlx.sh"]])
    }

    func test_control_service_runs_restart_script() async throws {
        let runner = RecordingCommandRunner()
        let service = BackendControlService(commandRunner: runner)

        try await service.restart()
        let commands = await runner.commands

        XCTAssertEqual(commands, [["/bin/zsh", "scripts/restart_omlx.sh"]])
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
