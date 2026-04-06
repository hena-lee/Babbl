import Cocoa
import Carbon.HIToolbox

final class TextInserter {
    enum OutputMode {
        case typing      // Simulate keystrokes via CGEvent (types into active app)
        case clipboard   // Copy to clipboard only
    }

    var mode: OutputMode = .typing

    func insertText(_ text: String) {
        print("[VoxScribe:TextInserter] insertText called, mode: \(mode), text length: \(text.count)")

        switch mode {
        case .typing:
            typeText(text)
        case .clipboard:
            copyToClipboard(text)
            print("[VoxScribe:TextInserter] Text copied to clipboard (clipboard-only mode)")
        }
    }

    // MARK: - Typing Simulation

    private func typeText(_ text: String) {
        let isTrusted = AXIsProcessTrusted()
        print("[VoxScribe:TextInserter] AXIsProcessTrusted: \(isTrusted)")

        guard isTrusted else {
            print("[VoxScribe:TextInserter] No accessibility permission, falling back to clipboard")
            copyToClipboard(text)
            showAccessibilityAlert()
            return
        }

        // Save what's currently on the clipboard
        let previousClipboard = NSPasteboard.general.string(forType: .string)
        print("[VoxScribe:TextInserter] Saved previous clipboard (\(previousClipboard?.count ?? 0) chars)")

        // Set clipboard to our text
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        print("[VoxScribe:TextInserter] Set clipboard to transcribed text")

        // Small delay to ensure clipboard is set
        usleep(50_000) // 50ms

        // Check which app is frontmost right now
        let frontApp = NSWorkspace.shared.frontmostApplication
        print("[VoxScribe:TextInserter] Current frontmost app: \(frontApp?.localizedName ?? "none") (pid: \(frontApp?.processIdentifier ?? 0))")

        // Simulate Cmd+V to paste
        simulatePaste()
        print("[VoxScribe:TextInserter] Cmd+V paste simulated")

        // Restore previous clipboard content after a delay
        if let previous = previousClipboard {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(previous, forType: .string)
                print("[VoxScribe:TextInserter] Previous clipboard restored")
            }
        }
    }

    private func simulatePaste() {
        let source = CGEventSource(stateID: .hidSystemState)

        // Key down: Cmd+V
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true)
        keyDown?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)

        // Small delay between key down and up
        usleep(10_000) // 10ms

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
            alert.informativeText = "VoxScribe needs accessibility access to type text into other apps. Text has been copied to your clipboard instead.\n\nGo to System Settings > Privacy & Security > Accessibility and add VoxScribe (or Xcode during development)."
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

    static func requestAccessibilityPermission() {
        // First check if already granted -- don't prompt unnecessarily
        if AXIsProcessTrusted() {
            print("[VoxScribe:TextInserter] Accessibility already granted, no prompt needed")
            return
        }

        print("[VoxScribe:TextInserter] Accessibility not granted, showing system prompt...")
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        print("[VoxScribe:TextInserter] Permission prompt shown, current status: \(trusted)")
    }
}
