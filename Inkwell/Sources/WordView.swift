import SwiftUI

private struct LaunchPointKey: EnvironmentKey {
    static let defaultValue: CGPoint = .zero
}

extension EnvironmentValues {
    /// Fallback start for a new word, in the "root" coordinate space, when it
    /// doesn't know where its ink was written (the strip's center).
    var launchPoint: CGPoint {
        get { self[LaunchPointKey.self] }
        set { self[LaunchPointKey.self] = newValue }
    }
}

/// Every word's frame in the note's scrolling content, so a scribble can find
/// the words it crosses.
struct WordFramesKey: PreferenceKey {
    static let defaultValue: [UUID: CGRect] = [:]
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

/// One typeset word. A fresh word starts where it was written, slightly
/// blurred and small, and floats up into its place in the note.
///
/// An uncertain word carries a dotted underline. Tapping any word reports its
/// frame (root coordinates) so the editor can offer alternatives or a rewrite.
/// A scribbled-over word is struck through, then fades away.
struct WordView: View {
    let word: Word
    var isHighlighted = false
    var isStruck = false
    var isFading = false
    var onTap: (CGRect) -> Void = { _ in }
    var onDelete: () -> Void = {}

    @Environment(\.launchPoint) private var defaultLaunch
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var progress: CGFloat
    @State private var start: CGSize = .zero

    init(word: Word, isHighlighted: Bool = false, isStruck: Bool = false, isFading: Bool = false,
         onTap: @escaping (CGRect) -> Void = { _ in }, onDelete: @escaping () -> Void = {}) {
        self.word = word
        self.isHighlighted = isHighlighted
        self.isStruck = isStruck
        self.isFading = isFading
        self.onTap = onTap
        self.onDelete = onDelete
        _progress = State(initialValue: word.isFresh ? 0 : 1)
    }

    var body: some View {
        label
            .blur(radius: (1 - progress) * Tuning.floatBlur)
            .opacity(isFading ? 0 : min(1, progress * 3))
            .scaleEffect(Tuning.floatStartScale + (1 - Tuning.floatStartScale) * progress)
            .offset(x: start.width * (1 - progress), y: start.height * (1 - progress))
            .background(
                GeometryReader { proxy in
                    Color.clear.onAppear {
                        guard word.isFresh, progress == 0 else { return }
                        if reduceMotion {
                            withAnimation(.easeOut(duration: 0.15)) { progress = 1 }
                            return
                        }
                        let frame = proxy.frame(in: .named("root"))
                        let from = word.launch ?? defaultLaunch
                        start = CGSize(width: from.x - frame.midX, height: from.y - frame.midY)
                        withAnimation(.spring(response: Tuning.floatResponse, dampingFraction: Tuning.floatDamping)) {
                            progress = 1
                        }
                    }
                }
            )
            .overlay(
                GeometryReader { proxy in
                    // The hit area reaches past the text so a word is easier to tap.
                    Color.clear
                        .contentShape(Rectangle().inset(by: -6))
                        .onTapGesture { onTap(proxy.frame(in: .named("root"))) }
                }
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(word.text)
            .accessibilityHint(word.alternatives.isEmpty ? "Double tap to write it again"
                                                          : "Double tap to choose another reading")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(named: "Delete word", onDelete)
    }

    private var label: some View {
        Text(word.text)
            .font(Theme.body)
            .foregroundStyle(Theme.ink)
            .background {
                if isHighlighted {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Theme.accent.opacity(0.16))
                        .padding(.horizontal, -4)
                }
            }
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(key: WordFramesKey.self,
                                           value: [word.id: proxy.frame(in: .named("content"))])
                }
            )
            .overlay(alignment: .bottom) {
                if !word.alternatives.isEmpty {
                    DottedLine()
                        .stroke(Color(white: 0.35),
                                style: StrokeStyle(lineWidth: 1.4, lineCap: .round, dash: [0.5, 4]))
                        .frame(height: 1)
                        .offset(y: 1)
                }
            }
            .overlay(alignment: .leading) {
                // The strike-through draws itself from left to right.
                Capsule()
                    .fill(Theme.accent)
                    .frame(height: 2.5)
                    .padding(.horizontal, -3)
                    .scaleEffect(x: isStruck ? 1 : 0.001, anchor: .leading)
                    .opacity(isStruck ? 1 : 0)
            }
    }
}

private struct DottedLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}
