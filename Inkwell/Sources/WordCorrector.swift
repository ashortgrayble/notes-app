import UIKit

/// Turns Vision's raw guesses into real words. Handwriting often drops or
/// swaps a letter ("interesing"), so each candidate reading is checked against
/// the system English dictionary and near-misses are repaired.
enum WordCorrector {
    struct Candidate {
        let text: String
        let confidence: Float
    }

    private static let language = "en_US"

    /// Picks the most plausible reading among `candidates` (all for the same
    /// line of ink) and repairs any misspelled words in it.
    static func best(of candidates: [Candidate]) -> String? {
        let checker = UITextChecker()
        var best: (text: String, score: Double)?

        for candidate in candidates {
            let tokens = candidate.text.split(whereSeparator: \.isWhitespace).map(String.init)
            guard !tokens.isEmpty else { continue }

            var valid = 0.0
            var fixed: [String] = []
            for (i, token) in tokens.enumerated() {
                switch correct(token, isFirst: i == 0, checker: checker) {
                case .valid(let t): valid += 1; fixed.append(t)
                case .repaired(let t): valid += 0.7; fixed.append(t)
                case .unknown(let t): fixed.append(t)
                }
            }
            let score = Double(candidate.confidence) * 0.5 + (valid / Double(tokens.count)) * 0.5
            if best == nil || score > best!.score {
                best = (fixed.joined(separator: " "), score)
            }
        }
        return best?.text
    }

    private enum Outcome {
        case valid(String), repaired(String), unknown(String)
    }

    private static func correct(_ token: String, isFirst: Bool, checker: UITextChecker) -> Outcome {
        let (lead, core, trail) = split(token)
        // Numbers, lone letters and mid-sentence capitalized words (likely names) are left alone.
        if core.count <= 1 || core.contains(where: \.isNumber) { return .valid(token) }
        if !isFirst, core.first?.isUppercase == true { return .valid(token) }
        if isWord(core, checker) { return .valid(token) }

        guard let guess = bestGuess(for: core, checker) else { return .unknown(token) }
        let cased = core.first?.isUppercase == true ? guess.prefix(1).uppercased() + guess.dropFirst() : guess
        return .repaired(lead + cased + trail)
    }

    private static func isWord(_ word: String, _ checker: UITextChecker) -> Bool {
        let range = NSRange(location: 0, length: word.utf16.count)
        return checker.rangeOfMisspelledWord(in: word, range: range, startingAt: 0,
                                             wrap: false, language: language).location == NSNotFound
    }

    /// The closest dictionary word, if it's only a letter or two away.
    private static func bestGuess(for word: String, _ checker: UITextChecker) -> String? {
        let range = NSRange(location: 0, length: word.utf16.count)
        let guesses = checker.guesses(forWordRange: range, in: word, language: language) ?? []
        let lower = word.lowercased()
        let limit = word.count <= 4 ? 1 : 2

        var best: (guess: String, distance: Int, rank: Int)?
        for (rank, guess) in guesses.enumerated() where !guess.contains(" ") {
            let d = editDistance(lower, guess.lowercased())
            guard d <= limit else { continue }
            if best == nil || d < best!.distance { best = (guess, d, rank) }
        }
        return best?.guess
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
