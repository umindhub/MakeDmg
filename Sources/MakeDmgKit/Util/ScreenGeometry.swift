import CoreGraphics

/// Finder stores WindowBounds in Cocoa global coordinates (origin at the bottom-left
/// of the main display). Config uses a top-left origin like create-dmg, so y is flipped.
public enum ScreenGeometry {
    /// Main display height in points, nil when no display is available (e.g. headless CI).
    public static func mainScreenHeight() -> Int? {
        let height = Int(CGDisplayBounds(CGMainDisplayID()).height)
        return height > 0 ? height : nil
    }

    /// Converts a top-left y to Finder's bottom-left y for a window of the given height.
    public static func finderY(topLeftY: Int, windowHeight: Int, screenHeight: Int) -> Int {
        screenHeight - topLeftY - windowHeight
    }
}
