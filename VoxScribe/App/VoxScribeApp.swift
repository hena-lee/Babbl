import SwiftUI

@main
struct VoxScribeApp: App {
    @StateObject private var appState = AppState()
    @State private var hasInitialized = false

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(appState)
                .onAppear {
                    guard !hasInitialized else { return }
                    hasInitialized = true

                    appState.hotkeyManager = HotkeyManager(appState: appState)
                    print("[VoxScribe] App started, hotkey manager initialized (mode: \(appState.hotkeyManager?.mode.displayName ?? "unknown"))")

                    // Auto-request accessibility once on launch
                    if !AXIsProcessTrusted() {
                        TextInserter.requestAccessibilityPermission()
                    }
                }
        } label: {
            Label {
                Text("VoxScribe")
            } icon: {
                Image(systemName: appState.isRecording ? "waveform.circle.fill" : "waveform.circle")
            }
        }
        .menuBarExtraStyle(.window)
    }
}
