import SwiftUI

/// The small dropdown under an uncertain word: other readings, plus a way to
/// write the word again. It simply fades in; no morphing or bouncing.
struct AlternativesCard: View {
    static let width: CGFloat = 210
    static let rowHeight: CGFloat = 46

    let alternatives: [String]
    var onChoose: (String) -> Void
    var onRewrite: () -> Void

    /// Height of the card for `count` alternatives, for positioning.
    static func height(for count: Int) -> CGFloat {
        CGFloat(count) * rowHeight + rowHeight
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(alternatives, id: \.self) { alternative in
                Button { onChoose(alternative) } label: {
                    Text(alternative)
                        .font(Theme.serif(size: 22))
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, minHeight: Self.rowHeight, alignment: .leading)
                        .contentShape(Rectangle())
                }
            }
            Divider().overlay(Theme.faint.opacity(0.5))
            Button(action: onRewrite) {
                Label("Write it again", systemImage: "pencil.tip")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.ink.opacity(0.7))
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, minHeight: Self.rowHeight - 1, alignment: .leading)
                    .contentShape(Rectangle())
            }
        }
        .buttonStyle(.plain)
        .frame(width: Self.width)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.stripPaper)
                .shadow(color: .black.opacity(0.12), radius: 14, y: 4)
        )
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.faint.opacity(0.35), lineWidth: 0.5))
    }
}
