import ArgumentParser
import Foundation
import MakeDmgKit

/// Options shared by all subcommands.
struct ConfigOptions: ParsableArguments {
    @Option(name: [.short, .long], help: "Path to the JSON config file.")
    var config: String

    @Flag(name: .shortAndLong, help: "Print detailed progress.")
    var verbose = false

    var configURL: URL {
        URL(fileURLWithPath: (config as NSString).expandingTildeInPath).standardizedFileURL
    }

    mutating func validate() throws {
        guard FileManager.default.fileExists(atPath: configURL.path) else {
            throw ValidationError("Config file not found: \(configURL.path)")
        }
    }

    /// Loads and validates the config, printing issues. Throws on errors.
    func loadValidated(strict: Bool = false) throws -> (config: LoadedConfig, issues: [ConfigIssue]) {
        let loaded: LoadedConfig
        do {
            loaded = try ConfigLoader.load(from: configURL)
        } catch let error as ConfigError {
            Console.error(error.description)
            throw ExitCode.failure
        }

        if verbose {
            Console.info("config: \(loaded.fileURL.path)")
            Console.info("base:   \(loaded.baseURL.path)")
        }

        let issues = loaded.loadIssues + ConfigValidator().validate(loaded)
        Console.report(issues)

        let errorCount = issues.errors.count
        let warningCount = issues.warnings.count
        if errorCount > 0 || (strict && warningCount > 0) {
            let suffix = strict && errorCount == 0 ? " (--strict)" : ""
            Console.error("config has \(errorCount) error(s), \(warningCount) warning(s)\(suffix)")
            throw ExitCode.failure
        }
        return (loaded, issues)
    }
}

/// Placeholder error until a command is implemented.
struct NotImplemented: Error, CustomStringConvertible {
    let command: String
    init(_ command: String) { self.command = command }
    var description: String { "'\(command)' is not implemented yet." }
}
