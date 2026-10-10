import Foundation

struct Word: Identifiable, Codable, Equatable {
    var id = UUID()
    var text: String
    /// True only for a word that was just written, so it plays the float-up
    /// animation. Not persisted: words loaded from disk just appear.
    var isFresh = false

    enum CodingKeys: String, CodingKey { case id, text }
}

@MainActor
final class NoteStore: ObservableObject {
    @Published private(set) var words: [Word] = []

    private let fileURL: URL = FileManager.default
        .urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("note.json")

    init() { load() }

    /// Adds recognized text, which may be several words. Lone punctuation is
    /// attached to the previous word, and sentence starts are capitalized.
    func append(recognized text: String) {
        let tokens = text.split(whereSeparator: \.isWhitespace).map(String.init)
        for token in tokens {
            if token.allSatisfy({ ".,;:!?".contains($0) }), !words.isEmpty {
                words[words.count - 1].text += token
                words[words.count - 1].isFresh = false
                continue
            }
            var t = token
            if startsSentence, let first = t.first, first.isLowercase {
                t = first.uppercased() + t.dropFirst()
            }
            words.append(Word(text: t, isFresh: true))
        }
        save()
    }

    func replace(_ id: Word.ID, with text: String) {
        guard let i = words.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { words.remove(at: i) } else { words[i].text = trimmed }
        save()
    }

    func removeLast() {
        guard !words.isEmpty else { return }
        words.removeLast()
        save()
    }

    func clear() {
        words = []
        save()
    }

    private var startsSentence: Bool {
        guard let last = words.last?.text.last else { return true }
        return ".!?".contains(last)
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([Word].self, from: data) else { return }
        words = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(words) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
