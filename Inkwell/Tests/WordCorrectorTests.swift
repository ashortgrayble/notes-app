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

    // MARK: - Alternatives

    private func words(_ candidates: [(String, Float)]) -> [RecognizedWord] {
        let readings = WordCorrector.readings(from: candidates.map { .init(text: $0.0, confidence: $0.1) })
        return WordCorrector.words(from: readings)
    }

    func testOtherRealReadingsBecomeAlternatives() {
        let result = words([("hello", 0.6), ("help", 0.5), ("hells", 0.4)])
        XCTAssertEqual(result.map(\.text), ["hello"])
        XCTAssertTrue(result[0].alternatives.contains("help"))
        XCTAssertFalse(result[0].alternatives.contains("hello"))
        XCTAssertLessThanOrEqual(result[0].alternatives.count, 3)
    }

    func testRepairedWordOffersNearbyWords() {
        let result = words([("interesing", 0.5)])
        XCTAssertEqual(result.first?.text, "interesting")
    }

    func testGibberishAlternativesAreNotOffered() {
        let result = words([("hello", 0.6), ("zxqvbn", 0.5)])
        XCTAssertEqual(result[0].alternatives, [])
    }

    func testCertainWordHasNoAlternatives() {
        XCTAssertEqual(words([("hello", 0.9)])[0].alternatives, [])
    }
}
