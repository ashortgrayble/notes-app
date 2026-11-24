import Foundation
import SwiftUI

/// The knobs that shape how Inkwell feels. Tweak them here.
enum Tuning {
    /// How long the pen must rest before the ink is read. Lower = snappier,
    /// but too low and slow writers get split mid-word.
    static let pauseBeforeCommit: TimeInterval = 0.3

    /// Writing area height while writing (fraction of the screen) and while
    /// reading, when the strip shrinks to a slim "tap to write" bar.
    static let focusedCanvasFraction: CGFloat = 0.55
    static let collapsedCanvasHeight: CGFloat = 44

    static let inkWidth: CGFloat = 4

    /// Each word is read once per ink-thickness factor, and the best reading wins.
    /// Thicker ink helps Vision with thin or shaky strokes.
    static let inkVariants: [CGFloat] = [1.0, 1.6]
    static let visionRenderScale: CGFloat = 3
    static let visionPadding: CGFloat = 100
    static let visionUsesLanguageCorrection = true

    /// If the best two readings of a word score within this margin, the
    /// on-device language model gets to pick using the sentence so far.
    static let contextTieMargin: Double = 0.1
    /// Never make the writer wait longer than this for that tie-break.
    static let contextModelTimeout: TimeInterval = 0.5

    /// PencilKit's stroke recognizer works best with paper-sized handwriting.
    /// The median stroke is scaled to about this height (points) before reading.
    static let strokeRecognizerTypicalStrokeHeight: CGFloat = 9
    /// How much the stroke recognizer's reading is trusted over Vision's guesses.
    static let strokeRecognizerConfidence: Float = 0.9
    static let strokeRecognizerBonus: Double = 0.15

    // MARK: Streaming

    /// Strokes closer together than this (relative to the writing's height,
    /// clamped to the min/max in points) belong to the same word. When the next
    /// word begins, the finished one is read and cleared while you keep writing.
    static let wordGapFactor: CGFloat = 0.5
    static let wordGapMin: CGFloat = 24
    static let wordGapMax: CGFloat = 80

    // MARK: Motion (kept deliberately calm)

    /// A new word floats from where it was written to its place in the note.
    static let floatResponse: Double = 0.4
    static let floatDamping: Double = 0.92
    static let floatBlur: CGFloat = 2
    static let floatStartScale: CGFloat = 0.95

    /// Strip growing/shrinking, scrolling, and the alternatives card.
    static let panelAnimation: Animation = .easeInOut(duration: 0.2)
    static let scrollAnimation: Animation = .easeOut(duration: 0.25)
    static let cardAnimation: Animation = .easeOut(duration: 0.12)
}
