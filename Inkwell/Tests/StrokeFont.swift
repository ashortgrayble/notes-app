import PencilKit
import UIKit

/// A tiny single-line "handwriting" font, for benchmarking recognizers on
/// stroke data without a human. Letters are polylines in a unit space where
/// the baseline is y = 0, the x-height line is y = -1, ascenders reach -2 and
/// descenders +1. Jitter, slant and size variation make each word look hand-drawn.
struct StrokeFont {
    struct Style {
        var xHeight: CGFloat = 36
        var slant: CGFloat = 0.12
        var jitter: CGFloat = 0.05
        var sizeVariation: CGFloat = 0.08
        var letterGap: CGFloat = 0.28
    }

    private static func arc(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat,
                            from a0: CGFloat, to a1: CGFloat, steps: Int = 18) -> [CGPoint] {
        (0...steps).map { i in
            let a = (a0 + (a1 - a0) * CGFloat(i) / CGFloat(steps)) * .pi / 180
            return CGPoint(x: cx + rx * cos(a), y: cy + ry * sin(a))
        }
    }

    private static func line(_ pts: (CGFloat, CGFloat)...) -> [CGPoint] {
        pts.map { CGPoint(x: $0.0, y: $0.1) }
    }

    private static let bowl = arc(0.45, -0.5, 0.45, 0.5, from: 180, to: 540)
    private static let circle = arc(0.45, -0.5, 0.45, 0.5, from: 0, to: 360)

    /// strokes and advance width per letter
    private static let glyphs: [Character: (strokes: [[CGPoint]], advance: CGFloat)] = [
        "a": ([circle, line((0.9, -1), (0.9, 0))], 1.3),
        "b": ([line((0, -2), (0, 0)), bowl], 1.3),
        "c": ([arc(0.5, -0.5, 0.5, 0.5, from: -40, to: -320)], 1.1),
        "d": ([circle, line((0.9, -2), (0.9, 0))], 1.3),
        "e": ([line((0.0, -0.5), (0.9, -0.5)) + arc(0.45, -0.5, 0.45, 0.5, from: 0, to: -320)], 1.2),
        "f": ([line((0.45, 0), (0.45, -1.7)) + arc(0.8, -1.7, 0.35, 0.3, from: 180, to: 280, steps: 8),
               line((0, -1), (0.9, -1))], 1.1),
        "g": ([circle, line((0.9, -1), (0.9, 0.5)) + arc(0.45, 0.5, 0.45, 0.45, from: 0, to: 160, steps: 10)], 1.3),
        "h": ([line((0, -2), (0, 0)),
               arc(0.4, -0.6, 0.4, 0.4, from: 180, to: 360, steps: 10) + line((0.8, -0.6), (0.8, 0))], 1.2),
        "i": ([line((0.05, -1), (0.05, 0)), line((0.05, -1.5), (0.07, -1.48))], 0.45),
        "j": ([line((0.3, -1), (0.3, 0.4)) + arc(0, 0.4, 0.3, 0.3, from: 0, to: 110, steps: 8),
               line((0.3, -1.5), (0.32, -1.48))], 0.6),
        "k": ([line((0, -2), (0, 0)), line((0.8, -1), (0, -0.35)), line((0.2, -0.5), (0.85, 0))], 1.1),
        "l": ([line((0.05, -2), (0.05, 0))], 0.4),
        "m": ([line((0, -1), (0, 0)),
               arc(0.3, -0.55, 0.3, 0.3, from: 180, to: 360, steps: 8) + line((0.6, -0.55), (0.6, 0)),
               arc(0.9, -0.55, 0.3, 0.3, from: 180, to: 360, steps: 8) + line((1.2, -0.55), (1.2, 0))], 1.6),
        "n": ([line((0, -1), (0, 0)),
               arc(0.4, -0.6, 0.4, 0.4, from: 180, to: 360, steps: 10) + line((0.8, -0.6), (0.8, 0))], 1.2),
        "o": ([circle], 1.3),
        "p": ([line((0, -1), (0, 1)), bowl], 1.3),
        "q": ([circle, line((0.9, -1), (0.9, 1))], 1.3),
        "r": ([line((0, -1), (0, 0)), arc(0.4, -0.6, 0.4, 0.4, from: 180, to: 300, steps: 8)], 0.9),
        "s": ([line((0.8, -0.9), (0.5, -1), (0.15, -0.85), (0.15, -0.65), (0.45, -0.5),
                    (0.75, -0.35), (0.75, -0.15), (0.45, 0), (0.1, -0.1))], 0.95),
        "t": ([line((0.3, -1.6), (0.3, 0)), line((0, -1), (0.65, -1))], 0.85),
        "u": ([line((0, -1), (0, -0.3)) + arc(0.4, -0.3, 0.4, 0.3, from: 180, to: 0, steps: 10),
               line((0.8, -1), (0.8, 0))], 1.2),
        "v": ([line((0, -1), (0.4, 0), (0.8, -1))], 1.1),
        "w": ([line((0, -1), (0.3, 0), (0.6, -0.9), (0.9, 0), (1.2, -1))], 1.5),
        "x": ([line((0, -1), (0.8, 0)), line((0.8, -1), (0, 0))], 1.1),
        "y": ([line((0, -1), (0.4, 0)), line((0.8, -1), (0.3, 0.9))], 1.1),
        "z": ([line((0, -1), (0.8, -1), (0, 0), (0.8, 0))], 1.1),
    ]

