import XCTest
@testable import Inkwell

final class ScratchOutTests: XCTestCase {
    private let word = UUID()
    private let other = UUID()
    private var frames: [UUID: CGRect] { [
        word: CGRect(x: 40, y: 100, width: 80, height: 34),
        other: CGRect(x: 130, y: 100, width: 60, height: 34),
    ] }

    private func sweep(from x0: CGFloat, to x1: CGFloat, y: CGFloat) -> [CGPoint] {
        stride(from: x0, through: x1, by: 8).map { CGPoint(x: $0, y: y) }
    }

    func testSidewaysSweepAcrossAWordStrikesIt() {
        XCTAssertEqual(ScratchOut.words(struckBy: sweep(from: 30, to: 130, y: 118), frames: frames), [word])
    }

    func testZigzagScribbleStrikesIt() {
        let zigzag = [CGPoint(x: 40, y: 108), CGPoint(x: 120, y: 128), CGPoint(x: 40, y: 118),
                      CGPoint(x: 120, y: 112), CGPoint(x: 60, y: 124)]
        XCTAssertEqual(ScratchOut.words(struckBy: zigzag, frames: frames), [word])
    }

    func testSweepAcrossTwoWordsStrikesBoth() {
        XCTAssertEqual(ScratchOut.words(struckBy: sweep(from: 30, to: 200, y: 118), frames: frames), [word, other])
    }

    func testBrushingPastAWordDoesNotStrikeIt() {
        // covers well under half of the word
        XCTAssertEqual(ScratchOut.words(struckBy: sweep(from: 100, to: 135, y: 118), frames: frames), [])
    }

    func testVerticalDragIsAScrollNotAStrike() {
        let drag = stride(from: 60, through: 260, by: 10).map { CGPoint(x: 80, y: CGFloat($0)) }
        XCTAssertEqual(ScratchOut.words(struckBy: drag, frames: frames), [])
    }

    func testStrikeOnADifferentLineMissesTheWord() {
        XCTAssertEqual(ScratchOut.words(struckBy: sweep(from: 30, to: 130, y: 220), frames: frames), [])
    }

    func testTapIsNotAStrike() {
        XCTAssertFalse(ScratchOut.isStrike([CGPoint(x: 50, y: 50)]))
    }
}
