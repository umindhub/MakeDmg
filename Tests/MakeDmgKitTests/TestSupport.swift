import Foundation
@testable import MakeDmgKit

typealias JSON = [String: Any]

/// Gives heterogeneous array literals a concrete type.
func items(_ list: [JSON]) -> [JSON] { list }

/// Minimal valid config as a mutable dictionary.
func minimalConfig() -> JSON {
    [
        "volumeName": "MyApp",
        "output": "build/MyApp.dmg",
        "contents": items([
            ["path": "MyApp.app", "x": 160, "y": 200],
            ["type": "applications", "x": 480, "y": 200],
        ]),
    ]
}

let fakeBase = URL(fileURLWithPath: "/Users/test/project", isDirectory: true)

func load(_ dict: [String: Any], base: URL = fakeBase) throws -> LoadedConfig {
    let data = try JSONSerialization.data(withJSONObject: dict)
    return try ConfigLoader.load(data: data, fileURL: base.appendingPathComponent("makedmg.json"))
}

func loadError(_ dict: [String: Any]) -> ConfigError? {
    do {
        _ = try load(dict)
        return nil
    } catch let error as ConfigError {
        return error
    } catch {
        return nil
    }
}

func hasIssue(_ issues: [ConfigIssue], _ severity: ConfigIssue.Severity, _ path: String) -> Bool {
    issues.contains { $0.severity == severity && $0.path == path }
}

/// Throwaway directory for tests that touch the file system.
struct TempDir {
    let url: URL

    init() throws {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("makedmg-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    func makeDirectory(_ relativePath: String) throws {
        try FileManager.default.createDirectory(
            at: url.appendingPathComponent(relativePath), withIntermediateDirectories: true)
    }

    func makeFile(_ relativePath: String) throws {
        let fileURL = url.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data().write(to: fileURL)
    }

    func remove() {
        try? FileManager.default.removeItem(at: url)
    }
}

extension Data {
    var hexString: String { map { String(format: "%02x", Int($0)) }.joined() }
}
