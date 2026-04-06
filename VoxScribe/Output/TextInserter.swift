import Cocoa
import Carbon.HIToolbox

final class TextInserter {
    enum OutputMode {
        case typing      // Simulate keystrokes via CGEvent (types into active app)
        case clipboard   // Copy to clipboard only
    }

    var mode: OutputMode = .typing

    func insertText(_ text: String) {
        switch mode {
        case .typing:
            typeText(text)
        case .clipboard:
            copyToClipboard(text)
        }
    }

    // MARK: - Typing Simulation

    private func typeText(_ text: String) {
        // Check accessibility permissions
        guard AXIsProcessTrusted() else {
            // Fall back to clipboard if no accessibility permission
            copyToClipboard(text)
            showAccessibilityAlert()
            return
        }

        // Use the clipboard-paste approach for reliability and speed.
        // Directly simulating keystrokes is slow and error-prone with Unicode.
        let previousClipboard = NSPasteboard.general.string(forType: .string)

        // Set clipboard to our text
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)

        // Simulate Cmd+V to paste
        simulatePaste()

        // Restore previous clipboard content after a short delay
        if let previous = previousClipboard {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(previous, forType: .string)
            }
        }
    }

    private func simulatePaste() {
        let source = CGEventSource(stateID: .hidSystemState)

        // Key down: Cmd+V
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true)
        keyDown?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)

        // Key up: Cmd+V
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)
        keyUp?.flags = .maskCommand
        keyUp?.post(tap: .cghidEventTap)
    }

    // MARK: - Clipboard

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    // MARK: - Accessibility

    private func showAccessibilityAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Accessibility Permission Required"
            alert.informativeText = "VoxScribe needs accessibility access to type text into other apps. Text has been copied to your clipboard instead.\n\nGo to System Settings > Privacy & Security > Accessibility to grant access."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "OK")

            if alert.runModal() == .alertFirstButtonReturn {
                NSWorkspace.shared.open(
                    URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                )
            }
        }
    }

    static func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }
}
