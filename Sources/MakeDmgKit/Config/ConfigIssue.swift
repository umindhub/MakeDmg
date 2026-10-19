/// A validation finding tied to a JSON path like "contents[1].x".
public struct ConfigIssue: Sendable, Equatable, CustomStringConvertible {
    public enum Severity: Sendable, Equatable {
        case error
        case warning
    }

    public let severity: Severity
    public let path: String
    public let message: String

    public init(_ severity: Severity, _ path: String, _ message: String) {
        self.severity = severity
        self.path = path
        self.message = message
    }

    public static func error(_ path: String, _ message: String) -> ConfigIssue {
        ConfigIssue(.error, path, message)
    }

    public static func warning(_ path: String, _ message: String) -> ConfigIssue {
        ConfigIssue(.warning, path, message)
    }

    public var description: String {
        path.isEmpty ? message : "\(path): \(message)"
    }
}

extension Array where Element == ConfigIssue {
    public var errors: [ConfigIssue] { filter { $0.severity == .error } }
    public var warnings: [ConfigIssue] { filter { $0.severity == .warning } }
}
