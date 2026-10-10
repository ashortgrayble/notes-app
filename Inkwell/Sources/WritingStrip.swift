import PencilKit
import SwiftUI

/// A finger- or pencil-drawable strip. After the writer pauses, the drawing
/// is handed to `onCommit` (with the strip-sized bounds) and the canvas clears.
struct WritingStrip: UIViewRepresentable {
    var pauseBeforeCommit: TimeInterval = 0.9
    var onCommit: (PKDrawing, CGRect) -> Void

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.overrideUserInterfaceStyle = .light
        canvas.drawingPolicy = .anyInput
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.isScrollEnabled = false
        canvas.tool = PKInkingTool(.pen, color: UIColor(Theme.ink), width: 4)
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

        init(_ parent: WritingStrip) { self.parent = parent }

        func canvasViewDidBeginUsingTool(_ canvasView: PKCanvasView) {
            timer?.invalidate() // still writing
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            timer?.invalidate()
            guard !canvasView.drawing.strokes.isEmpty else { return }
            timer = Timer.scheduledTimer(withTimeInterval: parent.pauseBeforeCommit, repeats: false) {
                [weak self, weak canvasView] _ in
                guard let self, let canvasView else { return }
                let drawing = canvasView.drawing
                guard !drawing.strokes.isEmpty else { return }
                self.parent.onCommit(drawing, canvasView.bounds)
                canvasView.drawing = PKDrawing()
            }
        }
    }
}
