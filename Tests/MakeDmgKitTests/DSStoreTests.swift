import Foundation
import Testing
@testable import MakeDmgKit

@Suite struct DSStoreTests {
    static let records: [DSStoreRecord] = [
        DSStoreRecord(filename: "AppPad.app", code: "Iloc", value: .blob(FinderLayout.iconLocation(x: 150, y: 165))),
        DSStoreRecord(filename: ".", code: "vSrn", value: .long(1)),
        DSStoreRecord(filename: "Applications", code: "Iloc", value: .blob(FinderLayout.iconLocation(x: 450, y: 165))),
        DSStoreRecord(filename: ".", code: "bwsp", value: .blob(Data([1, 2, 3]))),
    ]

    @Test func iconLocationMatchesFinder() {
        // Bytes from a Finder-written Iloc record at (450, 165).
        #expect(FinderLayout.iconLocation(x: 450, y: 165).hexString == "000001c2000000a5ffffffffffff0000")
    }

    @Test func headerAndSize() throws {
        let data = try DSStoreWriter.encode(Self.records)
        #expect(Array(data.prefix(8)) == [0, 0, 0, 1, 0x42, 0x75, 0x64, 0x31])
        // 4-byte prefix + header/root/node/DSDB blocks ending at 0x2000.
        #expect(data.count == 0x2004)
    }

    @Test func roundTripsInFinderOrder() throws {
        let data = try DSStoreWriter.encode(Self.records)
        let decoded = try DSStoreReader.read(data)
        #expect(decoded.map(\.filename) == [".", ".", "Applications", "AppPad.app"])
        #expect(decoded.map(\.code.description) == ["bwsp", "vSrn", "Iloc", "Iloc"])
        #expect(Set(decoded.map { "\($0.filename)/\($0.code)" }) == Set(Self.records.map { "\($0.filename)/\($0.code)" }))
        #expect(decoded.first { $0.filename == "AppPad.app" }?.value == Self.records[0].value)
    }

    @Test func roundTripsAllValueTypes() throws {
        let values: [DSStoreRecord.Value] = [
            .long(0xDEAD_BEEF), .shor(7), .bool(true), .blob(Data([9, 8])),
            .type("icnv"), .ustr("名前 ✓"), .comp(42), .dutc(0x0102_0304_0506_0708),
        ]
        let records = values.enumerated().map { index, value in
            DSStoreRecord(filename: "file\(index)", code: "test", value: value)
        }
        let decoded = try DSStoreReader.read(try DSStoreWriter.encode(records))
        #expect(decoded == records)
    }

    @Test func rejectsDuplicateRecords() {
        let dup = [Self.records[1], Self.records[1]]
        #expect(throws: DSStoreError.self) { _ = try DSStoreWriter.encode(dup) }
    }

    @Test func rejectsOversizedNode() {
        let big = DSStoreRecord(filename: "x", code: "blob", value: .blob(Data(count: 5000)))
        #expect(throws: DSStoreError.nodeTooLarge(bytes: 5026, limit: 0x1000)) {
            _ = try DSStoreWriter.encode([big])
        }
    }

    @Test func allocatorSplitsBuddies() throws {
        var allocator = BuddyAllocator()
        #expect(try allocator.allocate(exponent: 5) == 0)
        #expect(try allocator.allocate(exponent: 11) == 0x800)
        #expect(try allocator.allocate(exponent: 12) == 0x1000)
        #expect(try allocator.allocate(exponent: 5) == 0x20)
        #expect(allocator.freeLists[6] == [0x40])
        #expect(allocator.freeLists[30] == [0x4000_0000])
    }

    @Test func sortsCaseInsensitively() {
        let a = DSStoreRecord(filename: "beta", code: "Iloc", value: .long(0))
        let b = DSStoreRecord(filename: "Alpha", code: "Iloc", value: .long(0))
        #expect(DSStoreRecord.precedes(b, a))
    }
}

@Suite struct FinderLayoutTests {
    private func plist(_ data: Data) throws -> [String: Any] {
        try #require(try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
    }

    private func blob(_ records: [DSStoreRecord], _ code: FourCC) throws -> Data {
        let record = try #require(records.first { $0.filename == "." && $0.code == code })
        guard case .blob(let data) = record.value else {
            Issue.record("\(code) is not a blob")
            return Data()
        }
        return data
    }

    private func layout(_ background: FinderBackground) -> FinderLayout {
        FinderLayout(
            window: WindowConfig(),
            icon: IconConfig(),
            background: background,
            positions: [IconPosition(name: "MyApp.app", x: 160, y: 200)]
        )
    }

    @Test func windowBounds() throws {
        let bwsp = try plist(try blob(try layout(.none).records(), "bwsp"))
        #expect(bwsp["WindowBounds"] as? String == "{{200, 120}, {640, 400}}")
        #expect(bwsp["ShowToolbar"] as? Bool == false)
        #expect(bwsp["ShowTabView"] as? Bool == false)
    }

    @Test func flipsWindowYToFinderCoordinates() {
        #expect(ScreenGeometry.finderY(topLeftY: 120, windowHeight: 400, screenHeight: 1117) == 597)
    }

    @Test func colorBackground() throws {
        let color = try #require(HexColor("#FF8000"))
        let icvp = try plist(try blob(try layout(.color(color)).records(), "icvp"))
        #expect(icvp["backgroundType"] as? Int == 1)
        #expect(icvp["backgroundColorRed"] as? Double == 1.0)
        #expect(abs((icvp["backgroundColorGreen"] as? Double ?? 0) - 128.0 / 255) < 1e-9)
        #expect(icvp["backgroundColorBlue"] as? Double == 0.0)
        #expect(icvp["iconSize"] as? Double == 128)
        #expect(icvp["arrangeBy"] as? String == "none")
    }

    @Test func imageBackgroundAddsAliasAndBookmark() throws {
        let records = try layout(.image(alias: Data([1, 2]), bookmark: Data([3]))).records()
        let icvp = try plist(try blob(records, "icvp"))
        #expect(icvp["backgroundType"] as? Int == 2)
        #expect(icvp["backgroundImageAlias"] as? Data == Data([1, 2]))
        #expect(try blob(records, "pBBk") == Data([3]))
    }

    @Test func iconPositionRecord() throws {
        let records = try layout(.none).records()
        let iloc = try #require(records.first { $0.filename == "MyApp.app" && $0.code == "Iloc" })
        #expect(iloc.value == .blob(FinderLayout.iconLocation(x: 160, y: 200)))
    }
}
