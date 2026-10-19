import Foundation

/// One (filename, code) entry of a .DS_Store B-tree.
public struct DSStoreRecord: Sendable, Equatable {
    public enum Value: Sendable, Equatable {
        case long(UInt32)
        case shor(UInt16)
        case bool(Bool)
        case blob(Data)
        case type(FourCC)
        case ustr(String)
        case comp(UInt64)
        case dutc(UInt64)
    }

    public let filename: String
    public let code: FourCC
    public let value: Value

    public init(filename: String, code: FourCC, value: Value) {
        self.filename = filename
        self.code = code
        self.value = value
    }

    func encode(into data: inout Data) {
        data.appendBE(UInt32(filename.utf16.count))
        data.appendUTF16BE(filename)
        data.append(code)
        switch value {
        case .long(let v):
            data.append("long" as FourCC)
            data.appendBE(v)
        case .shor(let v):
            // Stored in 4 bytes like "long".
            data.append("shor" as FourCC)
            data.appendBE(UInt32(v))
        case .bool(let v):
            data.append("bool" as FourCC)
            data.append(UInt8(v ? 1 : 0))
        case .blob(let v):
            data.append("blob" as FourCC)
            data.appendBE(UInt32(v.count))
            data.append(v)
        case .type(let v):
            data.append("type" as FourCC)
            data.append(v)
        case .ustr(let v):
            data.append("ustr" as FourCC)
            data.appendBE(UInt32(v.utf16.count))
            data.appendUTF16BE(v)
        case .comp(let v):
            data.append("comp" as FourCC)
            data.appendBE(v)
        case .dutc(let v):
            data.append("dutc" as FourCC)
            data.appendBE(v)
        }
    }

    static func decode(from reader: inout ByteReader) throws -> DSStoreRecord {
        let nameLength = Int(try reader.readBE(UInt32.self))
        let filename = try reader.readUTF16BE(units: nameLength)
        let code = try reader.readFourCC()
        let type = try reader.readFourCC()
        let value: Value
        switch type.description {
        case "long": value = .long(try reader.readBE(UInt32.self))
        case "shor": value = .shor(UInt16(truncatingIfNeeded: try reader.readBE(UInt32.self)))
        case "bool": value = .bool(try reader.read(1)[0] != 0)
        case "blob":
            let count = Int(try reader.readBE(UInt32.self))
            value = .blob(Data(try reader.read(count)))
        case "type": value = .type(try reader.readFourCC())
        case "ustr":
            let units = Int(try reader.readBE(UInt32.self))
            value = .ustr(try reader.readUTF16BE(units: units))
        case "comp": value = .comp(try reader.readBE(UInt64.self))
        case "dutc": value = .dutc(try reader.readBE(UInt64.self))
        default:
            throw DSStoreError.unknownValueType(type.description)
        }
        return DSStoreRecord(filename: filename, code: code, value: value)
    }

    /// Finder order: case-insensitive filename, then code.
    static func precedes(_ a: DSStoreRecord, _ b: DSStoreRecord) -> Bool {
        let lhs = Array(a.filename.lowercased().utf16)
        let rhs = Array(b.filename.lowercased().utf16)
        if lhs != rhs {
            return lhs.lexicographicallyPrecedes(rhs)
        }
        return a.code.bytes.lexicographicallyPrecedes(b.code.bytes)
    }
}

public enum DSStoreError: Error, Equatable, CustomStringConvertible {
    case invalidHeader
    case missingDSDB
    case unknownValueType(String)
    case duplicateRecord(filename: String, code: String)
    case nodeTooLarge(bytes: Int, limit: Int)
    case allocatorExhausted

    public var description: String {
        switch self {
        case .invalidHeader: return "not a .DS_Store file (bad header)"
        case .missingDSDB: return ".DS_Store has no DSDB entry"
        case .unknownValueType(let t): return "unknown .DS_Store value type '\(t)'"
        case let .duplicateRecord(name, code): return "duplicate .DS_Store record '\(name)' \(code)"
        case let .nodeTooLarge(bytes, limit):
            return ".DS_Store records need \(bytes) bytes, more than one \(limit)-byte node; too many items"
        case .allocatorExhausted: return ".DS_Store allocator has no free space"
        }
    }
}
