import Foundation

/// Serializes records into a .DS_Store file with a single leaf B-tree node.
public enum DSStoreWriter {
    public static let pageSize = 0x1000
    static let rootBlockSize = 0x800

    public static func encode(_ records: [DSStoreRecord]) throws -> Data {
        let sorted = records.sorted(by: DSStoreRecord.precedes)
        for (a, b) in zip(sorted, sorted.dropFirst())
        where a.filename.lowercased() == b.filename.lowercased() && a.code == b.code {
            throw DSStoreError.duplicateRecord(filename: b.filename, code: b.code.description)
        }

        // Leaf node: P = 0, count, records.
        var node = Data()
        node.appendBE(UInt32(0))
        node.appendBE(UInt32(sorted.count))
        for record in sorted {
            record.encode(into: &node)
        }
        guard node.count <= pageSize else {
            throw DSStoreError.nodeTooLarge(bytes: node.count, limit: pageSize)
        }

        // Layout: header at 0, then root info, node, DSDB.
        var allocator = BuddyAllocator()
        let headerOffset = try allocator.allocate(exponent: BuddyAllocator.minExponent)
        precondition(headerOffset == 0, "header must be at offset 0")
        let rootExp = BuddyAllocator.exponent(forSize: rootBlockSize)
        let nodeExp = BuddyAllocator.exponent(forSize: pageSize)
        let dsdbExp = BuddyAllocator.minExponent
        let rootOffset = try allocator.allocate(exponent: rootExp)
        let nodeOffset = try allocator.allocate(exponent: nodeExp)
        let dsdbOffset = try allocator.allocate(exponent: dsdbExp)

        // Block ids: 0 = root info, 1 = DSDB, 2 = node.
        let addresses: [UInt32] = [
            BuddyAllocator.address(offset: rootOffset, exponent: rootExp),
            BuddyAllocator.address(offset: dsdbOffset, exponent: dsdbExp),
            BuddyAllocator.address(offset: nodeOffset, exponent: nodeExp),
        ]
        let dsdbID: UInt32 = 1
        let nodeID: UInt32 = 2

        var dsdb = Data()
        dsdb.appendBE(nodeID)               // root node
        dsdb.appendBE(UInt32(0))            // levels below root
        dsdb.appendBE(UInt32(sorted.count)) // records
        dsdb.appendBE(UInt32(1))            // nodes
        dsdb.appendBE(UInt32(pageSize))

        var root = Data()
        root.appendBE(UInt32(addresses.count))
        root.appendBE(UInt32(0))
        let paddedCount = (addresses.count + 255) / 256 * 256
        for index in 0..<paddedCount {
            root.appendBE(index < addresses.count ? addresses[index] : 0)
        }
        root.appendBE(UInt32(1)) // table of contents entries
        root.append(UInt8(4))
        root.append("DSDB" as FourCC)
        root.appendBE(dsdbID)
        for list in allocator.freeLists {
            root.appendBE(UInt32(list.count))
            for offset in list {
                root.appendBE(offset)
            }
        }
        precondition(root.count <= rootBlockSize, "root block overflow")

        // File = 4-byte prefix + allocator space up to the last used block.
        let blocks: [(offset: UInt32, size: Int, data: Data)] = [
            (rootOffset, rootBlockSize, root),
            (nodeOffset, pageSize, node),
            (dsdbOffset, 1 << dsdbExp, dsdb),
        ]
        let end = blocks.map { Int($0.offset) + $0.size }.max() ?? 0
        var file = Data(count: 4 + end)

        var header = Data()
        header.appendBE(UInt32(1))
        header.append("Bud1" as FourCC)
        header.appendBE(rootOffset)
        header.appendBE(UInt32(rootBlockSize))
        header.appendBE(rootOffset)
        header.appendZeros(16)
        file.replaceSubrange(0..<header.count, with: header)

        for block in blocks {
            let start = 4 + Int(block.offset)
            file.replaceSubrange(start..<start + block.data.count, with: block.data)
        }
        return file
    }

    public static func write(_ records: [DSStoreRecord], to url: URL) throws {
        try encode(records).write(to: url, options: .atomic)
    }
}
