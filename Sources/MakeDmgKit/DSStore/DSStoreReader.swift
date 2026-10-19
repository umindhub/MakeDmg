import Foundation

/// Parses a .DS_Store file into records in B-tree order. Handles multi-level trees.
public enum DSStoreReader {
    public static func read(contentsOf url: URL) throws -> [DSStoreRecord] {
        try read(try Data(contentsOf: url))
    }

    public static func read(_ data: Data) throws -> [DSStoreRecord] {
        let bytes = [UInt8](data)
        var header = ByteReader(bytes)
        guard try header.readBE(UInt32.self) == 1,
              try header.readFourCC() == "Bud1"
        else { throw DSStoreError.invalidHeader }
        let rootOffset = Int(try header.readBE(UInt32.self))

        // Root info block: addresses, table of contents.
        var root = ByteReader(bytes, offset: 4 + rootOffset)
        let blockCount = Int(try root.readBE(UInt32.self))
        _ = try root.readBE(UInt32.self)
        var addresses: [UInt32] = []
        for _ in 0..<blockCount {
            addresses.append(try root.readBE(UInt32.self))
        }
        let paddedCount = (blockCount + 255) / 256 * 256
        _ = try root.read((paddedCount - blockCount) * 4)

        var dsdbID: UInt32?
        let tocCount = Int(try root.readBE(UInt32.self))
        for _ in 0..<tocCount {
            let length = Int(try root.read(1)[0])
            let name = String(decoding: try root.read(length), as: UTF8.self)
            let id = try root.readBE(UInt32.self)
            if name == "DSDB" { dsdbID = id }
        }
        guard let dsdbID else { throw DSStoreError.missingDSDB }

        func blockReader(_ id: UInt32) throws -> ByteReader {
            guard Int(id) < addresses.count else { throw DSStoreError.invalidHeader }
            let (offset, _) = BuddyAllocator.decode(address: addresses[Int(id)])
            return ByteReader(bytes, offset: 4 + offset)
        }

        var dsdb = try blockReader(dsdbID)
        let rootNode = try dsdb.readBE(UInt32.self)

        var records: [DSStoreRecord] = []
        func walk(_ id: UInt32, depth: Int) throws {
            guard depth < 16 else { throw DSStoreError.invalidHeader }
            var node = try blockReader(id)
            let rightmost = try node.readBE(UInt32.self)
            let count = Int(try node.readBE(UInt32.self))
            for _ in 0..<count {
                if rightmost != 0 {
                    try walk(try node.readBE(UInt32.self), depth: depth + 1)
                }
                records.append(try DSStoreRecord.decode(from: &node))
            }
            if rightmost != 0 {
                try walk(rightmost, depth: depth + 1)
            }
        }
        try walk(rootNode, depth: 0)
        return records
    }
}
