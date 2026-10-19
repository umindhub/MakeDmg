import Foundation
import ImageIO

/// Reads basic image metadata without decoding pixels.
public enum ImageProbe {
    public struct Info: Sendable, Equatable {
        public let width: Int
        public let height: Int
        /// Number of images in the file; >1 for multi-resolution TIFF.
        public let count: Int
        /// Resolution metadata; 72 when absent.
        public let dpiX: Double
        public let dpiY: Double

        /// Size Finder draws at (pixels scaled by DPI).
        public var pointWidth: Int { Int((Double(width) * 72 / dpiX).rounded()) }
        public var pointHeight: Int { Int((Double(height) * 72 / dpiY).rounded()) }
        /// True when one file already carries Retina pixels (144 dpi or more).
        public var isHighDPI: Bool { dpiX >= 143 }
    }

    public static func info(at url: URL) -> Info? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let count = CGImageSourceGetCount(source)
        guard count > 0,
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = props[kCGImagePropertyPixelWidth] as? Int,
              let height = props[kCGImagePropertyPixelHeight] as? Int
        else { return nil }
        let dpiX = (props[kCGImagePropertyDPIWidth] as? Double).flatMap { $0 > 0 ? $0 : nil } ?? 72
        let dpiY = (props[kCGImagePropertyDPIHeight] as? Double).flatMap { $0 > 0 ? $0 : nil } ?? dpiX
        return Info(width: width, height: height, count: count, dpiX: dpiX, dpiY: dpiY)
    }

    /// "bg.png" -> "bg@2x.png" in the same folder.
    public static func retinaVariant(of url: URL) -> URL {
        let ext = url.pathExtension
        let stem = url.deletingPathExtension().lastPathComponent
        let name = ext.isEmpty ? "\(stem)@2x" : "\(stem)@2x.\(ext)"
        return url.deletingLastPathComponent().appendingPathComponent(name)
    }
}
