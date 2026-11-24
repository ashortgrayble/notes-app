import SwiftUI

/// The small dropdown under an uncertain word: other readings, plus a way to
/// write the word again. The card fades in, then its rows rise in from below one
/// after another. It never slides, so moving between menus never looks like one
/// menu travelling to the next.
struct AlternativesCard: View {
    static let width: CGFloat = 210
    static let rowHeight: CGFloat = 46

    let alternatives: [String]
    var onChoose: (String) -> Void
    var onRewrite: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    /// Fades a row in (and up from 8pt below) after the card itself has appeared.
    private func reveal(_ index: Int) -> some ViewModifier {
        RowReveal(shown: shown, index: index, reduceMotion: reduceMotion)
    }

    /// Height of the card for `count` alternatives, for positioning.
    static func height(for count: Int) -> CGFloat {
        CGFloat(count) * rowHeight + rowHeight
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(alternatives.enumerated()), id: \.element) { index, alternative in
                Button { onChoose(alternative) } label: {
                    Text(alternative)
                        .font(Theme.serif(size: 22))
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, minHeight: Self.rowHeight, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .modifier(reveal(index))
            }
            Divider().overlay(Theme.faint.opacity(0.35))
            Button(action: onRewrite) {
                HStack(spacing: 8) {
                    Icon(.designPencil, size: 18)
                    Text("Write it again")
                }
                .font(.system(size: 14))
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, minHeight: Self.rowHeight, alignment: .leading)
                .contentShape(Rectangle())
            }
            .modifier(reveal(alternatives.count))
        }
        .buttonStyle(.plain)
        .onAppear { shown = true }
        .frame(width: Self.width)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.stripPaper)
                .shadow(color: .black.opacity(0.12), radius: 14, y: 4)
        )
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.faint.opacity(0.35), lineWidth: 0.5))
    }
}

private struct RowReveal: ViewModifier {
    let shown: Bool
    let index: Int
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : 8)
            .animation(.easeOut(duration: 0.22).delay(Tuning.menuRowDelay + Double(index) * Tuning.menuRowStagger),
                       value: shown)
    }
}
