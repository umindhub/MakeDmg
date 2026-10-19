import Foundation

/// Fatal problems that stop a config from loading at all.
public enum ConfigError: Error, Equatable, CustomStringConvertible, LocalizedError {
    case unreadable(path: String, reason: String)
    case invalidJSON(reason: String)
    case invalidValue(path: String, reason: String, notes: [String])

    public var description: String {
        switch self {
        case let .unreadable(path, reason):
            return "cannot read config \(path): \(reason)"
        case let .invalidJSON(reason):
            return "invalid JSON: \(reason)"
        case let .invalidValue(path, reason, notes):
            var text = path.isEmpty ? reason : "\(path): \(reason)"
            for note in notes {
                text += "\n  note: \(note)"
            }
            return text
        }
    }

    public var errorDescription: String? { description }

    /// Maps a DecodingError to a short message with a dotted JSON path.
    static func from(_ error: DecodingError, notes: [String]) -> ConfigError {
        switch error {
        case let .typeMismatch(type, ctx):
            return .invalidValue(path: ctx.codingPath.jsonPath, reason: "expected \(jsonTypeName(type))", notes: notes)
        case let .valueNotFound(type, ctx):
            return .invalidValue(path: ctx.codingPath.jsonPath, reason: "expected \(jsonTypeName(type)), found null", notes: notes)
        case let .keyNotFound(key, ctx):
            return .invalidValue(path: (ctx.codingPath + [key]).jsonPath, reason: "required key is missing", notes: notes)
        case let .dataCorrupted(ctx):
            return .invalidValue(path: ctx.codingPath.jsonPath, reason: ctx.debugDescription, notes: notes)
        @unknown default:
            return .invalidValue(path: "", reason: String(describing: error), notes: notes)
        }
    }

    private static func jsonTypeName(_ type: Any.Type) -> String {
        switch type {
        case is Int.Type, is Double.Type: return "a number"
        case is String.Type: return "a string"
        case is Bool.Type: return "true or false"
        case is [Any].Type: return "an array"
        default:
            let name = String(describing: type)
            return name.hasPrefix("Array") ? "an array" : "an object"
        }
    }
}

extension Array where Element == any CodingKey {
    /// "contents[1].x" style path.
    var jsonPath: String {
        var result = ""
        for key in self {
            if let index = key.intValue {
                result += "[\(index)]"
            } else {
                result += result.isEmpty ? key.stringValue : ".\(key.stringValue)"
            }
        }
        return result
    }
}
