/// Buddy allocator over the 2^31-byte .DS_Store address space.
/// Block addresses encode offset | log2(size); blocks are at least 32 bytes.
struct BuddyAllocator {
    static let minExponent = 5
    static let maxExponent = 31

    /// Free block offsets per size exponent, ascending.
    private(set) var freeLists: [[UInt32]]

    init() {
        freeLists = Array(repeating: [], count: 32)
        freeLists[Self.maxExponent] = [0]
    }

    static func exponent(forSize size: Int) -> Int {
        var exp = minExponent
        while (1 << exp) < size { exp += 1 }
        return exp
    }

    static func address(offset: UInt32, exponent: Int) -> UInt32 {
        offset | UInt32(exponent)
    }

    static func decode(address: UInt32) -> (offset: Int, size: Int) {
        (Int(address & ~0x1F), 1 << Int(address & 0x1F))
    }

    /// Returns the offset of a block of 2^exponent bytes, splitting larger blocks as needed.
    mutating func allocate(exponent: Int) throws -> UInt32 {
        var k = Swift.max(exponent, Self.minExponent)
        let target = k
        while k <= Self.maxExponent && freeLists[k].isEmpty { k += 1 }
        guard k <= Self.maxExponent else { throw DSStoreError.allocatorExhausted }

        let offset = freeLists[k].removeFirst()
        while k > target {
            k -= 1
            let buddy = offset + (UInt32(1) << UInt32(k))
            freeLists[k].append(buddy)
            freeLists[k].sort()
        }
        return offset
    }
}
