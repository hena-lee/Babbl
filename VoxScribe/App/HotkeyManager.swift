import KeyboardShortcuts

@MainActor
final class HotkeyManager {
    private let appState: AppState

    init(appState: AppState) {
        self.appState = appState
        setupHotkey()
    }

    private func setupHotkey() {
        KeyboardShortcuts.onKeyUp(for: .toggleRecording) { [weak self] in
            self?.appState.toggleRecording()
        }
    }
}
