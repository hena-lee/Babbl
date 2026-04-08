import Cocoa
import Carbon.HIToolbox
import os.log

final class TextInserter {
    enum OutputMode {
        case typing      // Paste into active app via clipboard + Cmd+V
        case clipboard   // Copy to clipboard only
    }

    var mode: OutputMode = .typing
    private var hasShownAccessibilityAlert = false

    /// Inserts text into the active app. Returns `true` if paste was simulated, `false` if clipboard-only.
    @discardableResult
    func insertText(_ text: String) -> Bool {
        Log.textInserter.info("insertText called, mode: \(String(describing: self.mode))")

        switch mode {
        case .typing:
            return typeText(text)
        case .clipboard:
            ClipboardManager.copy(text)
            Log.textInserter.info("Text copied to clipboard (clipboard-only mode)")
            return false
        }
    }

    // MARK: - Text Insertion

    private func typeText(_ text: String) -> Bool {
        let isTrusted = AXIsProcessTrusted()

        guard isTrusted else {
            Log.textInserter.warning("No accessibility permission, falling back to clipboard")
            ClipboardManager.copy(text)
            if !hasShownAccessibilityAlert {
                hasShownAccessibilityAlert = true
                showAccessibilityAlert()
            }
            return false
        }

        // Use clipboard + Cmd+V — works reliably across all apps
        let previousClipboard = ClipboardManager.read()

        ClipboardManager.copy(text)

        // Small delay to ensure clipboard is set
        usleep(50_000) // 50ms

        simulatePaste()

        // Restore previous clipboard quickly to minimize exposure window
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if let previous = previousClipboard {
                ClipboardManager.copy(previous)
            } else {
                // Clear clipboard so transcribed text doesn't linger
                NSPasteboard.general.clearContents()
            }
        }

        return true
    }

    private func simulatePaste() {
        let source = CGEventSource(stateID: .hidSystemState)

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true)
        keyDown?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)

        usleep(10_000) // 10ms

        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)
        keyUp?.flags = .maskCommand
        keyUp?.post(tap: .cghidEventTap)
    }

    // MARK: - Accessibility

    private func showAccessibilityAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Accessibility Permission Required"
            alert.informativeText = "Babbl needs accessibility access to type text into other apps. Text has been copied to your clipboard instead.\n\nGo to System Settings > Privacy & Security > Accessibility, find Babbl in the list, and toggle it ON."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "OK")

            NSApp.activate(ignoringOtherApps: true)

            if alert.runModal() == .alertFirstButtonReturn {
                NSWorkspace.shared.open(
                    URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                )
            }
        }
    }

    /// Triggers the system accessibility prompt which auto-adds Babbl to the list.
    static func requestAccessibilityPermission() {
        if AXIsProcessTrusted() {
            Log.textInserter.info("Accessibility already granted")
            return
        }

        Log.textInserter.info("Requesting accessibility permission")
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
}
