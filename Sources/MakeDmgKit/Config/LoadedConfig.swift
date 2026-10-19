import Foundation

/// A decoded config plus where it came from, for resolving relative paths.
public struct LoadedConfig: Sendable {
    public let config: DMGConfig
    public let fileURL: URL
    /// Non-fatal findings from loading, e.g. unknown keys.
    public let loadIssues: [ConfigIssue]

    public var baseURL: URL { fileURL.deletingLastPathComponent() }

    /// Resolves a config path: "~" expands, relative paths are relative to the config file.
    public func resolve(_ path: String) -> URL {
        let expanded = (path as NSString).expandingTildeInPath
        if expanded.hasPrefix("/") {
            return URL(fileURLWithPath: expanded).standardizedFileURL
        }
        return URL(fileURLWithPath: expanded, relativeTo: baseURL).absoluteURL.standardizedFileURL
    }
}
