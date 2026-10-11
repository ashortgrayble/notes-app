import CoreGraphics
import Foundation

/// The knobs that shape how Inkwell feels. Tweak them here.
enum Tuning {
    /// How long the pen must rest before the ink is read. Lower = snappier,
    /// but too low and slow writers get split mid-word.
    static let pauseBeforeCommit: TimeInterval = 0.5

    /// Writing area height while writing (fraction of the screen) and while
    /// reading, when the strip shrinks to a slim "tap to write" bar.
    static let focusedCanvasFraction: CGFloat = 0.55
    static let collapsedCanvasHeight: CGFloat = 44

    static let inkWidth: CGFloat = 4

    /// Each word is read once per ink-thickness factor, and the best reading wins.
    /// Thicker ink helps Vision with thin or shaky strokes.
    static let inkVariants: [CGFloat] = [1.0, 1.6]

    /// If the best two readings of a word score within this margin, the
    /// on-device language model gets to pick using the sentence so far.
    static let contextTieMargin: Double = 0.1
    /// Never make the writer wait longer than this for that tie-break.
    static let contextModelTimeout: TimeInterval = 0.8
}
