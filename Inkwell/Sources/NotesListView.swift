import SwiftUI

/// Home screen: every saved note, newest first, plus a button to start a new one.
struct NotesListView: View {
    @EnvironmentObject private var library: NotesLibrary
    @State private var path: [UUID] = []

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                Theme.paper.ignoresSafeArea()
                VStack(spacing: 0) {
                    header
                    if library.notes.isEmpty { empty } else { list }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: UUID.self) { NoteEditorView(noteID: $0) }
            .onAppear { library.reload() }
        }
        .tint(Theme.ink)
    }

    private var header: some View {
        HStack {
            Text("Notes")
                .font(Theme.serif(size: 38, weight: 500))
                .foregroundStyle(Theme.ink)
            Spacer()
            Button { path.append(library.newNote()) } label: { CardIconLabel(.editPencil) }
                .accessibilityLabel("New note")
        }
        .padding(.leading, 28)
        .padding(.trailing, 20)
        .padding(.top, 12)
        .padding(.bottom, 12)
    }

    private var empty: some View {
        VStack {
            Spacer()
            Text("No notes yet.\nTap the pencil to write one.")
                .multilineTextAlignment(.center)
                .font(Theme.serif(size: 22, italic: true))
                .foregroundStyle(Theme.faint)
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    /// Each note is a soft white card.
    private var list: some View {
        List {
            ForEach(library.notes) { note in
                Button { path.append(note.id) } label: {
                    HStack(alignment: .center, spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(note.preview)
                                .font(Theme.serif(size: 21))
                                .foregroundStyle(Theme.ink)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                            Text(note.updatedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.faint)
                        }
                        Spacer(minLength: 0)
                        Icon(.forward, size: 18)
                            .foregroundStyle(Theme.faint)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous).fill(Theme.card))
                    .contentShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 5, leading: 20, bottom: 5, trailing: 20))
                .swipeActions {
                    Button { library.delete(note.id) } label: { Icon(.trash) }
                        .tint(Theme.accent)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}
