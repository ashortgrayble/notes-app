import CoreGraphics
import Foundation

struct Word: Identifiable, Codable, Equatable {
    var id = UUID()
    var text: String
    /// Other plausible readings of the same handwriting, best first. A word
    /// with alternatives was an uncertain read and shows a dotted underline.
    var alternatives: [String] = []
    /// True only for a word that was just written, so it plays the float-up
    /// animation. Not persisted: words loaded from disk just appear.
    var isFresh = false
    /// Where the ink was written (root coordinates), so a fresh word floats up
    /// from there. Not persisted.
    var launch: CGPoint?

    enum CodingKeys: String, CodingKey { case id, text, alternatives }

    init(id: UUID = UUID(), text: String, alternatives: [String] = [],
         isFresh: Bool = false, launch: CGPoint? = nil) {
        self.id = id
        self.text = text
        self.alternatives = alternatives
        self.isFresh = isFresh
        self.launch = launch
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        text = try c.decode(String.self, forKey: .text)
        alternatives = try c.decodeIfPresent([String].self, forKey: .alternatives) ?? []
    }
}

/// One word as read from ink, with the other readings that were close.
struct RecognizedWord: Equatable {
    var text: String
    var alternatives: [String] = []
}

/// One note, as saved on disk.
struct NoteFile: Codable {
    var id: UUID
    var updatedAt: Date
    var words: [Word]
}

enum NoteStorage {
    static let directory: URL = {
        let dir = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Notes", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    static func url(for id: UUID) -> URL {
        directory.appendingPathComponent("\(id.uuidString).json")
    }
}

/// The words of a single note. An empty note isn't saved, so opening a new
/// note and leaving without writing leaves nothing behind.
@MainActor
final class NoteStore: ObservableObject {
    let id: UUID
    @Published private(set) var words: [Word] = []

    private var fileURL: URL { NoteStorage.url(for: id) }

    init(id: UUID) {
        self.id = id
        load()
    }

    /// Adds recognized words to the end of the note.
    func append(_ recognized: [RecognizedWord], launch: CGPoint? = nil) {
        Self.append(recognized, launch: launch, to: &words)
        save()
    }

    /// Replaces one word with what was just written for it (which may be more
    /// than one word).
    func replace(_ id: Word.ID, with recognized: [RecognizedWord], launch: CGPoint? = nil) {
        guard let i = words.firstIndex(where: { $0.id == id }) else { return }
        var rebuilt = Array(words[..<i])
        Self.append(recognized, launch: launch, to: &rebuilt)
        guard !recognized.isEmpty else { return }
        rebuilt.append(contentsOf: words[(i + 1)...])
        words = rebuilt
        save()
    }

    /// Swaps in one of a word's alternatives; the old reading becomes an alternative.
    func choose(_ alternative: String, for id: Word.ID) {
        guard let i = words.firstIndex(where: { $0.id == id }) else { return }
        let old = words[i].text
        words[i].alternatives = ([old] + words[i].alternatives).filter { $0 != alternative }
        words[i].text = alternative
        save()
    }

    /// Lone punctuation is attached to the previous word, and sentence starts are capitalized.
    private static func append(_ recognized: [RecognizedWord], launch: CGPoint?, to words: inout [Word]) {
        for item in recognized {
            let token = item.text
            if token.allSatisfy({ ".,;:!?".contains($0) }), !words.isEmpty {
                words[words.count - 1].text += token
                words[words.count - 1].isFresh = false
                continue
            }
            let capitalize = startsSentence(words)
            words.append(Word(text: capitalize ? capitalized(token) : token,
                              alternatives: item.alternatives.map { capitalize ? capitalized($0) : $0 },
                              isFresh: true, launch: launch))
        }
    }

    private static func capitalized(_ text: String) -> String {
        guard let first = text.first, first.isLowercase else { return text }
        return first.uppercased() + text.dropFirst()
    }

    private static func startsSentence(_ words: [Word]) -> Bool {
        guard let last = words.last?.text.last else { return true }
        return ".!?".contains(last)
    }

    func remove(_ ids: Set<Word.ID>) {
        words.removeAll { ids.contains($0.id) }
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

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let file = try? JSONDecoder().decode(NoteFile.self, from: data) else { return }
        words = file.words
    }

    private func save() {
        guard !words.isEmpty else {
            try? FileManager.default.removeItem(at: fileURL)
            return
        }
        let file = NoteFile(id: id, updatedAt: Date(), words: words)
        guard let data = try? JSONEncoder().encode(file) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
