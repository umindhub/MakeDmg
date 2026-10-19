import ArgumentParser
import MakeDmgKit

/// Async root so subcommands like preview can hop to the main actor.
@main
struct MakeDmg: AsyncParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: AppInfo.name,
            abstract: "Build styled DMG images from a JSON config, without Finder.",
            version: AppInfo.version,
            subcommands: [InitCommand.self, BuildCommand.self, PreviewCommand.self, ValidateCommand.self, InspectCommand.self]
        )
    }
}
