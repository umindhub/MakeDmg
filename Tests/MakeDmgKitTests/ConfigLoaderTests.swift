import Foundation
import Testing
@testable import MakeDmgKit

@Suite struct ConfigLoaderTests {
    @Test func appliesDefaults() throws {
        let loaded = try load(minimalConfig())
        let c = loaded.config
        #expect(c.format == .ulfo)
        #expect(c.filesystem == .hfsPlus)
        #expect(c.window == WindowConfig())
        #expect(c.icon == IconConfig())
        #expect(c.background == nil)
        #expect(c.contents.count == 2)
        #expect(c.contents[0].kind == .file(path: "MyApp.app"))
        #expect(c.contents[1].kind == .applications)
        #expect(c.contents[1].finalName == "Applications")
        #expect(loaded.loadIssues.isEmpty)
    }

    @Test func decodesColorBackground() throws {
        var dict = minimalConfig()
        dict["background"] = ["color": "#121233"]
        let c = try load(dict).config
        #expect(c.background == .color(HexColor(red: 0x12, green: 0x12, blue: 0x33)))
    }

    @Test func decodesImageBackground() throws {
        var dict = minimalConfig()
        dict["background"] = ["image": "assets/bg.png"]
        #expect(try load(dict).config.background == .image("assets/bg.png"))
    }

    @Test func rejectsColorAndImageTogether() throws {
        var dict = minimalConfig()
        dict["background"] = ["color": "#FFFFFF", "image": "bg.png"]
        let error = try #require(loadError(dict))
        #expect(error.description.contains("background"))
        #expect(error.description.contains("mutually exclusive"))
    }

    @Test func rejectsEmptyBackground() throws {
        var dict = minimalConfig()
        dict["background"] = [String: Any]()
        let error = try #require(loadError(dict))
        #expect(error.description.contains("set either"))
    }

    @Test func rejectsInvalidColor() throws {
        var dict = minimalConfig()
        dict["background"] = ["color": "blue"]
        let error = try #require(loadError(dict))
        #expect(error.description.contains("background.color"))
    }

    @Test func reportsTypeMismatchPath() throws {
        var dict = minimalConfig()
        dict["contents"] = items([["path": "MyApp.app", "x": "160", "y": 200]])
        let error = try #require(loadError(dict))
        #expect(error.description.contains("contents[0].x"))
        #expect(error.description.contains("expected a number"))
    }

    @Test func reportsMissingRequiredKey() throws {
        var dict = minimalConfig()
        dict.removeValue(forKey: "volumeName")
        let error = try #require(loadError(dict))
        #expect(error.description.hasPrefix("volumeName: required key is missing"))
    }

    @Test func missingKeyErrorIncludesTypoNote() throws {
        var dict = minimalConfig()
        dict.removeValue(forKey: "volumeName")
        dict["VolumeName"] = "MyApp"
        let error = try #require(loadError(dict))
        #expect(error.description.contains("did you mean 'volumeName'"))
    }

    @Test func warnsOnUnknownKeysWithSuggestion() throws {
        var dict = minimalConfig()
        dict["window"] = ["width": 640, "hieght": 400]
        let loaded = try load(dict)
        let issue = try #require(loaded.loadIssues.first)
        #expect(issue.severity == .warning)
        #expect(issue.path == "window")
        #expect(issue.message.contains("did you mean 'height'"))
    }

    @Test func acceptsSchemaKey() throws {
        var dict = minimalConfig()
        dict["$schema"] = "https://example.com/makedmg.schema.json"
        #expect(try load(dict).loadIssues.isEmpty)
    }

    @Test func enumsAreCaseInsensitive() throws {
        var dict = minimalConfig()
        dict["format"] = "ulmo"
        dict["filesystem"] = "apfs"
        let c = try load(dict).config
        #expect(c.format == .ulmo)
        #expect(c.filesystem == .apfs)
    }

    @Test func rejectsUnknownEnumValue() throws {
        var dict = minimalConfig()
        dict["format"] = "zip"
        let error = try #require(loadError(dict))
        #expect(error.description.contains("expected one of: UDZO, UDBZ, ULFO, ULMO"))
    }

    @Test func rejectsPathOnApplicationsLink() throws {
        var dict = minimalConfig()
        dict["contents"] = items([["type": "applications", "path": "/Applications", "x": 1, "y": 1]])
        let error = try #require(loadError(dict))
        #expect(error.description.contains("contents[0].path"))
    }

    @Test func rejectsInvalidJSONSyntax() throws {
        let data = Data("{ \"volumeName\": ".utf8)
        #expect(throws: ConfigError.self) {
            _ = try ConfigLoader.load(data: data, fileURL: fakeBase.appendingPathComponent("makedmg.json"))
        }
    }

    @Test func resolvesPathsRelativeToConfigFile() throws {
        let loaded = try load(minimalConfig())
        #expect(loaded.resolve("build/MyApp.app").path == "/Users/test/project/build/MyApp.app")
        #expect(loaded.resolve("../assets/bg.png").path == "/Users/test/assets/bg.png")
        #expect(loaded.resolve("/opt/x.app").path == "/opt/x.app")
    }

    @Test func editDistanceAndSuggestion() {
        #expect(ConfigLoader.editDistance("kitten", "sitting") == 3)
        #expect(ConfigLoader.closestMatch(to: "volumname", in: DMGConfig.knownKeys) == "volumeName")
        #expect(ConfigLoader.closestMatch(to: "zzzzzz", in: DMGConfig.knownKeys) == nil)
    }

    @Test func decodesHideExtension() throws {
        var dict = minimalConfig()
        dict["contents"] = items([["path": "MyApp.app", "x": 160, "y": 200, "hideExtension": true]])
        let item = try load(dict).config.contents[0]
        #expect(item.hideExtension)
        #expect(item.finalName == "MyApp.app")
        #expect(item.displayName == "MyApp")
    }
}
