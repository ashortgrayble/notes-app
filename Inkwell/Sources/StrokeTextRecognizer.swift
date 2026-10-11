import PencilKit

/// Apple's stroke-based handwriting recognizer (PencilKit, iOS 27+). Unlike
/// Vision it reads the pen strokes themselves (order, direction, timing), not a
/// picture of them, which is far better suited to handwriting.
enum StrokeTextRecognizer {
    static var isAvailable: Bool {
        if #available(iOS 27.0, *) { return true }
        return false
    }

    /// The text the strokes spell, or nil if unavailable or nothing was read.
    /// PencilKit expects handwriting at roughly paper scale, so finger-sized
    /// ink is shrunk by `scale` first.
    static func recognize(_ drawing: PKDrawing, scale: CGFloat? = nil) async -> String? {
        guard #available(iOS 27.0, *), !drawing.strokes.isEmpty else { return nil }
        let scale = scale ?? adaptiveScale(for: drawing)

        let bounds = drawing.bounds
        let normalized = drawing.transformed(using:
            CGAffineTransform(translationX: -bounds.minX, y: -bounds.minY)
                .concatenating(CGAffineTransform(scaleX: scale, y: scale))
                .concatenating(CGAffineTransform(translationX: 20, y: 20)))

        let recognizer = PKStrokeRecognizer(preferredLanguages: [Locale.Language(identifier: "en")])
        await recognizer.updateDrawing(normalized)
        let text = await recognizer.recognizedText()?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return text?.isEmpty == false ? text : nil
    }

    /// Writing size varies a lot between people and canvas sizes, so rather
    /// than a fixed shrink factor, scale so the typical stroke is paper-sized.
    static func adaptiveScale(for drawing: PKDrawing) -> CGFloat {
        let heights = drawing.strokes.map { $0.renderBounds.height }.sorted()
        guard let typical = heights.isEmpty ? nil : heights[heights.count / 2], typical > 1 else { return 0.25 }
        return min(max(Tuning.strokeRecognizerTypicalStrokeHeight / typical, 0.1), 1)
    }
}
