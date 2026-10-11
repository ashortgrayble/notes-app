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
            Button { path.append(library.newNote()) } label: {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 22))
            }
            .accessibilityLabel("New note")
        }
        .padding(.horizontal, 28)
        .padding(.top, 16)
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

    private var list: some View {
        List {
            ForEach(library.notes) { note in
                NavigationLink(value: note.id) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(note.preview)
                            .font(Theme.serif(size: 21))
                            .foregroundStyle(Theme.ink)
                            .lineLimit(2)
                        Text(note.updatedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.faint)
                    }
                    .padding(.vertical, 6)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 28, bottom: 4, trailing: 20))
                .swipeActions {
                    Button(role: .destructive) { library.delete(note.id) } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}
