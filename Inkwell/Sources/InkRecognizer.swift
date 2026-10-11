import PencilKit
import UIKit
@preconcurrency import Vision

enum InkRecognizer {
    /// How the ink is prepared for Vision. The defaults come from `Tuning`.
    struct Settings {
        var inkVariants = Tuning.inkVariants
        var renderScale = Tuning.visionRenderScale
        var padding = Tuning.visionPadding
        var usesLanguageCorrection = Tuning.visionUsesLanguageCorrection
        /// Read the strokes with PencilKit's handwriting recognizer too (iOS 27+).
        var usesStrokeRecognizer = true
        static let standard = Settings()
    }

    /// Every reading on offer for the ink. Index 0 holds what PencilKit's
    /// stroke recognizer made of it (empty if unavailable); the rest hold what
    /// Vision offers per ink thickness. Each is a list of lines (top to bottom)
    /// of alternative readings. This is the slow, context-free part, so it can
    /// run while an earlier word is still being worked out.
    static func candidates(for drawing: PKDrawing, settings: Settings = .standard) async -> [[[WordCorrector.Candidate]]] {
        let variants = settings.inkVariants.map { drawing.withInkScaled(by: $0) }

        return await withTaskGroup(of: (Int, [[WordCorrector.Candidate]]).self) { group in
            if settings.usesStrokeRecognizer {
                group.addTask { (0, await strokeLines(in: drawing)) }
            }
            for (i, variant) in variants.enumerated() {
                group.addTask { (i + 1, await lines(in: variant, settings: settings)) }
            }
            var all = [[[WordCorrector.Candidate]]](repeating: [], count: variants.count + 1)
            for await (i, lines) in group { all[i] = lines }
            return all
        }
    }

    /// Picks the reading made of real words that best fits `context` (the
    /// sentence so far). Each word comes back with the other readings that
    /// were close.
    static func read(_ results: [[[WordCorrector.Candidate]]], context: [String]) async -> [RecognizedWord] {
        let stroke = results.first ?? []
        let vision = results.dropFirst().filter { !$0.isEmpty }

        // Lines are matched up by position across the readings, which only
        // makes sense when they agree on how many lines there are.
        let lineCount = stroke.isEmpty ? (vision.first?.count ?? 0) : stroke.count
        var sentence = context
        var words: [RecognizedWord] = []
        for index in 0..<lineCount {
            var pool = stroke.indices.contains(index) ? stroke[index] : []
            for reading in vision where reading.count == lineCount { pool += reading[index] }
            var readings = WordCorrector.readings(from: pool, context: sentence)
            readings = await ContextRanker.rerank(readings, context: sentence)
            let line = WordCorrector.words(from: readings)
            words += line
            sentence += line.map(\.text)
        }
        return words
    }

    static func recognize(_ drawing: PKDrawing, context: [String] = [], settings: Settings = .standard) async -> [RecognizedWord] {
        await read(await candidates(for: drawing, settings: settings), context: context)
    }

    /// What the stroke recognizer reads, one candidate per line. It's trusted
    /// more than Vision's guesses, but a gibberish reading still loses to a
    /// real word from Vision.
    private static func strokeLines(in drawing: PKDrawing) async -> [[WordCorrector.Candidate]] {
        guard let text = await StrokeTextRecognizer.recognize(drawing) else { return [] }
        return text.split(whereSeparator: \.isNewline)
            .map { [WordCorrector.Candidate(text: String($0), confidence: Tuning.strokeRecognizerConfidence,
                                         bonus: Tuning.strokeRecognizerBonus)] }
    }

    /// Runs Vision on one rendering. Each element is a line of text (top to
    /// bottom) holding Vision's alternative readings of that line.
    private static func lines(in drawing: PKDrawing, settings: Settings) async -> [[WordCorrector.Candidate]] {
        guard let image = render(drawing, settings: settings)?.cgImage else { return [] }

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
            request.usesLanguageCorrection = settings.usesLanguageCorrection
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

    private static func render(_ drawing: PKDrawing, settings: Settings) -> UIImage? {
        guard !drawing.strokes.isEmpty else { return nil }
        let bounds = drawing.bounds.insetBy(dx: -settings.padding, dy: -settings.padding)
        var ink: UIImage?
        UITraitCollection(userInterfaceStyle: .light).performAsCurrent {
            ink = drawing.image(from: bounds, scale: settings.renderScale)
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
