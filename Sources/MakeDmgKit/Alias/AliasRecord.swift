import Foundation

/// Classic Mac OS alias (version 2) pointing at a file on a mounted volume.
/// Layout matches what Finder writes into icvp.backgroundImageAlias, minus the
/// optional nested disk-image alias (tag 0x14).
public struct AliasRecord: Sendable, Equatable {
    public var volumeName: String
    public var volumeCreationDate: Date
    /// Two-letter file system signature, "H+" for HFS+.
    public var filesystemSignature: UInt16 = 0x482B
    /// 5 = ejectable, what Finder records for mounted disk images.
    public var diskType: UInt16 = 5
    public var volumeAttributes: UInt32 = 0x0D02
    public var parentCNID: UInt32
    public var parentName: String
    public var fileName: String
    public var fileCNID: UInt32
    public var fileCreationDate: Date
    /// POSIX path from the volume root, e.g. "/.background/bg.tiff".
    public var pathInVolume: String
    /// Mount point at creation time, e.g. "/Volumes/MyApp".
    public var mountPoint: String

    public init(
        volumeName: String, volumeCreationDate: Date,
        parentCNID: UInt32, parentName: String,
        fileName: String, fileCNID: UInt32, fileCreationDate: Date,
        pathInVolume: String, mountPoint: String
    ) {
        self.volumeName = volumeName
        self.volumeCreationDate = volumeCreationDate
        self.parentCNID = parentCNID
        self.parentName = parentName
        self.fileName = fileName
        self.fileCNID = fileCNID
        self.fileCreationDate = fileCreationDate
        self.pathInVolume = pathInVolume
        self.mountPoint = mountPoint
    }

    // MARK: - Encoding

    /// 32-bit dates are local time (classic Mac OS); tagged high-res dates are UTC.
    public func encode(timeZone: TimeZone = .current) -> Data {
        var d = Data()
        d.appendZeros(4)                 // application info
        d.appendBE(UInt16(0))            // record size, patched below
        d.appendBE(UInt16(2))            // version
        d.appendBE(UInt16(0))            // kind: file
        d.appendPascal(volumeName, fieldSize: 28)
        d.appendBE(Self.classicDate(volumeCreationDate, timeZone: timeZone))
        d.appendBE(filesystemSignature)
        d.appendBE(diskType)
        d.appendBE(parentCNID)
        d.appendPascal(fileName, fieldSize: 64)
        d.appendBE(fileCNID)
        d.appendBE(Self.classicDate(fileCreationDate, timeZone: timeZone))
        d.appendZeros(4)                 // file type
        d.appendZeros(4)                 // creator
        d.appendBE(UInt16(0xFFFF))       // nlvlFrom
        d.appendBE(UInt16(0xFFFF))       // nlvlTo
        d.appendBE(volumeAttributes)
        d.appendBE(UInt16(0))            // volume fs id
        d.appendZeros(10)                // reserved

        d.appendTag(0x0000, Data(parentName.utf8))
        d.appendTag(0x0010, Self.highResDate(volumeCreationDate))
        d.appendTag(0x0011, Self.highResDate(fileCreationDate))
        var cnidPath = Data()
        cnidPath.appendBE(parentCNID)
        d.appendTag(0x0001, cnidPath)
        // Carbon path as Finder writes it: "Volume:Parent:\0File".
        d.appendTag(0x0002, Data("\(volumeName):\(parentName):\u{0}\(fileName)".utf8))
        d.appendTag(0x000E, Self.unicodeName(fileName))
        d.appendTag(0x000F, Self.unicodeName(volumeName))
        d.appendTag(0x0012, Data(pathInVolume.utf8))
        d.appendTag(0x0013, Data(mountPoint.utf8))
        d.appendBE(UInt16(0xFFFF))       // end tag
        d.appendBE(UInt16(0))

        let size = UInt16(d.count)
        d[4] = UInt8(size >> 8)
        d[5] = UInt8(size & 0xFF)
        return d
    }

    // MARK: - Helpers

    /// Seconds between 1904-01-01 and 1970-01-01.
    static let macEpochOffset: TimeInterval = 2_082_844_800

    static func macSeconds(_ date: Date) -> TimeInterval {
        date.timeIntervalSince1970 + macEpochOffset
    }

    static func classicDate(_ date: Date, timeZone: TimeZone) -> UInt32 {
        let local = floor(macSeconds(date)) + TimeInterval(timeZone.secondsFromGMT(for: date))
        return UInt32(clamping: Int64(local))
    }

    /// 48.16 fixed-point seconds since 1904, UTC.
    static func highResDate(_ date: Date) -> Data {
        let seconds = macSeconds(date)
        let whole = floor(seconds)
        let fraction = UInt64((seconds - whole) * 65536) & 0xFFFF
        var d = Data()
        d.appendBE((UInt64(Swift.max(whole, 0)) << 16) | fraction)
        return d
    }

    static func unicodeName(_ name: String) -> Data {
        var d = Data()
        d.appendBE(UInt16(name.utf16.count))
        d.appendUTF16BE(name)
        return d
    }
}

private extension Data {
    /// Length-prefixed MacRoman string padded to a fixed field size.
    mutating func appendPascal(_ string: String, fieldSize: Int) {
        let encoded = string.data(using: .macOSRoman, allowLossyConversion: true) ?? Data()
        let bytes = encoded.prefix(fieldSize - 1)
        append(UInt8(bytes.count))
        append(bytes)
        appendZeros(fieldSize - 1 - bytes.count)
    }

    /// Tag, length, data, padded to an even length.
    mutating func appendTag(_ tag: UInt16, _ data: Data) {
        appendBE(tag)
        appendBE(UInt16(data.count))
        append(data)
        if data.count % 2 == 1 { append(UInt8(0)) }
    }
}
