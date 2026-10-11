import XCTest
@testable import Inkwell

final class WordCorrectorTests: XCTestCase {
    private func best(_ candidates: [(String, Float)]) -> String? {
        WordCorrector.best(of: candidates.map { .init(text: $0.0, confidence: $0.1) })
    }

    func testRepairsDroppedLetter() {
        XCTAssertEqual(best([("interesing", 0.5)]), "interesting")
    }

    func testRepairsSwappedLetter() {
        XCTAssertEqual(best([("beautifol", 0.5)]), "beautiful")
    }

    func testPrefersRealWordAmongCandidates() {
        XCTAssertEqual(best([("helio", 0.6), ("hello", 0.4)]), "hello")
    }

    func testLeavesRealWordsAlone() {
        XCTAssertEqual(best([("hello world", 0.9)]), "hello world")
    }

    func testKeepsPunctuationAndCapital() {
        XCTAssertEqual(best([("Interesing,", 0.5)]), "Interesting,")
    }

    func testLeavesMidSentenceNames() {
        XCTAssertEqual(best([("met Nils today", 0.9)]), "met Nils today")
    }

    func testLeavesGibberishWithNoCloseWord() {
        XCTAssertEqual(best([("zxqvbn", 0.5)]), "zxqvbn")
    }
}
