import PencilKit
import SwiftUI

/// A finger- or pencil-drawable strip. Words are handed to `onCommit` (with
/// the ink's bounds in the strip) and removed from the canvas as they finish:
/// either when the next word begins (`streaming`) or after a pause.
struct WritingStrip: UIViewRepresentable {
    var pauseBeforeCommit: TimeInterval = Tuning.pauseBeforeCommit
    /// Read each word as soon as the next one starts, instead of waiting for a pause.
    var streaming = true
    var onCommit: (PKDrawing, CGRect) -> Void

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.overrideUserInterfaceStyle = .light
        canvas.drawingPolicy = .anyInput
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.isScrollEnabled = false
        canvas.tool = PKInkingTool(.pen, color: UIColor(Theme.ink), width: Tuning.inkWidth)
        canvas.delegate = context.coordinator
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        context.coordinator.parent = self
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: WritingStrip
        private var timer: Timer?
        private var isReplacingDrawing = false

        init(_ parent: WritingStrip) { self.parent = parent }

        func canvasViewDidBeginUsingTool(_ canvasView: PKCanvasView) {
            timer?.invalidate() // still writing
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            guard !isReplacingDrawing else { return }
            timer?.invalidate()
            let strokes = canvasView.drawing.strokes
            guard !strokes.isEmpty else { return }

            // A stroke that starts a new word means the earlier words are done.
            if parent.streaming {
                let words = WordSegmenter.groups(of: strokes.map(\.renderBounds))
                if words.count > 1 {
                    for word in words.dropLast() {
                        emit(PKDrawing(strokes: word.map { strokes[$0] }))
                    }
                    replaceDrawing(of: canvasView, with: PKDrawing(strokes: words[words.count - 1].map { strokes[$0] }))
                }
            }

            timer = Timer.scheduledTimer(withTimeInterval: parent.pauseBeforeCommit, repeats: false) {
                [weak self, weak canvasView] _ in
                guard let self, let canvasView else { return }
                let drawing = canvasView.drawing
                guard !drawing.strokes.isEmpty else { return }
                self.emit(drawing)
                self.replaceDrawing(of: canvasView, with: PKDrawing())
            }
        }

        private func emit(_ drawing: PKDrawing) {
            parent.onCommit(drawing, drawing.bounds)
        }

        private func replaceDrawing(of canvasView: PKCanvasView, with drawing: PKDrawing) {
            isReplacingDrawing = true
            canvasView.drawing = drawing
            isReplacingDrawing = false
        }
    }
}
