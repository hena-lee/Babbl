import XCTest
@testable import VoxScribe

final class FillerFilterTests: XCTestCase {
    let filter = FillerFilter()

    // MARK: - Unconditional Fillers

    func testRemovesUm() {
        XCTAssertEqual(filter.filter("Um I went to the store"), "I went to the store")
    }

    func testRemovesUh() {
        XCTAssertEqual(filter.filter("I uh went to the store"), "I went to the store")
    }

    func testRemovesMultipleFillers() {
        XCTAssertEqual(
            filter.filter("Um I like went to the uh store"),
            "I went to the store"
        )
    }

    func testRemovesHmm() {
        XCTAssertEqual(filter.filter("Hmm let me think"), "Let me think")
    }

    // MARK: - Conditional: "like"

    func testKeepsLikeAsVerb() {
        XCTAssertEqual(filter.filter("I like dogs"), "I like dogs")
    }

    func testRemovesLikeAsFiller() {
        let result = filter.filter("it was like really big")
        XCTAssertFalse(result.lowercased().contains("like"))
    }

    func testKeepsLooksLike() {
        XCTAssertEqual(filter.filter("it looks like rain"), "It looks like rain")
    }

    // MARK: - Conditional: "you know"

    func testRemovesYouKnowAsFiller() {
        let result = filter.filter("it was, you know, fine")
        XCTAssertFalse(result.contains("you know"))
    }

    func testKeepsDoYouKnow() {
        let result = filter.filter("do you know where it is")
        XCTAssertTrue(result.contains("you know"))
    }

    // MARK: - Conditional: "basically"

    func testRemovesBasicallyAtStart() {
        let result = filter.filter("Basically I think we should go")
        XCTAssertFalse(result.lowercased().contains("basically"))
    }

    // MARK: - Conditional: "so"

    func testRemovesSoAtSentenceStart() {
        let result = filter.filter("So I went to the store")
        XCTAssertFalse(result.lowercased().hasPrefix("so"))
    }

    func testKeepsSoThat() {
        let result = filter.filter("I did it so that it would work")
        XCTAssertTrue(result.contains("so that"))
    }

    // MARK: - Complex Cases

    func testComplexFillerRemoval() {
        let result = filter.filter("So basically I was like you know thinking")
        XCTAssertFalse(result.lowercased().contains("basically"))
        XCTAssertTrue(result.lowercased().contains("thinking"))
    }

    // MARK: - Cleanup

    func testNoDoubleSpaces() {
        let result = filter.filter("Um I uh went uh there")
        XCTAssertFalse(result.contains("  "))
    }

    func testCapitalizesAfterFillerRemoval() {
        let result = filter.filter("um hello there")
        XCTAssertTrue(result.first?.isUppercase ?? false)
    }

    // MARK: - Edge Cases

    func testEmptyString() {
        XCTAssertEqual(filter.filter(""), "")
    }

    func testNoFillers() {
        XCTAssertEqual(
            filter.filter("The quick brown fox jumps over the lazy dog"),
            "The quick brown fox jumps over the lazy dog"
        )
    }

    func testAllFillers() {
        let result = filter.filter("um uh erm hmm ah")
        XCTAssertTrue(result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
}
