import Foundation

/// Four ASCII characters, e.g. "Iloc", "blob", "Bud1".
public struct FourCC: Hashable, Sendable, CustomStringConvertible, ExpressibleByStringLiteral {
    public let bytes: [UInt8]

    public init?(_ string: String) {
        let ascii = Array(string.utf8)
        guard ascii.count == 4, ascii.allSatisfy({ $0 >= 0x20 && $0 < 0x7F }) else { return nil }
        bytes = ascii
    }

    public init(stringLiteral value: String) {
        guard let code = FourCC(value) else { preconditionFailure("invalid FourCC '\(value)'") }
        self = code
    }

    init(bytes: [UInt8]) {
        self.bytes = bytes
    }

    public var description: String { String(decoding: bytes, as: UTF8.self) }
}

extension Data {
    mutating func appendBE<T: FixedWidthInteger>(_ value: T) {
        Swift.withUnsafeBytes(of: value.bigEndian) { append(contentsOf: $0) }
    }

    mutating func append(_ code: FourCC) {
        append(contentsOf: code.bytes)
    }

    mutating func appendZeros(_ count: Int) {
        append(Data(count: count))
    }

    mutating func appendUTF16BE(_ string: String) {
        for unit in string.utf16 {
            appendBE(unit)
        }
    }
}

enum BinaryError: Error, Equatable, CustomStringConvertible {
    case truncated(offset: Int, needed: Int)

    var description: String {
        switch self {
        case let .truncated(offset, needed):
            return "unexpected end of data at offset \(offset) (needed \(needed) bytes)"
        }
    }
}

/// Sequential big-endian reader over a byte array.
struct ByteReader {
    let bytes: [UInt8]
    var offset: Int

    init(_ bytes: [UInt8], offset: Int = 0) {
        self.bytes = bytes
        self.offset = offset
    }

    mutating func read(_ count: Int) throws -> [UInt8] {
        guard count >= 0, offset >= 0, offset + count <= bytes.count else {
            throw BinaryError.truncated(offset: offset, needed: count)
        }
        defer { offset += count }
        return Array(bytes[offset..<offset + count])
    }

    mutating func readBE<T: FixedWidthInteger>(_: T.Type = T.self) throws -> T {
        let raw = try read(MemoryLayout<T>.size)
        return raw.reduce(T.zero) { ($0 << 8) | T($1) }
    }

    mutating func readFourCC() throws -> FourCC {
        FourCC(bytes: try read(4))
    }

    mutating func readUTF16BE(units: Int) throws -> String {
        var codeUnits: [UInt16] = []
        codeUnits.reserveCapacity(units)
        for _ in 0..<units {
            codeUnits.append(try readBE(UInt16.self))
        }
        return String(decoding: codeUnits, as: UTF16.self)
    }
}
