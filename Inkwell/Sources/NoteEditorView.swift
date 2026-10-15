import PencilKit
import SwiftUI

struct NoteEditorView: View {
    /// The ink of one word, shown where it was written until its typeset word lands.
    private struct Ghost: Identifiable {
        let id = UUID()
        let image: UIImage
        let center: CGPoint
        var opacity = 1.0
    }

    private struct Choosing {
        let word: Word
        let anchor: CGRect
    }

    @Environment(\.dismiss) private var dismiss
    @StateObject private var store: NoteStore

    /// Writing (big strip) vs reading (slim strip). New notes open ready to write.
    @State private var focused: Bool
    @State private var rewritingID: Word.ID?
    @State private var choosing: Choosing?
    @State private var stripFrame: CGRect = .zero
    @State private var ghosts: [Ghost] = []
    /// Words being read. They land in the note in the order they were written.
    @State private var pending = 0
    @State private var recognitionTail: Task<Void, Never>?

    init(noteID: UUID) {
        _store = StateObject(wrappedValue: NoteStore(id: noteID))
        _focused = State(initialValue: !FileManager.default.fileExists(atPath: NoteStorage.url(for: noteID).path))
    }

    var body: some View {
        GeometryReader { screen in
            content(screen: screen.size)
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: { Icon(.back, size: 24) }
                    .accessibilityLabel("Back to notes")
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .tint(Theme.ink)
    }

    private func content(screen: CGSize) -> some View {
        ZStack {
            Theme.paper.ignoresSafeArea()

            VStack(spacing: 0) {
                noteArea
                strip(focusedCanvasHeight: screen.height * Tuning.focusedCanvasFraction)
            }

            ForEach(ghosts) { ghost in
                Image(uiImage: ghost.image)
                    .position(ghost.center)
                    .opacity(ghost.opacity)
                    .allowsHitTesting(false)
            }

            if let choosing { alternativesCard(for: choosing, screenWidth: screen.width) }
        }
        .coordinateSpace(name: "root")
        .environment(\.launchPoint, CGPoint(x: stripFrame.midX, y: stripFrame.midY))
    }

    // MARK: - Note

    private var noteArea: some View {
        ScrollViewReader { reader in
            ScrollView {
                FlowLayout {
                    ForEach(store.words) { word in
                        WordView(word: word,
                                 isHighlighted: word.id == (rewritingID ?? choosing?.word.id),
                                 onTap: { wordTapped(word, frame: $0) })
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
                withAnimation(Tuning.scrollAnimation) { reader.scrollTo(id, anchor: .bottom) }
            }
            .onChange(of: rewritingID) { _, id in
                guard let id else { return }
                withAnimation(Tuning.scrollAnimation) { reader.scrollTo(id, anchor: .center) }
            }
        }
    }

    private func alternativesCard(for choosing: Choosing, screenWidth: CGFloat) -> some View {
        let width = AlternativesCard.width
        let height = AlternativesCard.height(for: choosing.word.alternatives.count)
        let x = min(max(choosing.anchor.minX, 16), screenWidth - width - 16)
        var y = choosing.anchor.maxY + 6
        if y + height > stripFrame.minY - 8 { y = choosing.anchor.minY - height - 6 }

        return ZStack {
            Color.clear
                .contentShape(Rectangle())
                .ignoresSafeArea()
                .onTapGesture { dismissCard() }

            AlternativesCard(
                alternatives: choosing.word.alternatives,
                onChoose: { alternative in
                    store.choose(alternative, for: choosing.word.id)
                    dismissCard()
                },
                onRewrite: {
                    dismissCard()
                    startRewriting(choosing.word)
                })
                .position(x: x + width / 2, y: y + height / 2)
        }
        .transition(.opacity)
    }

    private func wordTapped(_ word: Word, frame: CGRect) {
        if word.alternatives.isEmpty {
            startRewriting(word)
        } else {
            withAnimation(Tuning.cardAnimation) { choosing = Choosing(word: word, anchor: frame) }
        }
    }

    private func dismissCard() {
        withAnimation(Tuning.cardAnimation) { choosing = nil }
    }

    // MARK: - Strip

    private func strip(focusedCanvasHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            handle
            HStack {
                Button { store.removeLast() } label: { Icon(.erase) }
                    .accessibilityLabel("Delete last word")
                    .disabled(store.words.isEmpty)
                Spacer()
                if let word = store.words.first(where: { $0.id == rewritingID }) {
                    Button { rewritingID = nil } label: {
                        Text("Rewriting “\(word.text)” · Cancel")
                            .font(.system(size: 13))
                    }
                } else if pending > 0 {
                    ProgressView().controlSize(.small)
                }
                Spacer()
                Button { store.clear() } label: { Icon(.trash) }
                    .accessibilityLabel("Clear note")
                    .foregroundStyle(store.words.isEmpty ? Theme.faint : Theme.accent)
                    .disabled(store.words.isEmpty)
            }
            .font(.system(size: 15))
            .tint(Theme.ink)
            .padding(.horizontal, 22)
            .frame(height: 30)

            ZStack {
                WritingStrip(streaming: rewritingID == nil) { drawing, inkBounds in
                    commit(drawing, inkBounds: inkBounds)
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
        withAnimation(Tuning.panelAnimation) { focused = true }
    }

    private func stopWriting() {
        guard focused else { return }
        withAnimation(Tuning.panelAnimation) {
            focused = false
            rewritingID = nil
        }
    }

    /// Tapping a word asks for it to be written again; the next thing written replaces it.
    private func startRewriting(_ word: Word) {
        withAnimation(Tuning.panelAnimation) {
            focused = true
            rewritingID = word.id
        }
    }

    // MARK: - Reading ink

    /// The words before `id` (or all words), as context for reading new ink.
    private func sentenceContext(before id: Word.ID?) -> [String] {
        let preceding = id.flatMap { id in store.words.firstIndex { $0.id == id } }
            .map { store.words[..<$0] } ?? store.words[...]
        return preceding.suffix(12).map(\.text)
    }

    /// Takes one word's ink off the strip and reads it. Several words can be in
    /// flight at once: Vision runs for each straight away, but each word is
    /// ranked against the sentence only after the word before it has landed.
    private func commit(_ drawing: PKDrawing, inkBounds: CGRect) {
        let padded = inkBounds.insetBy(dx: -4, dy: -4)
        var snapshot: UIImage?
        UITraitCollection(userInterfaceStyle: .light).performAsCurrent {
            snapshot = drawing.image(from: padded, scale: UIScreen.main.scale)
        }
        let center = CGPoint(x: stripFrame.minX + padded.midX, y: stripFrame.minY + padded.midY)
        var ghostID: UUID?
        if let snapshot {
            let ghost = Ghost(image: snapshot, center: center)
            ghostID = ghost.id
            ghosts.append(ghost)
        }

        let rewriteID = rewritingID
        let previous = recognitionTail
        pending += 1
        recognitionTail = Task {
            let raw = await InkRecognizer.candidates(for: drawing)
            await previous?.value
            let words = await InkRecognizer.read(raw, context: sentenceContext(before: rewriteID))
            pending -= 1

            if !words.isEmpty {
                if let rewriteID {
                    store.replace(rewriteID, with: words, launch: center)
                    if rewritingID == rewriteID { rewritingID = nil }
                } else {
                    store.append(words, launch: center)
                }
            }
            if let ghostID { fadeGhost(ghostID) }
        }
    }

    /// The ink gives way to the typeset word floating up from it.
    private func fadeGhost(_ id: UUID) {
        withAnimation(.easeOut(duration: 0.3)) {
            if let i = ghosts.firstIndex(where: { $0.id == id }) { ghosts[i].opacity = 0 }
        }
        Task {
            try? await Task.sleep(for: .milliseconds(350))
            ghosts.removeAll { $0.id == id }
        }
    }
}
