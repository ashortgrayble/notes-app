import UIKit

/// Turns Vision's raw guesses into real words. Handwriting often drops or
/// swaps a letter ("interesing"), so each candidate reading is checked against
/// the system English dictionary and near-misses are repaired. The readings
/// that lose out become a word's alternatives.
enum WordCorrector {
    struct Candidate {
        let text: String
        let confidence: Float
    }

    /// One complete reading of a line of ink, after repairs.
    struct Reading {
        var tokens: [String]
        /// Per token: is it (now) a real word?
        var isWord: [Bool]
        /// Per token: other dictionary words near a repaired token.
        var near: [[String]]
        var score: Double
    }

    private static let language = "en_US"

    /// Every distinct reading of the candidates, most plausible first.
    /// `context` is the sentence so far, used to break close calls.
    static func readings(from candidates: [Candidate], context: [String] = []) -> [Reading] {
        let checker = UITextChecker()
        var readings: [Reading] = []
        var indexByText: [String: Int] = [:]

        for candidate in candidates {
            let raw = candidate.text.split(whereSeparator: \.isWhitespace).map(String.init)
            guard !raw.isEmpty else { continue }

            var reading = Reading(tokens: [], isWord: [], near: [], score: 0)
            var validity = 0.0
            for (i, token) in raw.enumerated() {
                let result = correct(token, isFirst: i == 0, checker: checker)
                reading.tokens.append(result.text)
                reading.isWord.append(result.weight > 0)
                reading.near.append(result.near)
                validity += result.weight
            }
            reading.score = Double(candidate.confidence) * 0.5
                + (validity / Double(raw.count)) * 0.5
                + ContextRanker.similarityBonus(context: context, tokens: reading.tokens)

            let key = reading.tokens.joined(separator: " ").lowercased()
            if let existing = indexByText[key] {
                readings[existing].score = max(readings[existing].score, reading.score)
            } else {
                indexByText[key] = readings.count
                readings.append(reading)
            }
        }
        return readings.sorted { $0.score > $1.score }
    }

    /// The winning reading as words, each with up to three alternatives drawn
    /// from the other readings and from dictionary words near a repair.
    static func words(from readings: [Reading]) -> [RecognizedWord] {
        guard let best = readings.first else { return [] }

        return best.tokens.indices.map { i in
            let (lead, core, trail) = split(best.tokens[i])
            var alternatives: [String] = []

            func add(_ other: String) {
                let otherCore = split(other).1
                guard !otherCore.isEmpty, otherCore.lowercased() != core.lowercased(),
                      editDistance(core.lowercased(), otherCore.lowercased()) <= 3 else { return }
                let cased = core.first?.isUppercase == true ? capitalized(otherCore) : otherCore
                let alt = lead + cased + trail
                if !alternatives.contains(where: { $0.lowercased() == alt.lowercased() }) {
                    alternatives.append(alt)
                }
            }

            for other in readings.dropFirst()
            where other.tokens.count == best.tokens.count && other.isWord[i] {
                add(other.tokens[i])
            }
            best.near[i].forEach(add)
            return RecognizedWord(text: best.tokens[i], alternatives: Array(alternatives.prefix(3)))
        }
    }

    /// Convenience: the best reading as plain text.
    static func best(of candidates: [Candidate]) -> String? {
        let text = words(from: readings(from: candidates)).map(\.text).joined(separator: " ")
        return text.isEmpty ? nil : text
    }

    // MARK: - Per-token repair

    private struct Corrected {
        var text: String
        /// 1 = already a word, 0.7 = repaired into one, 0 = unknown.
        var weight: Double
        var near: [String] = []
    }

    private static func correct(_ token: String, isFirst: Bool, checker: UITextChecker) -> Corrected {
        let (lead, core, trail) = split(token)
        // Numbers, lone letters and mid-sentence capitalized words (likely names) are left alone.
        if core.count <= 1 || core.contains(where: \.isNumber) { return Corrected(text: token, weight: 1) }
        if !isFirst, core.first?.isUppercase == true { return Corrected(text: token, weight: 1) }
        if isWord(core, checker) { return Corrected(text: token, weight: 1) }

        let guesses = closeGuesses(for: core, checker)
        guard let first = guesses.first else { return Corrected(text: token, weight: 0) }
        let cased = core.first?.isUppercase == true ? capitalized(first) : first
        return Corrected(text: lead + cased + trail, weight: 0.7, near: Array(guesses.dropFirst().prefix(3)))
    }

    private static func isWord(_ word: String, _ checker: UITextChecker) -> Bool {
        let range = NSRange(location: 0, length: word.utf16.count)
        return checker.rangeOfMisspelledWord(in: word, range: range, startingAt: 0,
                                             wrap: false, language: language).location == NSNotFound
    }

    /// Dictionary words only a letter or two away, closest first.
    private static func closeGuesses(for word: String, _ checker: UITextChecker) -> [String] {
        let range = NSRange(location: 0, length: word.utf16.count)
        let guesses = checker.guesses(forWordRange: range, in: word, language: language) ?? []
        let lower = word.lowercased()
        let limit = word.count <= 4 ? 1 : 2

        return guesses.enumerated()
            .filter { !$0.element.contains(" ") }
            .map { (rank: $0.offset, guess: $0.element, distance: editDistance(lower, $0.element.lowercased())) }
            .filter { $0.distance <= limit }
            .sorted { ($0.distance, $0.rank) < ($1.distance, $1.rank) }
            .map(\.guess)
    }

    // MARK: - String helpers

    private static func capitalized(_ text: String) -> String {
        text.prefix(1).uppercased() + text.dropFirst()
    }

    /// Splits surrounding punctuation from a token: `("hi,"` -> (`"("`, `hi`, `,"`).
    private static func split(_ token: String) -> (String, String, String) {
        let edge = CharacterSet.punctuationCharacters.subtracting(CharacterSet(charactersIn: "'’"))
        let chars = Array(token)
        var start = 0, end = chars.count
        while start < end, chars[start].unicodeScalars.allSatisfy(edge.contains) { start += 1 }
        while end > start, chars[end - 1].unicodeScalars.allSatisfy(edge.contains) { end -= 1 }
        return (String(chars[..<start]), String(chars[start..<end]), String(chars[end...]))
    }

    private static func editDistance(_ a: String, _ b: String) -> Int {
        let a = Array(a), b = Array(b)
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        var prev = Array(0...b.count)
        for i in 1...a.count {
            var row = [i] + Array(repeating: 0, count: b.count)
            for j in 1...b.count {
                row[j] = min(prev[j] + 1, row[j - 1] + 1, prev[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1))
            }
            prev = row
        }
        return prev[b.count]
    }
}
