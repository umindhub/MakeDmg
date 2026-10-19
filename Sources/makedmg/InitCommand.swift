import ArgumentParser
import Foundation
import MakeDmgKit

struct InitCommand: ParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(commandName: "init", abstract: "Create a starter makedmg.json.")
    }

    @Option(help: "App bundle to put in the DMG.")
    var app: String?

    @Option(name: [.short, .long], help: "Config file to create.")
    var output = "makedmg.json"

    @Flag(help: "Overwrite an existing config file.")
    var force = false

    func run() throws {
        let configURL = URL(fileURLWithPath: (output as NSString).expandingTildeInPath).standardizedFileURL
        if FileManager.default.fileExists(atPath: configURL.path) && !force {
            Console.error("\(configURL.path) already exists (use --force to overwrite)")
            throw ExitCode.failure
        }

        var appPath = "build/MyApp.app"
        var volumeName = "MyApp"
        if let app {
            let appURL = URL(fileURLWithPath: (app as NSString).expandingTildeInPath).standardizedFileURL
            appPath = ConfigTemplate.configPath(for: appURL, configDirectory: configURL.deletingLastPathComponent())
            volumeName = appURL.deletingPathExtension().lastPathComponent
        }

        let json = ConfigTemplate.json(appPath: appPath, volumeName: volumeName)
        do {
            try FileManager.default.createDirectory(at: configURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try json.write(to: configURL, atomically: true, encoding: .utf8)
        } catch {
            Console.error("cannot write \(configURL.path): \(error.localizedDescription)")
            throw ExitCode.failure
        }

        Console.success("created \(configURL.path)")
        Console.info("""

        Next:
          makedmg preview -c \(output)    # check the layout as PNG
          makedmg build -c \(output)      # build the DMG
        Add "sign" and "notarize" to the config for distribution builds.
        """)
    }
}
