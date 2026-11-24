import XCTest
@testable import Inkwell

@MainActor
final class NoteStoreTests: XCTestCase {
    private var store: NoteStore!

    override func setUp() async throws {
        store = NoteStore(id: UUID())
    }

    override func tearDown() async throws {
        store.clear() // removes the file
    }

    private func word(_ text: String, _ alternatives: [String] = []) -> RecognizedWord {
        RecognizedWord(text: text, alternatives: alternatives)
    }

    func testAppendCapitalizesSentenceStartsAndKeepsAlternatives() {
        store.append([word("hello", ["help"]), word("."), word("world")])
        XCTAssertEqual(store.words.map(\.text), ["Hello.", "World"])
        XCTAssertEqual(store.words[0].alternatives, ["Help"])
    }

    func testChoosingAnAlternativeSwapsAndKeepsTheOldReading() {
        store.append([word("hello", ["help", "hells"])])
        let id = store.words[0].id
        store.choose("Help", for: id)
        XCTAssertEqual(store.words[0].text, "Help")
        XCTAssertEqual(store.words[0].alternatives, ["Hello", "Hells"])
    }

    func testReplaceSplicesWrittenWordsIntoPlace() {
        store.append([word("one"), word("two"), word("three")])
        let middle = store.words[1].id
        store.replace(middle, with: [word("2"), word("and")])
        XCTAssertEqual(store.words.map(\.text), ["One", "2", "and", "three"])
    }

    func testReplaceWithNothingKeepsTheWord() {
        store.append([word("one")])
        store.replace(store.words[0].id, with: [])
        XCTAssertEqual(store.words.map(\.text), ["One"])
    }

    func testAlternativesSurviveSaveAndReload() {
        store.append([word("hello", ["help"])])
        let reloaded = NoteStore(id: store.id)
        XCTAssertEqual(reloaded.words.first?.alternatives, ["Help"])
    }

    func testAppendReturnsIdsAndSkipsAttachedPunctuation() {
        let ids = store.append([word("hello"), word("."), word("world")])
        XCTAssertEqual(ids.count, 3)
        XCTAssertNotNil(ids[0])
        XCTAssertNil(ids[1])
        XCTAssertEqual(ids[2], store.words[1].id)
    }

    func testSetAlternativesFillsInLateReadings() {
        let ids = store.append([word("hello")])
        store.setAlternatives([(id: ids[0]!, alternatives: ["help", "Hello", "hells", "hallo", "extra"])])
        XCTAssertEqual(store.words[0].alternatives, ["Help", "Hells", "Hallo"])
    }

    func testSetAlternativesLeavesExistingChoicesAlone() {
        let ids = store.append([word("hello", ["help"])])
        store.setAlternatives([(id: ids[0]!, alternatives: ["hells"])])
        XCTAssertEqual(store.words[0].alternatives, ["Help"])
    }
}
