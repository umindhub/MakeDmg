import Foundation

/// Semantic checks on a loaded config: files exist, values in range, layout sanity.
public struct ConfigValidator: Sendable {
    /// Below this luminance Finder's black label text is hard to read.
    public static let darkBackgroundThreshold = 0.18

    /// Names makedmg itself writes at the volume root.
    static let reservedNames: Set<String> = [".background", ".VolumeIcon.icns", ".DS_Store", ".fseventsd", ".Trashes"]

    static let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "tif", "tiff"]

    public init() {}

    public func validate(_ loaded: LoadedConfig) -> [ConfigIssue] {
        var issues: [ConfigIssue] = []
        let config = loaded.config
        checkVolume(config, &issues)
        checkWindow(config.window, &issues)
        checkIcon(config.icon, &issues)
        checkContents(loaded, &issues)
        checkLayout(config, &issues)
        checkBackground(loaded, &issues)
        checkVolumeIcon(loaded, &issues)
        checkSigning(config, &issues)
        return issues
    }

    // MARK: - Sections

    private func checkVolume(_ c: DMGConfig, _ issues: inout [ConfigIssue]) {
        if c.volumeName.trimmingCharacters(in: .whitespaces).isEmpty {
            issues.append(.error("volumeName", "must not be empty"))
        } else if c.volumeName.contains(":") {
            issues.append(.error("volumeName", "must not contain ':'"))
        }

        if c.output.trimmingCharacters(in: .whitespaces).isEmpty {
            issues.append(.error("output", "must not be empty"))
        } else if (c.output as NSString).pathExtension.lowercased() != "dmg" {
            issues.append(.warning("output", "file name does not end with .dmg"))
        }
    }

    private func checkWindow(_ w: WindowConfig, _ issues: inout [ConfigIssue]) {
        if w.width < 100 { issues.append(.error("window.width", "must be at least 100")) }
        if w.height < 100 { issues.append(.error("window.height", "must be at least 100")) }
        if w.x < 0 || w.y < 0 {
            issues.append(.warning("window", "negative x/y may open the window off-screen"))
        }
    }

    private func checkIcon(_ icon: IconConfig, _ issues: inout [ConfigIssue]) {
        if !(16...512).contains(icon.size) {
            issues.append(.error("icon.size", "must be between 16 and 512"))
        }
        if !(10...16).contains(icon.textSize) {
            issues.append(.error("icon.textSize", "must be between 10 and 16"))
        }
    }

    private func checkContents(_ loaded: LoadedConfig, _ issues: inout [ConfigIssue]) {
        let items = loaded.config.contents
        if items.isEmpty {
            issues.append(.error("contents", "must contain at least one item"))
            return
        }
        if !items.contains(where: \.isFile) {
            issues.append(.error("contents", "must contain at least one file"))
        }

        var seenNames: [String: Int] = [:]  // lowercased name -> index (HFS+ and APFS default are case-insensitive)
        var applicationsIndex: Int?

        for (index, item) in items.enumerated() {
            let path = "contents[\(index)]"

            switch item.kind {
            case .file(let filePath):
                let url = loaded.resolve(filePath)
                if !FileManager.default.fileExists(atPath: url.path) {
                    issues.append(.error("\(path).path", "file not found: \(url.path)"))
                }
            case .applications:
                if item.hideExtension {
                    issues.append(.warning("\(path).hideExtension", "ignored for the applications link"))
                }
                if let first = applicationsIndex {
                    issues.append(.error(path, "duplicate applications link (already at contents[\(first)])"))
                } else {
                    applicationsIndex = index
                }
            }

            let name = item.finalName
            if name.isEmpty {
                issues.append(.error("\(path).name", "must not be empty"))
                continue
            }
            if name.contains("/") {
                issues.append(.error("\(path).name", "must not contain '/'"))
            }
            if Self.reservedNames.contains(name) {
                issues.append(.error("\(path).name", "'\(name)' is reserved by makedmg"))
            } else if name.hasPrefix(".") {
                issues.append(.warning("\(path).name", "names starting with '.' are hidden in Finder"))
            }
            if let other = seenNames[name.lowercased()] {
                issues.append(.error("\(path).name", "duplicate name '\(name)' (also used by contents[\(other)])"))
            } else {
                seenNames[name.lowercased()] = index
            }
        }
    }

    private func checkLayout(_ c: DMGConfig, _ issues: inout [ConfigIssue]) {
        let size = c.icon.size
        let half = size / 2
        // Rough label height below the icon; labels on the right are not measured.
        let labelHeight = c.icon.labelPosition == .bottom ? c.icon.textSize * 2 + 4 : 0
        let items = c.contents

        for (index, item) in items.enumerated() {
            let clipped = item.x - half < 0
                || item.x + half > c.window.width
                || item.y - half < 0
                || item.y + half + labelHeight > c.window.height
            if clipped {
                issues.append(.warning("contents[\(index)]",
                    "icon at (\(item.x), \(item.y)) may be clipped by the \(c.window.width)x\(c.window.height) window"))
            }
        }

        for i in items.indices {
            for j in (i + 1)..<items.count {
                let a = items[i], b = items[j]
                if abs(a.x - b.x) < size && abs(a.y - b.y) < size + labelHeight {
                    issues.append(.warning("contents[\(j)]", "overlaps contents[\(i)]"))
                }
            }
        }
    }

    private func checkBackground(_ loaded: LoadedConfig, _ issues: inout [ConfigIssue]) {
        guard let background = loaded.config.background else { return }
        let window = loaded.config.window

        switch background {
        case .color(let color):
            if color.relativeLuminance < Self.darkBackgroundThreshold {
                issues.append(.warning("background.color",
                    "\(color) is dark; Finder draws file names in black on custom backgrounds, so they will be hard to read"))
            }

        case .image(let imagePath):
            // The alias format for APFS volumes is not verified yet.
            if loaded.config.filesystem == .apfs {
                issues.append(.error("background.image", "image backgrounds currently require \"filesystem\": \"HFS+\""))
            }
            let url = loaded.resolve(imagePath)
            guard FileManager.default.fileExists(atPath: url.path) else {
                issues.append(.error("background.image", "file not found: \(url.path)"))
                return
            }
            let ext = url.pathExtension.lowercased()
            guard Self.imageExtensions.contains(ext) else {
                issues.append(.error("background.image", "unsupported format '.\(ext)', use png, jpg or tiff"))
                return
            }
            guard let info = ImageProbe.info(at: url) else {
                issues.append(.error("background.image", "cannot read image: \(url.path)"))
                return
            }
            // Finder draws at point size, so a 144+ dpi file is already Retina-sized.
            if info.pointWidth != window.width || info.pointHeight > window.height {
                let pixels = info.isHighDPI ? " (\(info.width)x\(info.height) px at \(Int(info.dpiX)) dpi)" : ""
                let visible = window.height - PreviewRenderer.defaultChromeHeight
                issues.append(.warning("background.image",
                    "image is \(info.pointWidth)x\(info.pointHeight) pt\(pixels), window is \(window.width)x\(window.height); about \(visible) pt of height is visible below the title bar"))
            }

            // A multi-image TIFF or a high-dpi file already carries Retina pixels.
            let isMultiResTIFF = (ext == "tif" || ext == "tiff") && info.count > 1
            if !isMultiResTIFF && !info.isHighDPI {
                checkRetinaVariant(of: url, base: info, &issues)
            }
        }
    }

    private func checkRetinaVariant(of url: URL, base: ImageProbe.Info, _ issues: inout [ConfigIssue]) {
        let retina = ImageProbe.retinaVariant(of: url)
        guard FileManager.default.fileExists(atPath: retina.path) else {
            issues.append(.warning("background.image",
                "no \(retina.lastPathComponent) found; the background will look blurry on Retina displays"))
            return
        }
        guard let info = ImageProbe.info(at: retina) else {
            issues.append(.error("background.image", "cannot read image: \(retina.path)"))
            return
        }
        if info.width != base.width * 2 || info.height != base.height * 2 {
            issues.append(.warning("background.image",
                "\(retina.lastPathComponent) is \(info.width)x\(info.height), expected \(base.width * 2)x\(base.height * 2)"))
        }
    }

    private func checkVolumeIcon(_ loaded: LoadedConfig, _ issues: inout [ConfigIssue]) {
        guard let iconPath = loaded.config.volumeIcon else { return }
        let url = loaded.resolve(iconPath)
        if !FileManager.default.fileExists(atPath: url.path) {
            issues.append(.error("volumeIcon", "file not found: \(url.path)"))
        } else if url.pathExtension.lowercased() != "icns" {
            issues.append(.error("volumeIcon", "must be an .icns file"))
        }
    }

    private func checkSigning(_ c: DMGConfig, _ issues: inout [ConfigIssue]) {
        if let sign = c.sign, sign.identity.trimmingCharacters(in: .whitespaces).isEmpty {
            issues.append(.error("sign.identity", "must not be empty"))
        }
        if let notarize = c.notarize {
            if notarize.keychainProfile.trimmingCharacters(in: .whitespaces).isEmpty {
                issues.append(.error("notarize.keychainProfile", "must not be empty"))
            }
            if c.sign == nil {
                issues.append(.error("notarize", "requires \"sign\"; notarization needs a signed DMG"))
            }
        }
    }
}