    /// Draws `word` as ink. A given `seed` always gives the same drawing.
    static func drawing(for word: String, style: Style = Style(), seed: UInt64) -> PKDrawing {
        var rng = SeededRandom(seed: seed)
        var strokes: [PKStroke] = []
        var cursor: CGFloat = 0
        var time: TimeInterval = 0
        let origin = CGPoint(x: 40, y: 120)

        // slow wobble shared across the word, so the baseline drifts a little
        let driftPhase = rng.next(in: 0...6.28)
        let driftSize = rng.next(in: 0...0.12)

        for letter in word {
            guard let glyph = glyphs[letter] else { continue }
            let scale = style.xHeight * (1 + rng.next(in: -style.sizeVariation...style.sizeVariation))
            let lift = rng.next(in: -0.06...0.06) + sin(driftPhase + cursor * 0.6) * driftSize

            for polyline in glyph.strokes {
                var points: [PKStrokePoint] = []
                for p in resample(polyline, spacing: 0.09) {
                    let noiseX = rng.next(in: -style.jitter...style.jitter)
                    let noiseY = rng.next(in: -style.jitter...style.jitter)
                    let ux = cursor + p.x + noiseX
                    let uy = p.y + lift + noiseY
                    let location = CGPoint(x: origin.x + (ux - uy * style.slant) * scale,
                                           y: origin.y + uy * scale)
                    points.append(PKStrokePoint(location: location, timeOffset: time,
                                                size: CGSize(width: 4, height: 4), opacity: 1, force: 1,
                                                azimuth: 0, altitude: .pi / 2))
                    time += 0.012
                }
                time += 0.15 // pen lift between strokes
                guard points.count > 1 else { continue }
                strokes.append(PKStroke(ink: PKInk(.pen, color: .black),
                                        path: PKStrokePath(controlPoints: points, creationDate: Date(timeIntervalSince1970: 0))))
            }
            cursor += glyph.advance + style.letterGap
        }
        return PKDrawing(strokes: strokes)
    }

    private static func resample(_ polyline: [CGPoint], spacing: CGFloat) -> [CGPoint] {
        guard var last = polyline.first else { return [] }
        var out = [last]
        for next in polyline.dropFirst() {
            let dx = next.x - last.x, dy = next.y - last.y
            let length = hypot(dx, dy)
            let steps = max(1, Int(length / spacing))
            for i in 1...steps {
                let t = CGFloat(i) / CGFloat(steps)
                out.append(CGPoint(x: last.x + dx * t, y: last.y + dy * t))
            }
            last = next
        }
        return out
    }
}

struct SeededRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed &* 6364136223846793005 &+ 1442695040888963407 }

    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    mutating func next(in range: ClosedRange<CGFloat>) -> CGFloat {
        range.lowerBound + (range.upperBound - range.lowerBound) * CGFloat(Double(next() >> 11) / Double(1 << 53))
    }
}
