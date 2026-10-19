import AppKit

/// Renders an approximation of the Finder window to PNG, so layouts can be tuned
/// without building or opening a DMG.
public struct PreviewRenderer: Sendable {
    public enum Appearance: String, Sendable, CaseIterable {
        case light, dark
    }

    /// Height of Finder's title bar plus tab bar above the content area.
    /// Measured at ~68pt on macOS 26; older systems show no tab bar.
    public static var defaultChromeHeight: Int {
        ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 26 ? 68 : 28
    }

    /// Window corner radius; macOS 26 uses noticeably rounder windows.
    public static var defaultCornerRadius: CGFloat {
        ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 26 ? 16 : 10
    }

    public let loaded: LoadedConfig
    public let chromeHeight: Int
    public let cornerRadius: CGFloat
    public let scale: CGFloat

    public init(
        loaded: LoadedConfig,
        chromeHeight: Int = PreviewRenderer.defaultChromeHeight,
        cornerRadius: CGFloat = PreviewRenderer.defaultCornerRadius,
        scale: CGFloat = 2
    ) {
        self.loaded = loaded
        self.chromeHeight = chromeHeight
        self.cornerRadius = cornerRadius
        self.scale = scale
    }

    /// PNG data of the window in the given appearance.
    @MainActor
    public func render(_ appearance: Appearance) throws -> Data {
        let config = loaded.config
        let width = CGFloat(config.window.width)
        let height = CGFloat(config.window.height)
        let chrome = CGFloat(chromeHeight)
        let dark = appearance == .dark

        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let cg = CGContext(
                  data: nil,
                  width: Int(width * scale), height: Int(height * scale),
                  bitsPerComponent: 8, bytesPerRow: 0, space: space,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { throw PreviewError.contextUnavailable }

        // Top-left origin in points, like Finder's icon coordinates.
        cg.translateBy(x: 0, y: height * scale)
        cg.scaleBy(x: scale, y: -scale)

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: cg, flipped: true)
        defer { NSGraphicsContext.restoreGraphicsState() }

        // Rounded window shape; outside stays transparent.
        let bounds = CGRect(x: 0, y: 0, width: width, height: height)
        cg.addPath(CGPath(roundedRect: bounds, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil))
        cg.clip()

        drawChrome(width: width, chrome: chrome, dark: dark)

        // Finder uses black labels on custom backgrounds; only the default background follows the appearance.
        let labelColor: NSColor = (config.background == nil && dark) ? .white : .black

        let content = NSRect(x: 0, y: chrome, width: width, height: Swift.max(height - chrome, 0))
        cg.saveGState()
        cg.clip(to: content)
        drawBackground(in: content, dark: dark)
        for item in config.contents {
            drawItem(item, contentTop: chrome, labelColor: labelColor)
        }
        cg.restoreGState()

        // Window outline.
        (dark ? NSColor(white: 0.35, alpha: 1) : NSColor(white: 0.75, alpha: 1)).setStroke()
        let outline = NSBezierPath(
            roundedRect: NSRect(x: 0.5, y: 0.5, width: width - 1, height: height - 1),
            xRadius: cornerRadius, yRadius: cornerRadius)
        outline.lineWidth = 1
        outline.stroke()

        guard let image = cg.makeImage(),
              let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
        else { throw PreviewError.encodingFailed }
        return png
    }

    // MARK: - Drawing

    @MainActor
    private func drawChrome(width: CGFloat, chrome: CGFloat, dark: Bool) {
        (dark ? NSColor(white: 0.17, alpha: 1) : NSColor(white: 0.93, alpha: 1)).setFill()
        NSRect(x: 0, y: 0, width: width, height: chrome).fill()

        // Traffic lights.
        let lights: [NSColor] = [.systemRed, .systemYellow, .systemGreen]
        for (index, color) in lights.enumerated() {
            color.setFill()
            NSBezierPath(ovalIn: NSRect(x: 14 + CGFloat(index) * 20, y: 9, width: 12, height: 12)).fill()
        }

        let title = NSAttributedString(string: loaded.config.volumeName, attributes: [
            .font: NSFont.boldSystemFont(ofSize: 13),
            .foregroundColor: dark ? NSColor.white : NSColor.black,
        ])
        let size = title.size()
        title.draw(at: NSPoint(x: (width - size.width) / 2, y: 7))
    }

    @MainActor
    private func drawBackground(in content: NSRect, dark: Bool) {
        switch loaded.config.background {
        case nil:
            (dark ? NSColor(white: 0.12, alpha: 1) : NSColor.white).setFill()
            content.fill()
        case .color(let color)?:
            NSColor(srgbRed: color.redComponent, green: color.greenComponent, blue: color.blueComponent, alpha: 1).setFill()
            content.fill()
        case .image(let path)?:
            NSColor.white.setFill()
            content.fill()
            if let image = NSImage(contentsOf: loaded.resolve(path)) {
                // Finder anchors the background at the content's top-left, at point size.
                let rect = NSRect(origin: content.origin, size: image.size)
                image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
            }
        }
    }

    @MainActor
    private func drawItem(_ item: ContentItem, contentTop: CGFloat, labelColor: NSColor) {
        let icon = loaded.config.icon
        let size = CGFloat(icon.size)
        let center = NSPoint(x: CGFloat(item.x), y: contentTop + CGFloat(item.y))
        let iconRect = NSRect(x: center.x - size / 2, y: center.y - size / 2, width: size, height: size)

        let path: String
        switch item.kind {
        case .file(let filePath): path = loaded.resolve(filePath).path
        case .applications: path = "/Applications"
        }
        NSWorkspace.shared.icon(forFile: path)
            .draw(in: iconRect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        let textSize = CGFloat(icon.textSize)
        let labelRect: NSRect
        switch icon.labelPosition {
        case .bottom:
            paragraph.alignment = .center
            let labelWidth = Swift.max(size + 40, 100)
            labelRect = NSRect(x: center.x - labelWidth / 2, y: iconRect.maxY + 4, width: labelWidth, height: textSize * 2.6)
        case .right:
            paragraph.alignment = .left
            labelRect = NSRect(x: iconRect.maxX + 6, y: center.y - textSize * 0.65, width: 180, height: textSize * 2.6)
        }
        let label = NSAttributedString(string: item.displayName, attributes: [
            .font: NSFont.systemFont(ofSize: textSize),
            .foregroundColor: labelColor,
            .paragraphStyle: paragraph,
        ])
        label.draw(with: labelRect, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine])
    }
}

public enum PreviewError: Error, CustomStringConvertible {
    case contextUnavailable
    case encodingFailed

    public var description: String {
        switch self {
        case .contextUnavailable: return "cannot create a drawing context"
        case .encodingFailed: return "cannot encode the preview as PNG"
        }
    }
}
