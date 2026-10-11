import PencilKit
import XCTest
@testable import Inkwell

/// Measures how often each recognizer reads synthetic handwriting correctly.
/// Slow, so it only runs when asked:
///   TEST_RUNNER_BENCHMARK=1 xcodebuild test ... -only-testing:InkwellTests/RecognitionBenchmarkTests
final class RecognitionBenchmarkTests: XCTestCase {
    static let words = [
        "the", "and", "hello", "world", "interesting", "write", "note", "think", "about", "because",
        "morning", "coffee", "remember", "tomorrow", "meeting", "idea", "simple", "garden", "light", "water",
        "friend", "quick", "brown", "jumps", "over", "lazy", "dog", "park", "walk", "story",
    ]

    private func samples() -> [(word: String, drawing: PKDrawing)] {
        var out: [(String, PKDrawing)] = []
        for (w, word) in Self.words.enumerated() {
            for variant in 0..<4 {
                var rng = SeededRandom(seed: UInt64(w * 100 + variant))
                let style = StrokeFont.Style(xHeight: rng.next(in: 30...46),
                                             slant: rng.next(in: 0.02...0.22),
                                             jitter: rng.next(in: 0.03...0.09),
                                             sizeVariation: rng.next(in: 0.04...0.12),
                                             letterGap: rng.next(in: 0.2...0.38))
                out.append((word, StrokeFont.drawing(for: word, style: style, seed: UInt64(w * 100 + variant))))
            }
        }
        return out
    }

    private func sizedSamples() -> [(word: String, size: CGFloat, drawing: PKDrawing)] {
        var out: [(String, CGFloat, PKDrawing)] = []
        for (w, word) in Self.words.enumerated() {
            for (v, size) in ([18, 28, 45, 70, 100] as [CGFloat]).enumerated() {
                var rng = SeededRandom(seed: UInt64(w * 100 + v + 7))
                let style = StrokeFont.Style(xHeight: size, slant: rng.next(in: 0.02...0.22),
                                             jitter: rng.next(in: 0.03...0.09), sizeVariation: 0.08,
                                             letterGap: rng.next(in: 0.2...0.38))
                out.append((word, size, StrokeFont.drawing(for: word, style: style, seed: UInt64(w * 100 + v + 7))))
            }
        }
        return out
    }

    private func report(_ title: String, _ tallies: [String: Int], total: Int) {
        print("BENCH == \(title) (n=\(total))")
        for (name, hits) in tallies.sorted(by: { $0.key < $1.key }) {
            print("BENCH   \(name.padding(toLength: 34, withPad: " ", startingAt: 0)) \(String(format: "%5.1f", Double(hits) / Double(total) * 100))%")
        }
    }

