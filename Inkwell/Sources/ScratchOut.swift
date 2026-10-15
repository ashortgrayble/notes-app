import CoreGraphics
import Foundation

/// The scratch-out gesture: drag back and forth across words in the note to
/// strike them out and delete them. Pure geometry, so it's easy to test.
enum ScratchOut {
    /// Roughly how far (points) a stroke-through must run, and how tall it may be.
    static let minWidth: CGFloat = 28
    static let maxHeight: CGFloat = 44

    /// A mostly-sideways scribble: wide, shallow, and longer than it is tall.
    static func isStrike(_ points: [CGPoint], minWidth: CGFloat = minWidth) -> Bool {
        let box = bounds(of: points)
        return points.count >= 3 && box.width >= minWidth && box.height <= maxHeight && box.width >= box.height * 1.4
    }

    /// The words a scribble crosses: its line passes through the word's row and
    /// it covers at least half the word's width.
    static func words(struckBy points: [CGPoint], frames: [UUID: CGRect]) -> Set<UUID> {
        guard isStrike(points) else { return [] }
        let box = bounds(of: points)
        var hit = Set<UUID>()
        for (id, frame) in frames {
            let row = frame.insetBy(dx: 0, dy: -4)
            guard row.minY...row.maxY ~= box.midY else { continue }
            let overlap = min(box.maxX, frame.maxX) - max(box.minX, frame.minX)
            if overlap >= frame.width * 0.5 { hit.insert(id) }
        }
        return hit
    }

    private static func bounds(of points: [CGPoint]) -> CGRect {
        guard let first = points.first else { return .null }
        var minX = first.x, maxX = first.x, minY = first.y, maxY = first.y
        for p in points {
            minX = min(minX, p.x); maxX = max(maxX, p.x)
            minY = min(minY, p.y); maxY = max(maxY, p.y)
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}
