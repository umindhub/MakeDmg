import Foundation
import Testing
@testable import MakeDmgKit

@Suite struct AliasRecordTests {
    /// Background alias from a Finder-made DMG (create-dmg), with the nested
    /// disk-image alias (tag 0x14) removed. Built in UTC+8.
    static let finderGolden = [
        "00000000017e000200000c41707050616420312e322e31000000000000000000000000000000e6fadb19482b00050000",
        "00b312646d675f6261636b67726f756e642e706e67000000000000000000000000000000000000000000000000000000",
        "000000000000000000000000000000000000000000b4e6fadb260000000000000000ffffffff00000d02000000000000",
        "0000000000000000000b2e6261636b67726f756e6400001000080000e6fa6a990000001100080000e6fa6aa600000001",
        "0004000000b30002002c41707050616420312e322e313a2e6261636b67726f756e643a00646d675f6261636b67726f75",
        "6e642e706e67000e002600120064006d0067005f006200610063006b00670072006f0075006e0064002e0070006e0067",
        "000f001a000c00410070007000500061006400200031002e0032002e00310012001f2f2e6261636b67726f756e642f64",
        "6d675f6261636b67726f756e642e706e6700001300132f566f6c756d65732f646d672e56486463796700ffff0000",
    ].joined()

    static func macDate(_ seconds: UInt32) -> Date {
        Date(timeIntervalSince1970: TimeInterval(seconds) - AliasRecord.macEpochOffset)
    }

    static let sample = AliasRecord(
        volumeName: "AppPad 1.2.1",
        volumeCreationDate: macDate(0xE6FA_6A99),
        parentCNID: 0xB3,
        parentName: ".background",
        fileName: "dmg_background.png",
        fileCNID: 0xB4,
        fileCreationDate: macDate(0xE6FA_6AA6),
        pathInVolume: "/.background/dmg_background.png",
        mountPoint: "/Volumes/dmg.VHdcyg"
    )

    @Test func matchesFinderBytes() throws {
        let tz = try #require(TimeZone(secondsFromGMT: 8 * 3600))
        let encoded = Self.sample.encode(timeZone: tz)
        #expect(encoded.hexString == Self.finderGolden)
    }

    @Test func recordSizeIsPatched() {
        let encoded = Self.sample.encode(timeZone: TimeZone(secondsFromGMT: 0)!)
        let size = Int(encoded[4]) << 8 | Int(encoded[5])
        #expect(size == encoded.count)
    }

    @Test func classicDateIsLocalTime() throws {
        let tz = try #require(TimeZone(secondsFromGMT: 8 * 3600))
        #expect(AliasRecord.classicDate(Self.macDate(0xE6FA_6A99), timeZone: tz) == 0xE6FA_DB19)
    }

    @Test func highResDateKeepsFraction() {
        let date = Self.macDate(100).addingTimeInterval(0.5)
        #expect(AliasRecord.highResDate(date).hexString == "0000000000648000")
    }
}
