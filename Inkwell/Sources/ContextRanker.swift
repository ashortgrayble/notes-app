import Foundation
import NaturalLanguage
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Uses the sentence written so far to decide between readings of a word.
///
/// Two signals, cheapest first:
/// 1. `similarityBonus`: a tiny nudge for words that are semantically close to
///    the recent words (on-device word embeddings). Always available.
/// 2. `rerank`: when the top readings are nearly tied, ask the on-device
///    language model (Apple Intelligence, iOS 26+) which one fits the sentence.
///    Skipped silently where the model isn't available, and never allowed to
///    delay the word by more than `Tuning.contextModelTimeout`.
enum ContextRanker {
    private static let embedding = NLEmbedding.wordEmbedding(for: .english)

    static func similarityBonus(context: [String], tokens: [String]) -> Double {
        guard let embedding, !context.isEmpty else { return 0 }
        let contextWords = context.suffix(8).map(normalized).filter { $0.count >= 4 && embedding.contains($0) }
        guard !contextWords.isEmpty else { return 0 }

        var total = 0.0, counted = 0.0
        for token in tokens.map(normalized) where token.count >= 3 && embedding.contains(token) {
            let distances = contextWords.map { embedding.distance(between: token, and: $0) }
            total += distances.reduce(0, +) / Double(distances.count)
            counted += 1
        }
        guard counted > 0 else { return 0 }
        // Cosine distance: related words sit well under 1, unrelated ones around or above it.
        return max(-0.04, min(0.04, (1.0 - total / counted) * 0.1))
    }

    /// Moves the language model's pick to the front when the top readings are close.
    static func rerank(_ readings: [WordCorrector.Reading], context: [String]) async -> [WordCorrector.Reading] {
        guard readings.count >= 2, !context.isEmpty,
              readings[0].score - readings[1].score < Tuning.contextTieMargin else { return readings }

        let options = readings.prefix(3).map { $0.tokens.joined(separator: " ") }
        guard let pick = await modelPick(context: context, options: options),
              pick > 0, pick < readings.count else { return readings }

        var reordered = readings
        reordered.insert(reordered.remove(at: pick), at: 0)
        return reordered
    }

    private static func normalized(_ word: String) -> String {
        word.lowercased().trimmingCharacters(in: .punctuationCharacters)
    }

    /// Index of the option the model thinks fits best, or nil if it can't or won't say in time.
    private static func modelPick(context: [String], options: [String]) async -> Int? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return await withTaskGroup(of: Int?.self) { group in
                group.addTask { await askModel(context: context, options: options) }
                group.addTask {
                    try? await Task.sleep(for: .seconds(Tuning.contextModelTimeout))
                    return nil
                }
                let first = await group.next() ?? nil
                group.cancelAll()
                return first
            }
        }
        #endif
        return nil
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private static func askModel(context: [String], options: [String]) async -> Int? {
        guard case .available = SystemLanguageModel.default.availability else { return nil }

        let session = LanguageModelSession(instructions: """
            You help read messy handwriting. You are given the start of a sentence and \
            a few candidate readings of the next handwritten word. Pick the candidate \
            that best fits the sentence in grammar and meaning. Reply with only its number.
            """)
        let list = options.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
        let prompt = "Sentence so far: \"\(context.suffix(12).joined(separator: " "))\"\nCandidates for the next word:\n\(list)"

        guard let reply = try? await session.respond(to: prompt),
              let digit = reply.content.first(where: \.isNumber).flatMap({ Int(String($0)) }),
              (1...options.count).contains(digit) else { return nil }
        return digit - 1
    }
    #endif
}
