import ArgumentParser
import Foundation
import MakeDmgKit

struct BuildCommand: ParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(commandName: "build", abstract: "Build, sign and notarize a DMG.")
    }

    @OptionGroup var options: ConfigOptions

    @Option(name: [.short, .long], help: "Override the output path from config (relative to the current directory).")
    var output: String?

    @Flag(help: "Skip code signing even if configured.")
    var skipSign = false

    @Flag(help: "Skip notarization even if configured.")
    var skipNotarize = false

    @Flag(help: "Mount and open the result in Finder when done.")
    var open = false

    func run() throws {
        let (loaded, _) = try options.loadValidated()

        var buildOptions = BuildOptions(skipSign: skipSign, skipNotarize: skipNotarize)
        if let output {
            buildOptions.output = URL(fileURLWithPath: (output as NSString).expandingTildeInPath).standardizedFileURL
        }

        let builder = DMGBuilder(loaded: loaded, options: buildOptions, logger: ConsoleBuildLogger(verbose: options.verbose))
        let start = Date()
        let dmg: URL
        do {
            dmg = try builder.build()
        } catch {
            Console.error("\(error)")
            throw ExitCode.failure
        }

        let seconds = String(format: "%.1f", Date().timeIntervalSince(start))
        Console.success("\(dmg.path) (\(seconds)s)")

        if open {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            process.arguments = [dmg.path]
            try? process.run()
        }
    }
}
