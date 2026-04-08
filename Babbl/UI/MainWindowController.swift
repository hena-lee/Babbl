import os.log
import SwiftUI
import AppKit

final class MainWindowController {
    static let shared = MainWindowController()

    private var window: NSWindow?

    func showWindow(appState: AppState) {
        Log.general.info("Opening main window...")

        if let existing = window, existing.isVisible {
            Log.general.info("Window already visible, bringing to front")
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let contentView = MainAppView()
            .environmentObject(appState)

        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 520),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        newWindow.title = "Babbl"
        newWindow.contentView = NSHostingView(rootView: contentView)
        newWindow.center()
        newWindow.isReleasedWhenClosed = false

        // Critical for LSUIElement apps: these ensure the window can receive
        // key events properly, which is required for KeyboardShortcuts.Recorder
        newWindow.makeKeyAndOrderFront(nil)
        newWindow.acceptsMouseMovedEvents = true
        newWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Activate the app so the window becomes key and can receive keyboard input.
        // Without this, LSUIElement (menu bar only) apps don't properly become
        // the frontmost app, so text fields and key recorders don't work.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        window = newWindow
        Log.general.info("Main window opened successfully, activation policy set to .regular")

        // When the window closes, revert to accessory (menu bar only) mode
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: newWindow,
            queue: .main
        ) { [weak self] _ in
            Log.general.info("Main window closing, reverting to accessory activation policy")
            NSApp.setActivationPolicy(.accessory)
            self?.window = nil
        }
    }
}
