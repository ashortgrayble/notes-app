import PencilKit
import UIKit
@preconcurrency import Vision

enum InkRecognizer {
    /// Everything Vision offers for the ink, per ink thickness and per line.
    /// This is the slow, context-free part, so it can run while an earlier
    /// word is still being worked out.
    static func candidates(for drawing: PKDrawing) async -> [[[WordCorrector.Candidate]]] {
        let variants = Tuning.inkVariants.map { drawing.withInkScaled(by: $0) }

        return await withTaskGroup(of: (Int, [[WordCorrector.Candidate]]).self) { group in
            for (i, variant) in variants.enumerated() {
                group.addTask { (i, await lines(in: variant)) }
            }
            var all = [[[WordCorrector.Candidate]]](repeating: [], count: variants.count)
            for await (i, lines) in group { all[i] = lines }
            return all
        }
    }

    /// Picks the reading made of real words that best fits `context` (the
    /// sentence so far). Each word comes back with the other readings that
    /// were close.
    static func read(_ results: [[[WordCorrector.Candidate]]], context: [String]) async -> [RecognizedWord] {
        // Lines are matched up by position (top to bottom) across the variants.
        let primary = results.first(where: { !$0.isEmpty }) ?? []
        var sentence = context
        var words: [RecognizedWord] = []
        for index in primary.indices {
            let pool = results.compactMap { $0.indices.contains(index) ? $0[index] : nil }.flatMap { $0 }
            var readings = WordCorrector.readings(from: pool, context: sentence)
            readings = await ContextRanker.rerank(readings, context: sentence)
            let line = WordCorrector.words(from: readings)
            words += line
            sentence += line.map(\.text)
        }
        return words
    }

    static func recognize(_ drawing: PKDrawing, context: [String] = []) async -> [RecognizedWord] {
        await read(await candidates(for: drawing), context: context)
    }

    /// Runs Vision on one rendering. Each element is a line of text (top to
    /// bottom) holding Vision's alternative readings of that line.
    private static func lines(in drawing: PKDrawing) async -> [[WordCorrector.Candidate]] {
        guard let image = render(drawing)?.cgImage else { return [] }

        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, _ in
                let observations = (request.results as? [VNRecognizedTextObservation] ?? [])
                    .sorted { $0.boundingBox.midY > $1.boundingBox.midY }
                let lines = observations.map { observation in
                    observation.topCandidates(5).map {
                        WordCorrector.Candidate(text: $0.string, confidence: $0.confidence)
                    }
                }
                continuation.resume(returning: lines.filter { !$0.isEmpty })
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US"]

            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try VNImageRequestHandler(cgImage: image).perform([request])
                } catch {
                    continuation.resume(returning: [])
                }
            }
        }
    }

    private static func render(_ drawing: PKDrawing) -> UIImage? {
        guard !drawing.strokes.isEmpty else { return nil }
        let bounds = drawing.bounds.insetBy(dx: -40, dy: -40)
        var ink: UIImage?
        UITraitCollection(userInterfaceStyle: .light).performAsCurrent {
            ink = drawing.image(from: bounds, scale: 3)
        }
        guard let ink else { return nil }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: ink.size, format: format).image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: ink.size))
            ink.draw(at: .zero)
        }
    }
}

extension PKDrawing {
    /// A copy with every stroke's thickness multiplied by `factor`.
    func withInkScaled(by factor: CGFloat) -> PKDrawing {
        guard factor != 1 else { return self }
        return PKDrawing(strokes: strokes.map { stroke in
            let points = stroke.path.map { p in
                PKStrokePoint(location: p.location, timeOffset: p.timeOffset,
                              size: CGSize(width: p.size.width * factor, height: p.size.height * factor),
                              opacity: p.opacity, force: p.force,
                              azimuth: p.azimuth, altitude: p.altitude)
            }
            return PKStroke(ink: stroke.ink,
                            path: PKStrokePath(controlPoints: points, creationDate: stroke.path.creationDate),
                            transform: stroke.transform, mask: stroke.mask)
        })
    }
}
