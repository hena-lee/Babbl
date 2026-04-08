import SwiftUI
import KeyboardShortcuts
import ServiceManagement

// MARK: - General Settings

struct GeneralSettingsView: View {
    @EnvironmentObject var appState: AppState
    @AppStorage("outputMode") private var outputMode = "typing"
    @AppStorage("hotkeyMode") private var hotkeyMode = HotkeyMode.optionDoubleTap.rawValue
    @AppStorage("pauseMediaDuringRecording") private var pauseMediaDuringRecording = true
    @State private var isAccessibilityGranted = AXIsProcessTrusted()
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    let accessibilityTimer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        Form {
            Section("Keyboard Shortcut") {
                Picker("Activation:", selection: $hotkeyMode) {
                    ForEach(HotkeyMode.allCases) { mode in
                        VStack(alignment: .leading) {
                            Text(mode.displayName)
                        }
                        .tag(mode.rawValue)
                    }
                }
                .onChange(of: hotkeyMode) { _, newValue in
                    if let mode = HotkeyMode(rawValue: newValue) {
                        appState.hotkeyManager?.mode = mode
                    }
                }

                if hotkeyMode == HotkeyMode.customShortcut.rawValue {
                    KeyboardShortcuts.Recorder("Custom Shortcut:", name: .toggleRecording)
                }

                // Show current mode description
                if let mode = HotkeyMode(rawValue: hotkeyMode) {
                    Text(mode.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Section("Output") {
                Picker("Output Mode:", selection: $outputMode) {
                    Text("Type into active app").tag("typing")
                    Text("Copy to clipboard").tag("clipboard")
                }
                .onChange(of: outputMode) { _, newValue in
                    appState.textInserter.mode = newValue == "typing" ? .typing : .clipboard
                }
            }

            Section("Media") {
                Toggle("Pause media during recording", isOn: $pauseMediaDuringRecording)
                Text("Pauses music or video playback while recording, then resumes when done.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Startup") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        do {
                            if newValue {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            Log.general.error("Failed to update launch at login: \(error.localizedDescription)")
                            launchAtLogin = !newValue
                        }
                    }
            }

            Section("Permissions") {
                HStack {
                    if isAccessibilityGranted {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Accessibility access granted")
                    } else {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Accessibility access required")
                        Spacer()
                        Button("Grant Access") {
                            TextInserter.requestAccessibilityPermission()
                        }
                    }
                }
                .help("Required for typing text into other apps")
                .onReceive(accessibilityTimer) { _ in
                    isAccessibilityGranted = AXIsProcessTrusted()
                }
            }

            Section {
                HStack {
                    Text("If Babbl is useful to you, consider supporting its development.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Link(destination: URL(string: "https://ko-fi.com/babbl")!) {
                        Text("Support Babbl")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Model Settings

struct ModelSettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Form {
            Section("Whisper Model") {
                Picker("Model:", selection: Binding(
                    get: { appState.selectedModel },
                    set: { appState.switchModel(to: $0) }
                )) {
                    ForEach(WhisperModel.allCases) { model in
                        Text(model.displayName).tag(model)
                    }
                }

                if appState.isModelLoaded {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Model loaded (\(appState.selectedModel.displayName))")
                            .font(.caption)
                    }
                } else if appState.isModelDownloading {
                    ProgressView(value: appState.modelDownloadProgress)
                    Text("Downloading... \(Int(appState.modelDownloadProgress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Button("Download & Load Model") {
                        appState.loadModel()
                    }
                }
            }

            Section("Info") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Models are downloaded from HuggingFace and cached locally.")
                    Text("")
                    Text("Speed guide on M4 Pro:")
                    Text("  Tiny/Base: <0.5s (fast, less accurate)")
                    Text("  Small: ~1s (good balance)")
                    Text("  Medium: ~2-3s (accurate, recommended)")
                    Text("  Large: ~4-5s (most accurate, slowest)")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Filter Settings

struct FilterSettingsView: View {
    @AppStorage("filterEnabled") private var filterEnabled = true
    @AppStorage("filterUm") private var filterUm = true
    @AppStorage("filterLike") private var filterLike = true
    @AppStorage("filterYouKnow") private var filterYouKnow = true
    @AppStorage("filterBasically") private var filterBasically = true
    @AppStorage("filterActually") private var filterActually = true
    @AppStorage("filterSo") private var filterSo = true
    @AppStorage("filterIMean") private var filterIMean = true
    @AppStorage("filterLiterally") private var filterLiterally = true

    var body: some View {
        Form {
            Section("Filler Word Removal") {
                Toggle("Enable filler word filtering", isOn: $filterEnabled)
            }

            if filterEnabled {
                Section("Always Remove") {
                    Toggle("um, uh, erm, hmm, ah", isOn: $filterUm)
                }

                Section("Context-Aware (removed only when used as filler)") {
                    Toggle("\"like\" (keeps \"I like dogs\")", isOn: $filterLike)
                    Toggle("\"you know\"", isOn: $filterYouKnow)
                    Toggle("\"basically\"", isOn: $filterBasically)
                    Toggle("\"actually\"", isOn: $filterActually)
                    Toggle("\"literally\"", isOn: $filterLiterally)
                    Toggle("\"so\" (sentence starter)", isOn: $filterSo)
                    Toggle("\"I mean\"", isOn: $filterIMean)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
