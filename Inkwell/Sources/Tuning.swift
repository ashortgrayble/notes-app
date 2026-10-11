import CoreGraphics
import Foundation

/// The knobs that shape how Inkwell feels. Tweak them here.
enum Tuning {
    /// How long the pen must rest before the ink is read. Lower = snappier,
    /// but too low and slow writers get split mid-word.
    static let pauseBeforeCommit: TimeInterval = 0.5

    /// Writing strip height: collapsed, and the most it can expand to (as a
    /// fraction of the screen height).
    static let stripMinHeight: CGFloat = 170
    static let stripMaxHeightFraction: CGFloat = 0.62

    static let inkWidth: CGFloat = 4

    /// Each word is read once per ink-thickness factor, and the best reading wins.
    /// Thicker ink helps Vision with thin or shaky strokes.
    static let inkVariants: [CGFloat] = [1.0, 1.6]
}
