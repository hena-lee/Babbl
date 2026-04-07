import XCTest
@testable import Babbl

final class TranscriptionStoreTests: XCTestCase {
    private var tempURL: URL!

    override func setUp() {
        super.setUp()
        tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("BabblTest_\(UUID().uuidString).json")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempURL)
        super.tearDown()
    }

    func testSaveAndLoad() {
        let store = TranscriptionStore(fileURL: tempURL)
        let record = TranscriptionRecord(
            rawText: "Um hello world",
            cleanedText: "Hello world",
            durationSeconds: 2.5
        )
        store.save(record)

        XCTAssertEqual(store.records.count, 1)
        XCTAssertEqual(store.records[0].cleanedText, "Hello world")
        XCTAssertEqual(store.records[0].wordCount, 2)

        // Load from same file in new store instance
        let store2 = TranscriptionStore(fileURL: tempURL)
        XCTAssertEqual(store2.records.count, 1)
        XCTAssertEqual(store2.records[0].rawText, "Um hello world")
    }

    func testNewestFirst() {
        let store = TranscriptionStore(fileURL: tempURL)
        store.save(TranscriptionRecord(rawText: "first", cleanedText: "first", durationSeconds: 1))
        store.save(TranscriptionRecord(rawText: "second", cleanedText: "second", durationSeconds: 1))

        XCTAssertEqual(store.records[0].cleanedText, "second")
        XCTAssertEqual(store.records[1].cleanedText, "first")
    }

    func testEmptyStore() {
        let store = TranscriptionStore(fileURL: tempURL)
        XCTAssertTrue(store.records.isEmpty)
    }
}
