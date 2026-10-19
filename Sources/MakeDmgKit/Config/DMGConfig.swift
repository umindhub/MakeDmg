import Foundation

/// Root of a makedmg JSON config. Paths are kept as written; resolve them via LoadedConfig.
public struct DMGConfig: Sendable, Equatable {
    public var volumeName: String
    public var output: String
    public var format: ImageFormat
    public var filesystem: Filesystem
    public var window: WindowConfig
    public var icon: IconConfig
    public var background: Background?
    public var contents: [ContentItem]
    public var volumeIcon: String?
    public var sign: SignConfig?
    public var notarize: NotarizeConfig?
}

// MARK: - Enums

public enum ImageFormat: String, CaseIterable, Sendable, Decodable {
    case udzo = "UDZO"  // zlib, widest compatibility
    case udbz = "UDBZ"  // bzip2
    case ulfo = "ULFO"  // lzfse, macOS 10.11+
    case ulmo = "ULMO"  // lzma, macOS 10.15+

    public init(from decoder: Decoder) throws { self = try decodeChoice(decoder) }
}

public enum Filesystem: String, CaseIterable, Sendable, Decodable {
    case hfsPlus = "HFS+"
    case apfs = "APFS"

    public init(from decoder: Decoder) throws { self = try decodeChoice(decoder) }
}

public enum LabelPosition: String, CaseIterable, Sendable, Decodable {
    case bottom
    case right

    public init(from decoder: Decoder) throws { self = try decodeChoice(decoder) }
}

/// Case-insensitive string enum decoding with a readable error.
func decodeChoice<T: CaseIterable & RawRepresentable>(_ decoder: Decoder) throws -> T where T.RawValue == String {
    let container = try decoder.singleValueContainer()
    let raw = try container.decode(String.self)
    if let match = T.allCases.first(where: { $0.rawValue.caseInsensitiveCompare(raw) == .orderedSame }) {
        return match
    }
    let choices = T.allCases.map(\.rawValue).joined(separator: ", ")
    throw DecodingError.dataCorruptedError(in: container, debugDescription: "invalid value '\(raw)', expected one of: \(choices)")
}

// MARK: - Window

public struct WindowConfig: Sendable, Equatable {
    public var x = 200
    public var y = 120
    public var width = 640
    public var height = 400
    public var showToolbar = false
    public var showSidebar = false
    public var showStatusBar = false
    public var showPathBar = false

    public init() {}
}

extension WindowConfig: Decodable {
    enum CodingKeys: String, CodingKey, CaseIterable {
        case x, y, width, height, showToolbar, showSidebar, showStatusBar, showPathBar
    }

    static var knownKeys: Set<String> { Set(CodingKeys.allCases.map(\.rawValue)) }

    public init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        x = try c.decodeIfPresent(Int.self, forKey: .x) ?? x
        y = try c.decodeIfPresent(Int.self, forKey: .y) ?? y
        width = try c.decodeIfPresent(Int.self, forKey: .width) ?? width
        height = try c.decodeIfPresent(Int.self, forKey: .height) ?? height
        showToolbar = try c.decodeIfPresent(Bool.self, forKey: .showToolbar) ?? showToolbar
        showSidebar = try c.decodeIfPresent(Bool.self, forKey: .showSidebar) ?? showSidebar
        showStatusBar = try c.decodeIfPresent(Bool.self, forKey: .showStatusBar) ?? showStatusBar
        showPathBar = try c.decodeIfPresent(Bool.self, forKey: .showPathBar) ?? showPathBar
    }
}

// MARK: - Icon

public struct IconConfig: Sendable, Equatable {
    public var size = 128
    /// 16 matches create-dmg's default; Finder's own default is 12.
    public var textSize = 16
    public var labelPosition: LabelPosition = .bottom

    public init() {}
}

extension IconConfig: Decodable {
    enum CodingKeys: String, CodingKey, CaseIterable {
        case size, textSize, labelPosition
    }

    static var knownKeys: Set<String> { Set(CodingKeys.allCases.map(\.rawValue)) }

    public init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        size = try c.decodeIfPresent(Int.self, forKey: .size) ?? size
        textSize = try c.decodeIfPresent(Int.self, forKey: .textSize) ?? textSize
        labelPosition = try c.decodeIfPresent(LabelPosition.self, forKey: .labelPosition) ?? labelPosition
    }
}

// MARK: - Background

public enum Background: Sendable, Equatable {
    case color(HexColor)
    case image(String)
}

extension Background: Decodable {
    enum CodingKeys: String, CodingKey, CaseIterable {
        case color, image
    }

