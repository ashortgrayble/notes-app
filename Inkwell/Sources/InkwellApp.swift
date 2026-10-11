import SwiftUI

@main
struct InkwellApp: App {
    @StateObject private var library = NotesLibrary()

    var body: some Scene {
        WindowGroup {
            NotesListView()
                .environmentObject(library)
                .preferredColorScheme(.light)
        }
    }
}
