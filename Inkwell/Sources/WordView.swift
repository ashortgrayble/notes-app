import SwiftUI

private struct LaunchPointKey: EnvironmentKey {
    static let defaultValue: CGPoint = .zero
}

extension EnvironmentValues {
    /// Where new words start from, in the "root" coordinate space (the strip's center).
    var launchPoint: CGPoint {
        get { self[LaunchPointKey.self] }
        set { self[LaunchPointKey.self] = newValue }
    }
}

/// One typeset word. A fresh word starts at the writing strip, blurred and
/// small, and floats up into its place in the note.
///
/// An uncertain word carries a dotted underline; tapping it offers the other
/// readings. Tapping a certain word goes straight to rewriting it by hand.
struct WordView: View {
    let word: Word
    var isRewriting = false
    var onChoose: (String) -> Void = { _ in }
    var onRewrite: () -> Void = {}

    @Environment(\.launchPoint) private var launch
    @State private var progress: CGFloat
    @State private var start: CGSize = .zero

    init(word: Word, isRewriting: Bool = false,
         onChoose: @escaping (String) -> Void = { _ in }, onRewrite: @escaping () -> Void = {}) {
        self.word = word
        self.isRewriting = isRewriting
        self.onChoose = onChoose
        self.onRewrite = onRewrite
        _progress = State(initialValue: word.isFresh ? 0 : 1)
    }

    var body: some View {
        interactive
            .blur(radius: (1 - progress) * 5)
            .opacity(min(1, progress * 3))
            .scaleEffect(0.8 + 0.2 * progress)
            .offset(x: start.width * (1 - progress), y: start.height * (1 - progress))
            .background(
                GeometryReader { proxy in
                    Color.clear.onAppear {
                        guard word.isFresh, progress == 0 else { return }
                        let frame = proxy.frame(in: .named("root"))
                        start = CGSize(width: launch.x - frame.midX, height: launch.y - frame.midY)
                        withAnimation(.spring(response: 0.85, dampingFraction: 0.8)) {
                            progress = 1
                        }
                    }
                }
            )
    }

    @ViewBuilder private var interactive: some View {
        if word.alternatives.isEmpty {
            label.onTapGesture(perform: onRewrite)
        } else {
            Menu {
                Section("Maybe you wrote") {
                    ForEach(word.alternatives, id: \.self) { alternative in
                        Button(alternative) { onChoose(alternative) }
                    }
                }
                Button("Write it again", systemImage: "pencil.tip", action: onRewrite)
            } label: {
                label
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
        }
    }

    private var label: some View {
        Text(word.text)
            .font(Theme.body)
            .foregroundStyle(Theme.ink)
            .background {
                if isRewriting {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Theme.ink.opacity(0.09))
                        .padding(.horizontal, -4)
                }
            }
            .overlay(alignment: .bottom) {
                if !word.alternatives.isEmpty {
                    DottedLine()
                        .stroke(Theme.ink.opacity(0.5),
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
