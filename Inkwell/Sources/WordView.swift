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
struct WordView: View {
    let word: Word
    @Environment(\.launchPoint) private var launch
    @State private var progress: CGFloat
    @State private var start: CGSize = .zero

    init(word: Word) {
        self.word = word
        _progress = State(initialValue: word.isFresh ? 0 : 1)
    }

    var body: some View {
        Text(word.text)
            .font(Theme.body)
            .foregroundStyle(Theme.ink)
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
}
