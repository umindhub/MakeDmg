import Foundation

/// RGB color parsed from "#RGB" or "#RRGGBB". Finder ignores alpha, so none is accepted.
public struct HexColor: Sendable, Equatable, CustomStringConvertible {
    public let red: UInt8
    public let green: UInt8
    public let blue: UInt8

    public init(red: UInt8, green: UInt8, blue: UInt8) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    public init?(_ string: String) {
        let trimmed = string.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("#") else { return nil }
        var hex = String(trimmed.dropFirst())
        guard hex.allSatisfy(\.isHexDigit) else { return nil }
        if hex.count == 3 {
            hex = hex.map { "\($0)\($0)" }.joined()
        }
        guard hex.count == 6, let value = UInt32(hex, radix: 16) else { return nil }
        red = UInt8((value >> 16) & 0xFF)
        green = UInt8((value >> 8) & 0xFF)
        blue = UInt8(value & 0xFF)
    }

    /// Components in 0...1, as stored in the DS_Store icvp plist.
    public var redComponent: Double { Double(red) / 255 }
    public var greenComponent: Double { Double(green) / 255 }
    public var blueComponent: Double { Double(blue) / 255 }

    /// WCAG relative luminance, 0 (black) ... 1 (white).
    public var relativeLuminance: Double {
        func linear(_ c: Double) -> Double {
            c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(redComponent)
            + 0.7152 * linear(greenComponent)
            + 0.0722 * linear(blueComponent)
    }

    public var description: String {
        String(format: "#%02X%02X%02X", Int(red), Int(green), Int(blue))
    }
}

extension HexColor: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        guard let color = HexColor(raw) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "invalid color '\(raw)', expected #RGB or #RRGGBB"
            )
        }
        self = color
    }
}
