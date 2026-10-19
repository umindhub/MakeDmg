import Testing
@testable import MakeDmgKit

@Suite struct HexColorTests {
    @Test func parsesLongForm() throws {
        let color = try #require(HexColor("#121233"))
        #expect(color == HexColor(red: 0x12, green: 0x12, blue: 0x33))
    }

    @Test func parsesShortFormAndLowercase() throws {
        let color = try #require(HexColor("#fa0"))
        #expect(color == HexColor(red: 0xFF, green: 0xAA, blue: 0x00))
    }

    @Test(arguments: ["121233", "#12345", "#1234567", "#GGGGGG", "#+12345", "", "#"])
    func rejectsInvalid(_ input: String) {
        #expect(HexColor(input) == nil)
    }

    @Test func descriptionIsUppercase() {
        #expect(HexColor("#abcdef")?.description == "#ABCDEF")
    }

    @Test func luminance() throws {
        let white = try #require(HexColor("#FFFFFF"))
        let black = try #require(HexColor("#000000"))
        let navy = try #require(HexColor("#121233"))
        #expect(white.relativeLuminance > 0.99)
        #expect(black.relativeLuminance < 0.01)
        #expect(navy.relativeLuminance < ConfigValidator.darkBackgroundThreshold)
    }
}
