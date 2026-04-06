import SwiftUI
import KeyboardShortcuts

struct SettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView {
            GeneralSettingsView()
                .environmentObject(appState)
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            ModelSettingsView()
                .environmentObject(appState)
                .tabItem {
                    Label("Model", systemImage: "cpu")
                }

            FilterSettingsView()
                .tabItem {
                    Label("Filters", systemImage: "line.3.horizontal.decrease.circle")
                }
        }
        .frame(width: 480, height: 360)
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @EnvironmentObject var appState: AppState
    @AppStorage("outputMode") private var outputMode = "typing"
    @AppStorage("launchAtLogin") private var launchAtLogin = false

    var body: some View {
        Form {
            Section("Keyboard Shortcut") {
                KeyboardShortcuts.Recorder("Toggle Recording:", name: .toggleRecording)
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

            Section("Startup") {
                Toggle("Launch at login", isOn: $launchAtLogin)
            }

            Section("Permissions") {
                HStack {
                    if AXIsProcessTrusted() {
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
    @AppStorage("filterUh") private var filterUh = true
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
