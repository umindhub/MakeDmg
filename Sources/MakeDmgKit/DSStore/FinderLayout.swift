import Foundation

/// Background as Finder stores it in icvp.
public enum FinderBackground: Sendable, Equatable {
    case none
    case color(HexColor)
    /// Alias is required; the bookmark (pBBk) is what newer Finder writes alongside it.
    case image(alias: Data, bookmark: Data?)
}

public struct IconPosition: Sendable, Equatable {
    public var name: String
    public var x: Int
    public var y: Int

    public init(name: String, x: Int, y: Int) {
        self.name = name
        self.x = x
        self.y = y
    }
}

/// Builds the Finder view records (bwsp, icvp, pBBk, vSrn, Iloc) for a volume root.
public struct FinderLayout: Sendable {
    public var window: WindowConfig
    public var icon: IconConfig
    public var background: FinderBackground
    public var positions: [IconPosition]

    public init(window: WindowConfig, icon: IconConfig, background: FinderBackground, positions: [IconPosition]) {
        self.window = window
        self.icon = icon
        self.background = background
        self.positions = positions
    }

    /// Uses window, icon and item positions from a config.
    public init(config: DMGConfig, background: FinderBackground) {
        self.init(
            window: config.window,
            icon: config.icon,
            background: background,
            positions: config.contents.map { IconPosition(name: $0.finalName, x: $0.x, y: $0.y) }
        )
    }

    public func records() throws -> [DSStoreRecord] {
        var records: [DSStoreRecord] = [
            DSStoreRecord(filename: ".", code: "bwsp", value: .blob(try windowPlist())),
            DSStoreRecord(filename: ".", code: "icvp", value: .blob(try iconViewPlist())),
            DSStoreRecord(filename: ".", code: "vSrn", value: .long(1)),
        ]
        if case let .image(_, bookmark?) = background {
            records.append(DSStoreRecord(filename: ".", code: "pBBk", value: .blob(bookmark)))
        }
        for position in positions {
            records.append(DSStoreRecord(filename: position.name, code: "Iloc", value: .blob(Self.iconLocation(x: position.x, y: position.y))))
        }
        return records
    }

    // MARK: - Records

    func windowPlist() throws -> Data {
        let plist: [String: Any] = [
            "WindowBounds": "{{\(window.x), \(window.y)}, {\(window.width), \(window.height)}}",
            "ShowToolbar": window.showToolbar,
            "ShowSidebar": window.showSidebar,
            "ContainerShowSidebar": window.showSidebar,
            "ShowStatusBar": window.showStatusBar,
            "ShowPathbar": window.showPathBar,
            // Finder shows a tab bar above the content when this is true.
            "ShowTabView": false,
        ]
        return try Self.binaryPlist(plist)
    }

    func iconViewPlist() throws -> Data {
        var plist: [String: Any] = [
            "viewOptionsVersion": 1,
            "arrangeBy": "none",
            "iconSize": Double(icon.size),
            "textSize": Double(icon.textSize),
            "axTextSize": Double(icon.textSize),
            "labelOnBottom": icon.labelPosition == .bottom,
            "showItemInfo": false,
            "showIconPreview": true,
            "gridSpacing": 100.0,
            "gridOffsetX": 0.0,
            "gridOffsetY": 0.0,
            "backgroundColorRed": 1.0,
            "backgroundColorGreen": 1.0,
            "backgroundColorBlue": 1.0,
        ]
        switch background {
        case .none:
            plist["backgroundType"] = 0
        case .color(let color):
            plist["backgroundType"] = 1
            plist["backgroundColorRed"] = color.redComponent
            plist["backgroundColorGreen"] = color.greenComponent
            plist["backgroundColorBlue"] = color.blueComponent
        case .image(let alias, _):
            plist["backgroundType"] = 2
            plist["backgroundImageAlias"] = alias
        }
        return try Self.binaryPlist(plist)
    }

    /// Icon center x, y as 32-bit values, then Finder's fixed trailer.
    static func iconLocation(x: Int, y: Int) -> Data {
        var d = Data()
        d.appendBE(UInt32(bitPattern: Int32(clamping: x)))
        d.appendBE(UInt32(bitPattern: Int32(clamping: y)))
        d.append(contentsOf: [0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x00, 0x00] as [UInt8])
        return d
    }

    static func binaryPlist(_ object: [String: Any]) throws -> Data {
        try PropertyListSerialization.data(fromPropertyList: object, format: .binary, options: 0)
    }
}
