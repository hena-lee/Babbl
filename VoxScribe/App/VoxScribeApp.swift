import SwiftUI

@main
struct VoxScribeApp: App {
    @StateObject private var appState = AppState()
    @State private var hotkeyManager: HotkeyManager?

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(appState)
                .onAppear {
                    if hotkeyManager == nil {
                        hotkeyManager = HotkeyManager(appState: appState)
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

        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}
