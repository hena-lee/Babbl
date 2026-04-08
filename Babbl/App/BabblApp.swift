import os.log
import SwiftUI

@main
struct BabblApp: App {
    @StateObject private var appState = AppState()
    @State private var hasInitialized = false

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(appState)
                .onAppear {
                    guard !hasInitialized else { return }
                    hasInitialized = true

                    // Register defaults for settings
                    UserDefaults.standard.register(defaults: [
                        "pauseMediaDuringRecording": true,
                        "filterEnabled": true,
                        "filterUm": true,
                        "filterLike": true,
                        "filterYouKnow": true,
                        "filterBasically": true,
                        "filterActually": true,
                        "filterSo": true,
                        "filterIMean": true,
                        "filterLiterally": true
                    ])

                    appState.hotkeyManager = HotkeyManager(appState: appState)
                    Log.general.info("App started, hotkey manager initialized (mode: \(appState.hotkeyManager?.mode.displayName ?? "unknown"))")

                    // Auto-request permissions on launch
                    AudioCapture.requestMicrophoneAccess()
                    if !AXIsProcessTrusted() {
                        TextInserter.requestAccessibilityPermission()
                    }
                }
        } label: {
            Label {
                Text("Babbl")
            } icon: {
                Image(systemName: appState.isRecording ? "waveform.circle.fill" : "waveform.circle")
            }
        }
        .menuBarExtraStyle(.window)
    }
}
