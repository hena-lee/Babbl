import XCTest
@testable import Babbl

@MainActor
final class AppStateTests: XCTestCase {

    // MARK: - Recording Guard

    func testToggleRecordingFailsWhenModelNotLoaded() {
        let state = AppState()
        XCTAssertFalse(state.isModelLoaded)

        state.toggleRecording()

        // Should not start recording
        XCTAssertFalse(state.isRecording)
        // Should set an error message
        XCTAssertNotNil(state.errorMessage)
        XCTAssertTrue(state.errorMessage?.contains("Model not loaded") ?? false)
    }

    // MARK: - Stats Formatting

    func testFormattedTimeSavedZero() {
        let state = AppState()
        // Reset stats to zero (UserDefaults may have values from prior runs)
        state.totalWordsTranscribed = 0
        XCTAssertEqual(state.formattedTimeSaved, "0s")
    }

    func testFormattedTimeSavedMinutes() {
        let state = AppState()
        // 100 words: 100 * (1/40 - 1/130) = 100 * 0.01731 = 1.731 minutes = 103.8 seconds
        state.totalWordsTranscribed = 100
        let result = state.formattedTimeSaved
        // Should show minutes and seconds
        XCTAssertTrue(result.contains("m"), "Expected minutes format, got: \(result)")
    }

    func testFormattedTimeSavedHours() {
        let state = AppState()
        // 5000 words should produce hours
        state.totalWordsTranscribed = 5000
        let result = state.formattedTimeSaved
        XCTAssertTrue(result.contains("h"), "Expected hours format, got: \(result)")
    }

    // MARK: - Model Switching

    func testSwitchModelResetsState() {
        let state = AppState()
        state.isModelLoaded = true
        state.selectedModel = .small

        state.switchModel(to: .medium)

        XCTAssertEqual(state.selectedModel, .medium)
        XCTAssertFalse(state.isModelLoaded)
        XCTAssertTrue(state.isModelDownloading)
    }

    func testSwitchModelSameModelNoOp() {
        let state = AppState()
        state.isModelLoaded = true
        state.selectedModel = .small

        state.switchModel(to: .small)

        // Should not trigger a reload
        XCTAssertTrue(state.isModelLoaded)
        XCTAssertFalse(state.isModelDownloading)
    }
}
