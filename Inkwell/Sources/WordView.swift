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
    /// This word's menu is open: its underline goes solid. Nothing is filled or highlighted.
    var isFocused = false
    /// Another word's menu is open: step back so the focused word reads as the subject.
    var isDimmed = false
    /// Being rewritten: a strip of masking tape is stuck across the word.
    var isRewriting = false
    var isStruck = false
    var isFading = false
    var onTap: (CGRect) -> Void = { _ in }
    var onDelete: () -> Void = {}

    @Environment(\.launchPoint) private var defaultLaunch
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var progress: CGFloat
    @State private var start: CGSize = .zero

    init(word: Word, isFocused: Bool = false, isDimmed: Bool = false, isRewriting: Bool = false,
         isStruck: Bool = false, isFading: Bool = false,
         onTap: @escaping (CGRect) -> Void = { _ in }, onDelete: @escaping () -> Void = {}) {
        self.word = word
        self.isFocused = isFocused
        self.isDimmed = isDimmed
        self.isRewriting = isRewriting
        self.isStruck = isStruck
        self.isFading = isFading
        self.onTap = onTap
        self.onDelete = onDelete
        _progress = State(initialValue: word.isFresh ? 0 : 1)
    }

    var body: some View {
        label
            .blur(radius: (1 - progress) * Tuning.floatBlur)
            .opacity(isFading ? 0 : min(1, progress * 3) * (isDimmed ? Tuning.dimmedWordOpacity : 1))
            .animation(Tuning.cardAnimation, value: isDimmed)
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
            .foregroundStyle(isRewriting ? Theme.ink.opacity(0.55) : Theme.ink)
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(key: WordFramesKey.self,
                                           value: [word.id: proxy.frame(in: .named("content"))])
                }
            )
            .overlay(alignment: .bottom) {
                if !word.alternatives.isEmpty && !isRewriting {
                    DottedLine()
                        .stroke(isFocused ? Theme.ink : Color(white: 0.35),
                                style: isFocused
                                    ? StrokeStyle(lineWidth: 1.5, lineCap: .round)
                                    : StrokeStyle(lineWidth: 1.4, lineCap: .round, dash: [0.5, 4]))
                        .frame(height: 1)
                        .offset(y: 1)
                        .animation(Tuning.cardAnimation, value: isFocused)
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
            .overlay(alignment: .top) {
                if isRewriting {
                    TapeStrip()
                        .transition(.opacity)
                }
            }
            .animation(Tuning.panelAnimation, value: isRewriting)
    }
}

/// The masking tape, applied the way a person would: the left end sticks first and
/// the rest rolls down after it, the free right end curling up and settling flat.
private struct TapeStrip: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// 0 = just touched down (right end lifted and curled), 1 = pressed flat.
    @State private var settle: CGFloat = 0

    var body: some View {
        MaskingTape(settle: settle)
            .fill(Color(white: 0.98).opacity(0.8))
            // A light shadow that grows a little while the tape is still lifting.
            .shadow(color: .black.opacity(0.07), radius: 1.2 + (1 - settle) * 2.5, y: 0.5 + (1 - settle) * 3)
            .frame(height: 24)
            .padding(.horizontal, -12)
            .rotationEffect(.degrees(-2))
            .padding(.top, 5)
            .allowsHitTesting(false)
            .onAppear {
                if reduceMotion { settle = 1 }
                else { withAnimation(.spring(response: 0.42, dampingFraction: 0.68)) { settle = 1 } }
            }
    }
}

/// A strip of masking tape with torn ends. `settle` animates the free right end
/// from curled up and slightly shortened (0) down flat onto the page (1).
struct MaskingTape: Shape {
    var settle: CGFloat = 1
    var animatableData: CGFloat {
        get { settle }
        set { settle = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height, tear: CGFloat = 2.5
        let lift = 1 - settle
        let steps = 12

        // The tape curls upward and pulls in toward its free (right) end while lifted.
        func bent(_ x: CGFloat) -> CGPoint {
            let t = x / w
            return CGPoint(x: x - lift * 10 * t * t, y: -lift * 18 * pow(t, 2.2))
        }

        var path = Path()
        path.move(to: bent(0))
        for i in 1...steps { path.addLine(to: bent(w * CGFloat(i) / CGFloat(steps))) }          // top edge
        let end = bent(w)
        for (i, y) in [0.18, 0.36, 0.54, 0.72, 1.0].enumerated() {                                // right end
            path.addLine(to: CGPoint(x: end.x - (i.isMultiple(of: 2) ? tear : 0), y: end.y + h * y))
        }
        for i in stride(from: steps - 1, through: 0, by: -1) {                                    // bottom edge
            let p = bent(w * CGFloat(i) / CGFloat(steps))
            path.addLine(to: CGPoint(x: p.x, y: p.y + h))
        }
        for (i, y) in [0.82, 0.64, 0.46, 0.28, 0.12].enumerated() {                               // left end
            path.addLine(to: CGPoint(x: i.isMultiple(of: 2) ? tear : 0, y: h * y))
        }
        path.closeSubpath()
        return path
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
