import Foundation
import Testing
@testable import MakeDmgKit

@Suite struct ConfigValidatorTests {
    /// Writes MyApp.app into a temp dir and validates the given config against it.
    private func validate(_ dict: [String: Any], files: [String] = []) throws -> [ConfigIssue] {
        let dir = try TempDir()
        defer { dir.remove() }
        try dir.makeDirectory("MyApp.app")
        for file in files {
            try dir.makeFile(file)
        }
        let loaded = try load(dict, base: dir.url)
        return ConfigValidator().validate(loaded)
    }

    @Test func minimalConfigIsClean() throws {
        #expect(try validate(minimalConfig()).isEmpty)
    }

    @Test func missingFileIsError() throws {
        var dict = minimalConfig()
        dict["contents"] = items([["path": "Missing.app", "x": 160, "y": 200]])
        #expect(hasIssue(try validate(dict), .error, "contents[0].path"))
    }

    @Test func requiresAtLeastOneFile() throws {
        var dict = minimalConfig()
        dict["contents"] = items([["type": "applications", "x": 160, "y": 200]])
        #expect(hasIssue(try validate(dict), .error, "contents"))
    }

    @Test func duplicateNamesAreCaseInsensitive() throws {
        var dict = minimalConfig()
        dict["contents"] = items([
            ["path": "MyApp.app", "x": 100, "y": 100],
            ["path": "MyApp.app", "name": "myapp.app", "x": 400, "y": 100],
        ])
        #expect(hasIssue(try validate(dict), .error, "contents[1].name"))
    }

    @Test func duplicateApplicationsLinkIsError() throws {
        var dict = minimalConfig()
        dict["contents"] = items([
            ["path": "MyApp.app", "x": 100, "y": 100],
            ["type": "applications", "x": 300, "y": 100],
            ["type": "applications", "name": "Apps", "x": 500, "y": 100],
        ])
        #expect(hasIssue(try validate(dict), .error, "contents[2]"))
    }

    @Test func reservedNameIsError() throws {
        var dict = minimalConfig()
        dict["contents"] = items([["path": "MyApp.app", "name": ".background", "x": 160, "y": 200]])
        #expect(hasIssue(try validate(dict), .error, "contents[0].name"))
    }

    @Test func iconSizeOutOfRange() throws {
        var dict = minimalConfig()
        dict["icon"] = ["size": 600]
        #expect(hasIssue(try validate(dict), .error, "icon.size"))
    }

    @Test func clippedIconIsWarning() throws {
        var dict = minimalConfig()
        dict["contents"] = items([["path": "MyApp.app", "x": 10, "y": 200]])
        #expect(hasIssue(try validate(dict), .warning, "contents[0]"))
    }

    @Test func overlappingIconsIsWarning() throws {
        var dict = minimalConfig()
        dict["contents"] = items([
            ["path": "MyApp.app", "x": 200, "y": 200],
            ["type": "applications", "x": 250, "y": 200],
        ])
        #expect(hasIssue(try validate(dict), .warning, "contents[1]"))
    }

    @Test func darkColorWarnsLightColorDoesNot() throws {
        var dark = minimalConfig()
        dark["background"] = ["color": "#121233"]
        #expect(hasIssue(try validate(dark), .warning, "background.color"))

        var light = minimalConfig()
        light["background"] = ["color": "#F5F5F7"]
        #expect(try validate(light).isEmpty)
    }

    @Test func missingBackgroundImageIsError() throws {
        var dict = minimalConfig()
        dict["background"] = ["image": "assets/bg.png"]
        #expect(hasIssue(try validate(dict), .error, "background.image"))
    }

    @Test func volumeIconMustBeIcns() throws {
        var dict = minimalConfig()
        dict["volumeIcon"] = "assets/volume.png"
        #expect(hasIssue(try validate(dict, files: ["assets/volume.png"]), .error, "volumeIcon"))
    }

    @Test func notarizeRequiresSign() throws {
        var dict = minimalConfig()
        dict["notarize"] = ["keychainProfile": "notary"]
        #expect(hasIssue(try validate(dict), .error, "notarize"))
    }

    @Test func colonInVolumeNameIsError() throws {
        var dict = minimalConfig()
        dict["volumeName"] = "My:App"
        #expect(hasIssue(try validate(dict), .error, "volumeName"))
    }

    @Test func imageBackgroundRequiresHFSPlus() throws {
        var dict = minimalConfig()
        dict["filesystem"] = "APFS"
        dict["background"] = ["image": "bg.png"]
        let issues = try validate(dict, files: ["bg.png"])
        #expect(issues.contains { $0.severity == .error && $0.message.contains("HFS+") })
    }
}
