import Foundation
import MakeDmgKit

/// Terminal output: diagnostics to stderr, results to stdout, ANSI color on a TTY.
enum Console {
    static let colorEnabled: Bool =
        isatty(STDERR_FILENO) == 1 && ProcessInfo.processInfo.environment["NO_COLOR"] == nil

    static func error(_ message: String) {
        writeErr("\(paint("error:", "1;31")) \(message)")
    }

    static func warning(_ message: String) {
        writeErr("\(paint("warning:", "1;33")) \(message)")
    }

    static func info(_ message: String) {
        print(message)
    }

    static func step(_ message: String) {
        print("\(paint("==>", "1;34")) \(message)")
    }

    static func success(_ message: String) {
        print("\(paint("✓", "1;32")) \(message)")
    }

    static func report(_ issues: [ConfigIssue]) {
        for issue in issues {
            switch issue.severity {
            case .error: error(issue.description)
            case .warning: warning(issue.description)
            }
        }
    }

    private static func paint(_ text: String, _ code: String) -> String {
        colorEnabled ? "\u{1B}[\(code)m\(text)\u{1B}[0m" : text
    }

    private static func writeErr(_ line: String) {
        FileHandle.standardError.write(Data((line + "\n").utf8))
    }
}
