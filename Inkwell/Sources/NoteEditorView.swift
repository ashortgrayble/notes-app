import PencilKit
import SwiftUI

struct NoteEditorView: View {
    @StateObject private var store: NoteStore

    /// Writing (big strip) vs reading (slim strip). New notes open ready to write.
    @State private var focused: Bool
    @State private var rewritingID: Word.ID?
    @State private var stripFrame: CGRect = .zero
    @State private var ghost: UIImage?
    @State private var ghostOpacity = 1.0
    @State private var isReading = false

    init(noteID: UUID) {
        _store = StateObject(wrappedValue: NoteStore(id: noteID))
        _focused = State(initialValue: !FileManager.default.fileExists(atPath: NoteStorage.url(for: noteID).path))
    }

    var body: some View {
        GeometryReader { screen in
            content(focusedCanvasHeight: screen.size.height * Tuning.focusedCanvasFraction)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .tint(Theme.ink)
    }

    private func content(focusedCanvasHeight: CGFloat) -> some View {
        ZStack {
            Theme.paper.ignoresSafeArea()

            VStack(spacing: 0) {
                noteArea
                strip(focusedCanvasHeight: focusedCanvasHeight)
            }

            // The drawn ink lingers briefly while the typeset word takes off.
            if let ghost {
                Image(uiImage: ghost)
                    .frame(width: stripFrame.width, height: stripFrame.height)
                    .position(x: stripFrame.midX, y: stripFrame.midY)
                    .opacity(ghostOpacity)
                    .allowsHitTesting(false)
            }
        }
        .coordinateSpace(name: "root")
        .environment(\.launchPoint, CGPoint(x: stripFrame.midX, y: stripFrame.midY))
    }

    private var noteArea: some View {
        ScrollViewReader { reader in
            ScrollView {
                FlowLayout {
                    ForEach(store.words) { word in
                        WordView(word: word,
                                 isRewriting: word.id == rewritingID,
                                 onChoose: { store.choose($0, for: word.id) },
                                 onRewrite: { startRewriting(word) })
                            .id(word.id)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, 12)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity, alignment: .leading)

                if store.words.isEmpty {
                    Text("Write below with your finger.")
                        .font(Theme.serif(size: 22, italic: true))
                        .foregroundStyle(Theme.faint)
                        .padding(.horizontal, 28)
                }
            }
            .onTapGesture(perform: stopWriting) // tap outside the strip: back to reading
            .onChange(of: store.words.last?.id) { _, id in
                guard let id else { return }
                withAnimation(.easeOut(duration: 0.4)) { reader.scrollTo(id, anchor: .bottom) }
            }
            .onChange(of: rewritingID) { _, id in
                guard let id else { return }
                withAnimation(.easeOut(duration: 0.4)) { reader.scrollTo(id, anchor: .center) }
            }
        }
    }

    private func strip(focusedCanvasHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            handle
            HStack {
                Button { store.removeLast() } label: {
                    Image(systemName: "delete.left")
                }
                .disabled(store.words.isEmpty)
                Spacer()
                if let word = store.words.first(where: { $0.id == rewritingID }) {
                    Button { rewritingID = nil } label: {
                        Text("Rewriting “\(word.text)” · Cancel")
                            .font(.system(size: 13))
                    }
                } else if isReading {
                    ProgressView().controlSize(.small)
                }
                Spacer()
                Button(role: .destructive) { store.clear() } label: {
                    Image(systemName: "trash")
                }
                .disabled(store.words.isEmpty)
            }
            .font(.system(size: 15))
            .tint(Theme.ink)
            .padding(.horizontal, 22)
            .frame(height: 30)

            ZStack {
                WritingStrip { drawing, bounds in
                    commit(drawing, bounds: bounds)
                }
                .opacity(focused ? 1 : 0)
                .allowsHitTesting(focused)

                if !focused {
                    Text("Tap to write")
                        .font(Theme.serif(size: 18, italic: true))
                        .foregroundStyle(Theme.faint)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                        .onTapGesture(perform: startWriting)
                }
            }
            .frame(height: focused ? focusedCanvasHeight : Tuning.collapsedCanvasHeight)
            .background(GeometryReader { proxy in
                Color.clear
                    .onAppear { stripFrame = proxy.frame(in: .named("root")) }
                    .onChange(of: proxy.frame(in: .named("root"))) { _, new in stripFrame = new }
            })
        }
        .background(
            Theme.stripPaper
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 26, topTrailingRadius: 26))
                .shadow(color: .black.opacity(0.08), radius: 12, y: -3)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    /// Drag up (or tap) to write, drag down (or tap) to go back to reading.
    private var handle: some View {
        Capsule()
            .fill(Theme.faint)
            .frame(width: 40, height: 5)
            .frame(maxWidth: .infinity)
            .frame(height: 24)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 8)
                    .onEnded { drag in
                        if drag.translation.height < -20 { startWriting() }
                        else if drag.translation.height > 20 { stopWriting() }
                    }
            )
            .onTapGesture { focused ? stopWriting() : startWriting() }
    }

    private func startWriting() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { focused = true }
    }

    private func stopWriting() {
        guard focused else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            focused = false
            rewritingID = nil
        }
    }

    /// Tapping a word asks for it to be written again; the next thing written replaces it.
    private func startRewriting(_ word: Word) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            focused = true
            rewritingID = word.id
        }
    }

    /// The words before `id` (or all words), as context for reading new ink.
    private func sentenceContext(before id: Word.ID?) -> [String] {
        let preceding = id.flatMap { id in store.words.firstIndex { $0.id == id } }
            .map { store.words[..<$0] } ?? store.words[...]
        return preceding.suffix(12).map(\.text)
    }

    private func commit(_ drawing: PKDrawing, bounds: CGRect) {
        // Keep a copy of the ink on screen while the canvas clears.
        var snapshot: UIImage?
        UITraitCollection(userInterfaceStyle: .light).performAsCurrent {
            snapshot = drawing.image(from: bounds, scale: UIScreen.main.scale)
        }
        ghost = snapshot
        ghostOpacity = 1

        let rewriteID = rewritingID
        let context = sentenceContext(before: rewriteID)

        isReading = true
        Task {
            async let reading = InkRecognizer.recognize(drawing, context: context)
            try? await Task.sleep(for: .milliseconds(250))
            withAnimation(.easeOut(duration: 0.4)) { ghostOpacity = 0 }
            let words = await reading
            isReading = false
            if !words.isEmpty {
                if let rewriteID {
                    store.replace(rewriteID, with: words)
                    if rewritingID == rewriteID { rewritingID = nil }
                } else {
                    store.append(words)
                }
            }
            try? await Task.sleep(for: .milliseconds(450))
            ghost = nil
        }
    }
}
