import XCTest
@testable import Babbl

final class TextInserterTests: XCTestCase {

    // MARK: - Output Mode

    func testDefaultModeIsTyping() {
        let inserter = TextInserter()
        if case .typing = inserter.mode {
            // Pass
        } else {
            XCTFail("Default mode should be .typing")
        }
    }

    func testModeCanBeSetToClipboard() {
        let inserter = TextInserter()
        inserter.mode = .clipboard
        if case .clipboard = inserter.mode {
            // Pass
        } else {
            XCTFail("Mode should be .clipboard after setting")
        }
    }

    // MARK: - Accessibility Check

    func testRequestPermissionDoesNotPromptWhenGranted() {
        // This test verifies the logic flow -- if AXIsProcessTrusted() returns true,
        // requestAccessibilityPermission should return early without showing a prompt.
        // We can't mock AXIsProcessTrusted in a unit test, but we verify the method exists
        // and doesn't crash.
        TextInserter.requestAccessibilityPermission()
        // No assertion needed -- if it crashes, the test fails
    }

    // MARK: - Clipboard

    func testClipboardManagerCopy() {
        let testString = "Babbl test clipboard content \(UUID())"
        ClipboardManager.copy(testString)
        let result = ClipboardManager.read()
        XCTAssertEqual(result, testString)
    }

    func testClipboardManagerReadEmpty() {
        // Clear clipboard
        NSPasteboard.general.clearContents()
        let result = ClipboardManager.read()
        XCTAssertNil(result)
    }
}
