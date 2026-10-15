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

/// One typeset word. A fresh word starts where it was written, slightly
/// blurred and small, and floats up into its place in the note.
///
/// An uncertain word carries a dotted underline. Tapping any word reports its
/// frame (root coordinates) so the editor can offer alternatives or a rewrite.
struct WordView: View {
    let word: Word
    var isHighlighted = false
    var onTap: (CGRect) -> Void = { _ in }

    @Environment(\.launchPoint) private var defaultLaunch
    @State private var progress: CGFloat
    @State private var start: CGSize = .zero

    init(word: Word, isHighlighted: Bool = false, onTap: @escaping (CGRect) -> Void = { _ in }) {
        self.word = word
        self.isHighlighted = isHighlighted
        self.onTap = onTap
        _progress = State(initialValue: word.isFresh ? 0 : 1)
    }

    var body: some View {
        label
            .blur(radius: (1 - progress) * Tuning.floatBlur)
            .opacity(min(1, progress * 3))
            .scaleEffect(Tuning.floatStartScale + (1 - Tuning.floatStartScale) * progress)
            .offset(x: start.width * (1 - progress), y: start.height * (1 - progress))
            .background(
                GeometryReader { proxy in
                    Color.clear.onAppear {
                        guard word.isFresh, progress == 0 else { return }
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
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { onTap(proxy.frame(in: .named("root"))) }
                }
            )
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
            .overlay(alignment: .bottom) {
                if !word.alternatives.isEmpty {
                    DottedLine()
                        .stroke(Theme.accent.opacity(0.85),
                                style: StrokeStyle(lineWidth: 1.4, lineCap: .round, dash: [0.5, 4]))
                        .frame(height: 1)
                        .offset(y: 1)
                }
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
