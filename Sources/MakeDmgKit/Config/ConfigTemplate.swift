import Foundation

/// Starter config written by `makedmg init`.
public enum ConfigTemplate {
    /// - Parameters:
    ///   - appPath: path as it should appear in the config (relative or absolute).
    ///   - volumeName: shown as the window title and volume name.
    public static func json(appPath: String, volumeName: String) -> String {
        let name = escape(volumeName)
        let fileStem = escape(volumeName.replacingOccurrences(of: " ", with: "-"))
        return """
        {
          "volumeName": "\(name)",
          "output": "build/\(fileStem).dmg",
          "format": "ULFO",
          "window": { "x": 200, "y": 120, "width": 600, "height": 400 },
          "icon": { "size": 128, "textSize": 16 },
          "background": { "color": "#F5F5F7" },
          "contents": [
            { "path": "\(escape(appPath))", "x": 150, "y": 150 },
            { "type": "applications", "x": 450, "y": 150 }
          ]
        }

        """
    }

    /// Path relative to the config folder when the app lives inside it, else absolute.
    public static func configPath(for app: URL, configDirectory: URL) -> String {
        let appPath = app.standardizedFileURL.path
        let base = configDirectory.standardizedFileURL.path
        let prefix = base.hasSuffix("/") ? base : base + "/"
        return appPath.hasPrefix(prefix) ? String(appPath.dropFirst(prefix.count)) : appPath
    }

    static func escape(_ string: String) -> String {
        string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
