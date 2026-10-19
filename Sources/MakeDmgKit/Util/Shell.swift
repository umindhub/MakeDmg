import Foundation

/// Progress sink for long-running work; the CLI supplies a console implementation.
public protocol BuildLogger: Sendable {
    /// A major step, always shown.
    func step(_ message: String)
    /// Extra detail, shown with --verbose.
    func detail(_ message: String)
    func warning(_ message: String)
}

public struct CommandResult: Sendable {
    public let status: Int32
    public let stdout: String
    public let stderr: String

    /// stderr if present, otherwise stdout, trimmed.
    public var output: String {
        let err = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        return err.isEmpty ? stdout.trimmingCharacters(in: .whitespacesAndNewlines) : err
    }
}

public enum ShellError: Error, CustomStringConvertible {
    case launchFailed(command: String, reason: String)
    case failed(command: String, status: Int32, output: String)

    public var description: String {
        switch self {
        case let .launchFailed(command, reason):
            return "cannot run \(command): \(reason)"
        case let .failed(command, status, output):
            let detail = output.isEmpty ? "" : "\n\(output)"
            return "\(command) exited with status \(status)\(detail)"
        }
    }
}

/// Runs external tools synchronously, capturing output via temp files (no pipe deadlocks).
public struct Shell: Sendable {
    let logger: (any BuildLogger)?

    public init(logger: (any BuildLogger)?) {
        self.logger = logger
    }

    @discardableResult
    public func run(_ executable: String, _ arguments: [String], allowFailure: Bool = false) throws -> CommandResult {
        let display = ([executable] + arguments).map(Self.quote).joined(separator: " ")
        logger?.detail("$ \(display)")

        let fm = FileManager.default
        let tmp = fm.temporaryDirectory
        let outURL = tmp.appendingPathComponent("makedmg-out-\(UUID().uuidString)")
        let errURL = tmp.appendingPathComponent("makedmg-err-\(UUID().uuidString)")
        fm.createFile(atPath: outURL.path, contents: nil)
        fm.createFile(atPath: errURL.path, contents: nil)
        defer {
            try? fm.removeItem(at: outURL)
            try? fm.removeItem(at: errURL)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        do {
            let outHandle = try FileHandle(forWritingTo: outURL)
            let errHandle = try FileHandle(forWritingTo: errURL)
            defer {
                try? outHandle.close()
                try? errHandle.close()
            }
            process.standardOutput = outHandle
            process.standardError = errHandle
            process.standardInput = FileHandle.nullDevice
            try process.run()
            process.waitUntilExit()
        } catch {
            throw ShellError.launchFailed(command: executable, reason: error.localizedDescription)
        }

        let result = CommandResult(
            status: process.terminationStatus,
            stdout: (try? String(contentsOf: outURL, encoding: .utf8)) ?? "",
            stderr: (try? String(contentsOf: errURL, encoding: .utf8)) ?? ""
        )
        if result.status != 0 && !allowFailure {
            throw ShellError.failed(command: (executable as NSString).lastPathComponent, status: result.status, output: result.output)
        }
        return result
    }

    static func quote(_ arg: String) -> String {
        guard !arg.isEmpty else { return "''" }
        let safe = arg.allSatisfy { $0.isLetter || $0.isNumber || "-_./=:@+,".contains($0) }
        return safe ? arg : "'" + arg.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
