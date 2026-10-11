import CoreGraphics

/// Splits strokes into words by the empty space between them, so a finished
/// word can be read while the next one is still being written.
enum WordSegmenter {
    /// `bounds` are the strokes' bounding boxes in the order they were drawn.
    /// Returns the stroke indices of each word, in order.
    static func groups(of bounds: [CGRect]) -> [[Int]] {
        var groups: [[Int]] = []
        var current = CGRect.null
        for (index, box) in bounds.enumerated() {
            if !groups.isEmpty, belongs(box, to: current) {
                groups[groups.count - 1].append(index)
                current = current.union(box)
            } else {
                groups.append([index])
                current = box
            }
        }
        return groups
    }

    /// A stroke joins the current word if it's close enough sideways (letters,
    /// or an i-dot or t-bar) and not on a different line.
    static func belongs(_ stroke: CGRect, to word: CGRect) -> Bool {
        let height = max(word.height, stroke.height)
        let gapLimit = min(max(height * Tuning.wordGapFactor, Tuning.wordGapMin), Tuning.wordGapMax)
        let dx = max(0, stroke.minX - word.maxX, word.minX - stroke.maxX)
        let dy = max(0, stroke.minY - word.maxY, word.minY - stroke.maxY)
        return dx <= gapLimit && dy <= max(word.height * 0.6, 20)
    }
}
