import Foundation

/// The list of saved notes, for the home screen.
@MainActor
final class NotesLibrary: ObservableObject {
    struct Summary: Identifiable {
        let id: UUID
        let preview: String
        let updatedAt: Date
    }

    @Published private(set) var notes: [Summary] = []

    init() {
        migrateSingleNote()
        reload()
    }

    /// A fresh note id. Nothing is saved until the note has words in it.
    func newNote() -> UUID { UUID() }

    func delete(_ id: UUID) {
        try? FileManager.default.removeItem(at: NoteStorage.url(for: id))
        reload()
    }

    func reload() {
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: NoteStorage.directory, includingPropertiesForKeys: nil)) ?? []
        notes = urls
            .filter { $0.pathExtension == "json" }
            .compactMap { url -> Summary? in
                guard let data = try? Data(contentsOf: url),
                      let file = try? JSONDecoder().decode(NoteFile.self, from: data),
                      !file.words.isEmpty else { return nil }
                return Summary(id: file.id,
                               preview: file.words.map(\.text).joined(separator: " "),
                               updatedAt: file.updatedAt)
            }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    /// The first prototype kept one note in `note.json`. Carry it over.
    private func migrateSingleNote() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let legacy = documents.appendingPathComponent("note.json")
        guard let data = try? Data(contentsOf: legacy),
              let words = try? JSONDecoder().decode([Word].self, from: data),
              !words.isEmpty else { return }

        let id = UUID()
        let date = (try? legacy.resourceValues(forKeys: [.contentModificationDateKey]))?
            .contentModificationDate ?? Date()
        let file = NoteFile(id: id, updatedAt: date, words: words)
        guard let encoded = try? JSONEncoder().encode(file),
              (try? encoded.write(to: NoteStorage.url(for: id), options: .atomic)) != nil else { return }
        try? FileManager.default.moveItem(at: legacy, to: documents.appendingPathComponent("note.legacy.json"))
    }
}