    /// Does the stroke recognizer cope with writing of any size?
    func testStrokeRecognizerAcrossSizes() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["BENCHMARK"] != nil, "benchmark only runs on request")
        let samples = sizedSamples()
        var tallies: [String: Int] = [:]
        for (word, size, drawing) in samples {
            let adaptive = await StrokeTextRecognizer.recognize(drawing)
            if adaptive?.lowercased() == word { tallies["adaptive, x-height \(Int(size))", default: 0] += 1 }
            let fixed = await StrokeTextRecognizer.recognize(drawing, scale: 0.25)
            if fixed?.lowercased() == word { tallies["fixed 0.25, x-height \(Int(size))", default: 0] += 1 }
        }
        // each size has Self.words.count samples
        print("BENCH == stroke recognizer across writing sizes (n=\(Self.words.count) each)")
        for (name, hits) in tallies.sorted(by: { $0.key < $1.key }) {
            print("BENCH   \(name.padding(toLength: 34, withPad: " ", startingAt: 0)) \(String(format: "%5.1f", Double(hits) / Double(Self.words.count) * 100))%")
        }
    }

    /// Which Vision preparation reads best? (the fallback for older iOS)
    func testVisionSettingsSweep() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["BENCHMARK"] != nil, "benchmark only runs on request")
        let samples = samples()
        let configs: [(String, InkRecognizer.Settings)] = [
            ("current [1,1.6] x3 pad40", .standard),
            ("[1] only", .init(inkVariants: [1])),
            ("[1.6] only", .init(inkVariants: [1.6])),
            ("[2.2] only", .init(inkVariants: [2.2])),
            ("[1,1.6,2.4]", .init(inkVariants: [1, 1.6, 2.4])),
            ("[1.6,2.4]", .init(inkVariants: [1.6, 2.4])),
            ("scale 2", .init(renderScale: 2)),
            ("scale 1", .init(renderScale: 1)),
            ("pad 100", .init(padding: 100)),
            ("pad 15", .init(padding: 15)),
            ("no language correction", .init(usesLanguageCorrection: false)),
        ]
        var tallies: [String: Int] = [:]
        for (name, settings) in configs {
            for (word, drawing) in samples {
                let read = await InkRecognizer.recognize(drawing, settings: settings).map(\.text).joined(separator: " ")
                if read.lowercased().trimmingCharacters(in: .punctuationCharacters) == word { tallies[name, default: 0] += 1 }
            }
        }
        report("Vision + dictionary, settings sweep", tallies, total: samples.count)
    }

    /// The full pipeline as shipped, against Vision alone, on normal and messy writing.
    func testPipelineComparison() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["BENCHMARK"] != nil, "benchmark only runs on request")
        var visionOnly = InkRecognizer.Settings()
        visionOnly.usesStrokeRecognizer = false
        let strokeOnly = InkRecognizer.Settings(inkVariants: [])

        for (label, jitter, variation) in [("normal writing", 0.05, 0.08), ("messy writing", 0.16, 0.22)] as [(String, CGFloat, CGFloat)] {
            var tallies: [String: Int] = [:]
            var misses: [String: [String]] = [:]
            var total = 0
            for (w, word) in Self.words.enumerated() {
                for v in 0..<4 {
                    var rng = SeededRandom(seed: UInt64(w * 100 + v + 31))
                    let style = StrokeFont.Style(xHeight: rng.next(in: 30...50), slant: rng.next(in: 0.02...0.25),
                                                 jitter: jitter, sizeVariation: variation,
                                                 letterGap: rng.next(in: 0.2...0.4))
                    let drawing = StrokeFont.drawing(for: word, style: style, seed: UInt64(w * 100 + v + 31))
                    total += 1
                    for (name, settings) in [("vision only", visionOnly), ("stroke only (+dictionary)", strokeOnly), ("shipped pipeline", InkRecognizer.Settings())] {
                        let read = await InkRecognizer.recognize(drawing, settings: settings).map(\.text).joined(separator: " ")
                        if read.lowercased().trimmingCharacters(in: .punctuationCharacters) == word { tallies[name, default: 0] += 1 }
                        else { misses[name, default: []].append("\(word)→\(read)") }
                    }
                }
            }
            report(label, tallies, total: total)
            for name in misses.keys.sorted() { print("BENCH   misses \(name): \(misses[name]!.prefix(10).joined(separator: ", "))") }
        }
    }

    func testBenchmark() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["BENCHMARK"] != nil, "benchmark only runs on request")
        let samples = samples()
        var tallies: [String: Int] = [:]
        var misses: [String: [String]] = [:]

        func score(_ name: String, _ read: String?, _ expected: String) {
            let got = (read ?? "").lowercased().trimmingCharacters(in: .punctuationCharacters)
            if got == expected { tallies[name, default: 0] += 1 }
            else { misses[name, default: []].append("\(expected)→\(got)") }
        }

        for (word, drawing) in samples {
            // Vision as the app uses it today (two ink thicknesses, dictionary repair)
            let vision = await InkRecognizer.recognize(drawing).map(\.text).joined(separator: " ")
            score("vision+dictionary", vision, word)

            // Vision's first guess, untouched
            let raw = await InkRecognizer.candidates(for: drawing).first?.first?.first?.text
            score("vision raw", raw, word)

            for scale in [1.0, 0.6, 0.4, 0.25] as [CGFloat] {
                let pk = await StrokeTextRecognizer.recognize(drawing, scale: scale)
                score("stroke@\(scale)", pk, word)

                // stroke reading, repaired by the dictionary like the others
                if let pk {
                    let fixed = WordCorrector.best(of: [.init(text: pk, confidence: 0.9)])
                    score("stroke@\(scale)+dictionary", fixed, word)
                }
            }
        }

        let total = Double(samples.count)
        print("BENCH samples=\(samples.count)")
        for (name, hits) in tallies.sorted(by: { $0.key < $1.key }) {
            print(String(format: "BENCH %-24@ %5.1f%%", name as NSString, Double(hits) / total * 100))
        }
        for name in misses.keys.sorted() {
            print("BENCH misses \(name): \(misses[name]!.prefix(12).joined(separator: ", "))")
        }
    }
}

extension RecognitionBenchmarkTests {
    /// Is the stroke reading ever missing when it runs alongside Vision?
    func testStrokeReadingPresenceUnderLoad() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["BENCHMARK"] != nil, "benchmark only runs on request")
        var missing = 0, total = 0
        for (w, word) in Self.words.enumerated() {
            var rng = SeededRandom(seed: UInt64(w * 100 + 31))
            let style = StrokeFont.Style(xHeight: rng.next(in: 30...50), slant: rng.next(in: 0.02...0.25),
                                         jitter: 0.05, sizeVariation: 0.08, letterGap: rng.next(in: 0.2...0.4))
            let drawing = StrokeFont.drawing(for: word, style: style, seed: UInt64(w * 100 + 31))
            let results = await InkRecognizer.candidates(for: drawing)
            let alone = await StrokeTextRecognizer.recognize(drawing)
            total += 1
            let inPipeline = results.first?.first?.first?.text
            if inPipeline != alone {
                missing += 1
                print("BENCH differs for \(word): alone=\(alone ?? "nil") inPipeline=\(inPipeline ?? "nil")")
            }
        }
        print("BENCH stroke reading differs in \(missing)/\(total) samples")
    }
}
