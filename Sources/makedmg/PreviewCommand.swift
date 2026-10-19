import ArgumentParser
import Foundation
import MakeDmgKit

enum AppearanceChoice: String, CaseIterable, ExpressibleByArgument {
    case light, dark, both
}

struct PreviewCommand: AsyncParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "preview",
            abstract: "Render the window layout to a PNG without building.",
            discussion: "With --appearance both, writes <name>-light.png and <name>-dark.png."
        )
    }

    @OptionGroup var options: ConfigOptions

    @Option(name: [.short, .long], help: "Output PNG path.")
    var output = "preview.png"

    @Option(help: "System appearance to simulate: light, dark, both.")
    var appearance: AppearanceChoice = .both

    @Option(help: "Finder title bar + tab bar height in points (default: 68 on macOS 26, 28 before).")
    var chromeHeight: Int?

    @Option(help: "Window corner radius in points (default: 16 on macOS 26, 10 before).")
    var cornerRadius: Double?

    func run() async throws {
        let (loaded, _) = try options.loadValidated()
        let renderer = PreviewRenderer(
            loaded: loaded,
            chromeHeight: chromeHeight ?? PreviewRenderer.defaultChromeHeight,
            cornerRadius: cornerRadius.map { CGFloat($0) } ?? PreviewRenderer.defaultCornerRadius
        )

        let base = URL(fileURLWithPath: (output as NSString).expandingTildeInPath).standardizedFileURL
        let targets: [(PreviewRenderer.Appearance, URL)]
        switch appearance {
        case .light: targets = [(.light, base)]
        case .dark: targets = [(.dark, base)]
        case .both:
            let stem = base.deletingPathExtension().lastPathComponent
            let dir = base.deletingLastPathComponent()
            targets = [
                (.light, dir.appendingPathComponent("\(stem)-light.png")),
                (.dark, dir.appendingPathComponent("\(stem)-dark.png")),
            ]
        }

        for (mode, url) in targets {
            let png: Data
            do {
                png = try await MainActor.run { try renderer.render(mode) }
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try png.write(to: url)
            } catch {
                Console.error("\(error)")
                throw ExitCode.failure
            }
            Console.success("\(mode.rawValue): \(url.path)")
        }
    }
}