    static var knownKeys: Set<String> { Set(CodingKeys.allCases.map(\.rawValue)) }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let color = try c.decodeIfPresent(HexColor.self, forKey: .color)
        let image = try c.decodeIfPresent(String.self, forKey: .image)
        switch (color, image) {
        case let (color?, nil):
            self = .color(color)
        case let (nil, image?):
            self = .image(image)
        case (nil, nil):
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath,
                debugDescription: "set either \"color\" or \"image\""
            ))
        default:
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath,
                debugDescription: "\"color\" and \"image\" are mutually exclusive"
            ))
        }
    }
}

// MARK: - Contents

public struct ContentItem: Sendable, Equatable {
    public enum Kind: Sendable, Equatable {
        case file(path: String)
        case applications
    }

    public var kind: Kind
    public var name: String?
    public var x: Int
    public var y: Int
    /// Hide the file extension in Finder ("AppPad" instead of "AppPad.app").
    public var hideExtension = false

    /// Name of the entry inside the DMG.
    public var finalName: String {
        if let name { return name }
        switch kind {
        case .file(let path): return (path as NSString).lastPathComponent
        case .applications: return "Applications"
        }
    }

    /// Label Finder shows under the icon.
    public var displayName: String {
        hideExtension ? (finalName as NSString).deletingPathExtension : finalName
    }

    public var isFile: Bool {
        if case .file = kind { return true }
        return false
    }
}

extension ContentItem: Decodable {
    enum CodingKeys: String, CodingKey, CaseIterable {
        case type, path, name, x, y, hideExtension
    }

    static var knownKeys: Set<String> { Set(CodingKeys.allCases.map(\.rawValue)) }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decodeIfPresent(String.self, forKey: .type)?.lowercased() ?? "file"
        let path = try c.decodeIfPresent(String.self, forKey: .path)

        switch type {
        case "file":
            guard let path else {
                throw DecodingError.keyNotFound(CodingKeys.path, .init(
                    codingPath: decoder.codingPath,
                    debugDescription: "file item requires \"path\""
                ))
            }
            kind = .file(path: path)
        case "applications":
            guard path == nil else {
                throw DecodingError.dataCorruptedError(
                    forKey: .path, in: c,
                    debugDescription: "\"path\" is not allowed for an applications link"
                )
            }
            kind = .applications
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type, in: c,
                debugDescription: "invalid type '\(type)', expected one of: file, applications"
            )
        }

        name = try c.decodeIfPresent(String.self, forKey: .name)
        x = try c.decode(Int.self, forKey: .x)
        y = try c.decode(Int.self, forKey: .y)
        hideExtension = try c.decodeIfPresent(Bool.self, forKey: .hideExtension) ?? false
    }
}

// MARK: - Signing

public struct SignConfig: Sendable, Equatable, Decodable {
    public var identity: String

    enum CodingKeys: String, CodingKey, CaseIterable { case identity }
    static var knownKeys: Set<String> { Set(CodingKeys.allCases.map(\.rawValue)) }
}

public struct NotarizeConfig: Sendable, Equatable, Decodable {
    public var keychainProfile: String

    enum CodingKeys: String, CodingKey, CaseIterable { case keychainProfile }
    static var knownKeys: Set<String> { Set(CodingKeys.allCases.map(\.rawValue)) }
}

// MARK: - Root decoding

extension DMGConfig: Decodable {
    enum CodingKeys: String, CodingKey, CaseIterable {
        case volumeName, output, format, filesystem, window, icon
        case background, contents, volumeIcon, sign, notarize
    }

    /// "$schema" is accepted so editors can attach a JSON schema later.
    static var knownKeys: Set<String> { Set(CodingKeys.allCases.map(\.rawValue)).union(["$schema"]) }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        volumeName = try c.decode(String.self, forKey: .volumeName)
        output = try c.decode(String.self, forKey: .output)
        format = try c.decodeIfPresent(ImageFormat.self, forKey: .format) ?? .ulfo
        filesystem = try c.decodeIfPresent(Filesystem.self, forKey: .filesystem) ?? .hfsPlus
        window = try c.decodeIfPresent(WindowConfig.self, forKey: .window) ?? WindowConfig()
        icon = try c.decodeIfPresent(IconConfig.self, forKey: .icon) ?? IconConfig()
        background = try c.decodeIfPresent(Background.self, forKey: .background)
        contents = try c.decode([ContentItem].self, forKey: .contents)
        volumeIcon = try c.decodeIfPresent(String.self, forKey: .volumeIcon)
        sign = try c.decodeIfPresent(SignConfig.self, forKey: .sign)
        notarize = try c.decodeIfPresent(NotarizeConfig.self, forKey: .notarize)
    }
}
