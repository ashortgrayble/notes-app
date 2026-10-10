import PencilKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: NoteStore

    @State private var stripFrame: CGRect = .zero
    @State private var ghost: UIImage?
    @State private var ghostOpacity = 1.0
    @State private var isReading = false
    @State private var editing: Word?
    @State private var editText = ""

    var body: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()

            VStack(spacing: 0) {
                noteArea
                strip
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
        .alert("Fix word", isPresented: Binding(get: { editing != nil }, set: { if !$0 { editing = nil } })) {
            TextField("Word", text: $editText)
                .autocorrectionDisabled()
            Button("Save") {
                if let editing { store.replace(editing.id, with: editText) }
                editing = nil
            }
            Button("Cancel", role: .cancel) { editing = nil }
        }
    }

    private var noteArea: some View {
        ScrollViewReader { reader in
            ScrollView {
                FlowLayout {
                    ForEach(store.words) { word in
                        WordView(word: word)
                            .onTapGesture {
                                editText = word.text
                                editing = word
                            }
                            .id(word.id)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, 36)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity, alignment: .leading)

                if store.words.isEmpty {
                    Text("Write below with your finger.")
                        .font(Theme.serif(size: 22, italic: true))
                        .foregroundStyle(Theme.faint)
                        .padding(.horizontal, 28)
                }
            }
            .onChange(of: store.words.last?.id) { _, id in
                guard let id else { return }
                withAnimation(.easeOut(duration: 0.4)) { reader.scrollTo(id, anchor: .bottom) }
            }
        }
    }

    private var strip: some View {
        VStack(spacing: 0) {
            HStack {
                Button { store.removeLast() } label: {
                    Image(systemName: "delete.left")
                }
                .disabled(store.words.isEmpty)
                Spacer()
                if isReading {
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
            .frame(height: 36)

            WritingStrip { drawing, bounds in
                commit(drawing, bounds: bounds)
            }
            .frame(height: 170)
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

    private func commit(_ drawing: PKDrawing, bounds: CGRect) {
        // Keep a copy of the ink on screen while the canvas clears.
        var snapshot: UIImage?
        UITraitCollection(userInterfaceStyle: .light).performAsCurrent {
            snapshot = drawing.image(from: bounds, scale: UIScreen.main.scale)
        }
        ghost = snapshot
        ghostOpacity = 1

        isReading = true
        Task {
            async let reading = InkRecognizer.recognize(drawing)
            try? await Task.sleep(for: .milliseconds(250))
            withAnimation(.easeOut(duration: 0.4)) { ghostOpacity = 0 }
            let text = await reading
            isReading = false
            if let text { store.append(recognized: text) }
            try? await Task.sleep(for: .milliseconds(450))
            ghost = nil
        }
    }
}
