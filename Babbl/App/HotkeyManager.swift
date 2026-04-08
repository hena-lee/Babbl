import os.log
import Cocoa
import KeyboardShortcuts

enum HotkeyMode: String, CaseIterable, Identifiable {
    case optionDoubleTap = "optionDoubleTap"
    case optionPress = "optionPress"
    case customShortcut = "customShortcut"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .optionDoubleTap: return "Double-tap Option (recommended)"
        case .optionPress: return "Press & release Option"
        case .customShortcut: return "Custom keyboard shortcut"
        }
    }

    var description: String {
        switch self {
        case .optionDoubleTap: return "Quickly tap Option twice to toggle"
        case .optionPress: return "Tap Option once to toggle"
        case .customShortcut: return "Use a custom key combination"
        }
    }
}

@MainActor
final class HotkeyManager {
    private let appState: AppState
    private var globalMonitor: Any?
    private var localMonitor: Any?

    // State for modifier-only detection
    private var lastOptionPressTime: Date?
    private var optionWasPressed = false
    private var otherKeyPressed = false

    private let doubleTapInterval: TimeInterval = 0.4 // 400ms between taps

    var mode: HotkeyMode {
        didSet {
            UserDefaults.standard.set(mode.rawValue, forKey: "hotkeyMode")
            setupHotkey()
        }
    }

    init(appState: AppState) {
        self.appState = appState
        let savedMode = UserDefaults.standard.string(forKey: "hotkeyMode") ?? HotkeyMode.optionDoubleTap.rawValue
        self.mode = HotkeyMode(rawValue: savedMode) ?? .optionDoubleTap
        setupHotkey()
    }

    func setupHotkey() {
        removeMonitors()

        switch mode {
        case .optionDoubleTap, .optionPress:
            setupModifierMonitor()
            // Disable the KeyboardShortcuts listener when using modifier mode
            KeyboardShortcuts.onKeyUp(for: .toggleRecording) { }
            Log.hotkey.info("Set up \(self.mode.displayName) monitor")

        case .customShortcut:
            setupCustomShortcut()
            Log.hotkey.info("Set up custom shortcut monitor")
        }
    }

    // MARK: - Modifier Key Monitor (Option key)

    private func setupModifierMonitor() {
        // Global monitor: catches events when other apps are focused
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { [weak self] event in
            DispatchQueue.main.async {
                self?.handleEvent(event)
            }
        }

        // Local monitor: catches events when our app is focused
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { [weak self] event in
            DispatchQueue.main.async {
                self?.handleEvent(event)
            }
            return event
        }
    }

    private func handleEvent(_ event: NSEvent) {
        if event.type == .keyDown {
            // Any regular key press means this isn't a clean modifier-only press
            otherKeyPressed = true
            return
        }

        // flagsChanged event
        let optionPressed = event.modifierFlags.contains(.option)
        let onlyOption = event.modifierFlags.intersection([.shift, .control, .command]).isEmpty

        guard onlyOption else {
            // Other modifiers are held, reset state
            optionWasPressed = false
            otherKeyPressed = false
            return
        }

        if optionPressed {
            // Option key went DOWN
            optionWasPressed = true
            otherKeyPressed = false
        } else if optionWasPressed {
            // Option key went UP (was pressed, now released)
            optionWasPressed = false

            // Ignore if another key was pressed while Option was held (e.g., Option+A)
            guard !otherKeyPressed else {
                otherKeyPressed = false
                return
            }
            otherKeyPressed = false

            let now = Date()

            switch mode {
            case .optionPress:
                // Single press & release triggers toggle
                Log.hotkey.info("Option pressed & released, toggling recording")
                appState.toggleRecording()

            case .optionDoubleTap:
                if let lastPress = lastOptionPressTime,
                   now.timeIntervalSince(lastPress) < doubleTapInterval {
                    // Second tap within interval - trigger!
                    Log.hotkey.info("Option double-tapped, toggling recording")
                    lastOptionPressTime = nil
                    appState.toggleRecording()
                } else {
                    // First tap - record time
                    lastOptionPressTime = now
                }

            default:
                break
            }
        }
    }

    // MARK: - Custom Shortcut

    private func setupCustomShortcut() {
        KeyboardShortcuts.onKeyUp(for: .toggleRecording) { [weak self] in
            self?.appState.toggleRecording()
        }
    }

    // MARK: - Cleanup

    private func removeMonitors() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }
}
