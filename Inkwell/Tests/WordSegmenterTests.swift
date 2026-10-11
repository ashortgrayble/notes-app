import XCTest
@testable import Inkwell

final class WordSegmenterTests: XCTestCase {
    private func box(_ x: CGFloat, _ y: CGFloat = 100, w: CGFloat = 20, h: CGFloat = 60) -> CGRect {
        CGRect(x: x, y: y, width: w, height: h)
    }

    func testLettersCloseTogetherAreOneWord() {
        // Four letters with ~8pt between them.
        let strokes = [box(0), box(28), box(56), box(84)]
        XCTAssertEqual(WordSegmenter.groups(of: strokes), [[0, 1, 2, 3]])
    }

    func testBigGapStartsANewWord() {
        let strokes = [box(0), box(28), box(56), box(180), box(208)]
        XCTAssertEqual(WordSegmenter.groups(of: strokes), [[0, 1, 2], [3, 4]])
    }

    func testIDotAboveItsStemStaysWithTheWord() {
        let stem = box(100, 120, w: 6, h: 40)
        let dot = CGRect(x: 101, y: 95, width: 5, height: 5)
        XCTAssertEqual(WordSegmenter.groups(of: [box(60), stem, dot]), [[0, 1, 2]])
    }

    func testStartingANewLineStartsANewWord() {
        let strokes = [box(0), box(28), box(0, 220), box(28, 220)]
        XCTAssertEqual(WordSegmenter.groups(of: strokes), [[0, 1], [2, 3]])
    }

    func testSingleStrokeIsOneWord() {
        XCTAssertEqual(WordSegmenter.groups(of: [box(10)]), [[0]])
        XCTAssertEqual(WordSegmenter.groups(of: []), [])
    }
}
