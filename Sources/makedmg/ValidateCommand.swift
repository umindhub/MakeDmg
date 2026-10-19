import ArgumentParser
import MakeDmgKit

struct ValidateCommand: ParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(commandName: "validate", abstract: "Check a config file for errors and warnings.")
    }

    @OptionGroup var options: ConfigOptions

    @Flag(help: "Treat warnings as errors.")
    var strict = false

    func run() throws {
        let (_, issues) = try options.loadValidated(strict: strict)
        let warningCount = issues.warnings.count
        if warningCount == 0 {
            Console.success("config is valid")
        } else {
            Console.success("config is valid with \(warningCount) warning(s)")
        }
    }
}
