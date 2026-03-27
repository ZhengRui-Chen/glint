import Foundation

protocol ShellCommandRunning: Sendable {
    func run(_ executableURL: URL, arguments: [String]) async throws -> ShellCommandResult
}

struct ShellCommandResult: Equatable {
    let terminationStatus: Int32
    let standardOutput: String
    let standardError: String
}

struct ShellCommandRunner: ShellCommandRunning {
    func run(_ executableURL: URL, arguments: [String]) async throws -> ShellCommandResult {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let standardOutput = Pipe()
            let standardError = Pipe()

            process.executableURL = executableURL
            process.arguments = arguments
            process.standardOutput = standardOutput
            process.standardError = standardError
            process.terminationHandler = { process in
                let outputData = standardOutput.fileHandleForReading.readDataToEndOfFile()
                let errorData = standardError.fileHandleForReading.readDataToEndOfFile()
                let result = ShellCommandResult(
                    terminationStatus: process.terminationStatus,
                    standardOutput: String(decoding: outputData, as: UTF8.self),
                    standardError: String(decoding: errorData, as: UTF8.self)
                )
                continuation.resume(returning: result)
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
