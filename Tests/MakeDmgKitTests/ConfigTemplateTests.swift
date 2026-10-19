import Foundation
import Testing
@testable import MakeDmgKit

@Suite struct ConfigTemplateTests {
    @Test func templateLoadsWithoutIssues() throws {
        let json = ConfigTemplate.json(appPath: "build/My \"Quoted\" App.app", volumeName: "My App")
        let loaded = try ConfigLoader.load(data: Data(json.utf8), fileURL: fakeBase.appendingPathComponent("makedmg.json"))
        #expect(loaded.loadIssues.isEmpty)
        #expect(loaded.config.volumeName == "My App")
        #expect(loaded.config.output == "build/My-App.dmg")
        #expect(loaded.config.contents[0].kind == .file(path: "build/My \"Quoted\" App.app"))
    }

    @Test func pathIsRelativeInsideConfigFolder() {
        let dir = URL(fileURLWithPath: "/Users/test/project")
        #expect(ConfigTemplate.configPath(for: URL(fileURLWithPath: "/Users/test/project/build/A.app"), configDirectory: dir) == "build/A.app")
        #expect(ConfigTemplate.configPath(for: URL(fileURLWithPath: "/Applications/A.app"), configDirectory: dir) == "/Applications/A.app")
    }
}
