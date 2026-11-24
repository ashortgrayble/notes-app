import SwiftUI
import XCTest
@testable import Inkwell

/// Draws the masking tape at several stages of being applied, to look at the curl.
/// Runs on request: TEST_RUNNER_BENCHMARK=1 ... -only-testing:InkwellTests/TapeRenderTests
@MainActor
final class TapeRenderTests: XCTestCase {
    func testRenderApplicationStages() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["BENCHMARK"] != nil, "render only on request")
        let stages: [CGFloat] = [0, 0.3, 0.6, 0.85, 1]
        let view = VStack(spacing: 18) {
            ForEach(stages, id: \.self) { settle in
                ZStack(alignment: .topLeading) {
                    Text("plum").font(.system(size: 26, design: .serif)).foregroundStyle(.black.opacity(0.55))
                    MaskingTape(settle: settle)
                        .fill(Color(white: 0.98).opacity(0.8))
                        .shadow(color: .black.opacity(0.07), radius: 1.2 + (1 - settle) * 2.5, y: 0.5 + (1 - settle) * 3)
                        .frame(width: 80, height: 24)
                        .rotationEffect(.degrees(-2))
                        .offset(x: -12, y: 5)
                }
                .frame(width: 140, height: 70, alignment: .center)
            }
        }
        .padding(20)
        .background(Color(white: 0.922))

        let renderer = ImageRenderer(content: view)
        renderer.scale = 3
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("tape-stages.png")
        try renderer.uiImage?.pngData()?.write(to: url)
        print("BENCH tape image: \(url.path)")
    }
}
