import os.log
import SwiftUI
import KeyboardShortcuts

struct MainAppView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardTab(selectedTab: $selectedTab)
                .environmentObject(appState)
                .tabItem {
                    Label("Dashboard", systemImage: "house")
                }
                .tag(0)

            GeneralSettingsView()
                .environmentObject(appState)
                .tabItem {
                    Label("General", systemImage: "gear")
                }
                .tag(1)

            ModelSettingsView()
                .environmentObject(appState)
                .tabItem {
                    Label("Model", systemImage: "cpu")
                }
                .tag(2)

            FilterSettingsView()
                .tabItem {
                    Label("Filters", systemImage: "line.3.horizontal.decrease.circle")
                }
                .tag(3)
        }
        .frame(minWidth: 520, minHeight: 420)
        .padding()
    }
}

// MARK: - Dashboard

struct DashboardTab: View {
    @EnvironmentObject var appState: AppState
    @Binding var selectedTab: Int
    @State private var accessibilityGranted = AXIsProcessTrusted()
    @AppStorage("hotkeyMode") private var hotkeyMode = HotkeyMode.optionDoubleTap.rawValue
    let accessibilityTimer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 20) {
            // App header
            HStack(spacing: 12) {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading) {
                    Text("Babbl")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("Intelligent Voice-to-Text")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                // Status badge
                StatusBadge(appState: appState)
            }

            Divider()

            // Stats cards
            HStack(spacing: 16) {
                StatCard(
                    icon: "clock",
                    title: "Time Saved",
                    value: appState.formattedTimeSaved,
                    subtitle: "vs manual typing"
                )
                StatCard(
                    icon: "text.word.spacing",
                    title: "Words Transcribed",
                    value: "\(appState.totalWordsTranscribed)",
                    subtitle: "total"
                )
                StatCard(
                    icon: "minus.circle",
                    title: "Fillers Removed",
                    value: "\(appState.totalFillersRemoved)",
                    subtitle: "cleaned up"
                )
            }

            Divider()

            // Quick actions
            VStack(alignment: .leading, spacing: 8) {
                Text("Quick Start")
                    .font(.headline)

                HStack(spacing: 12) {
                    // Record: show state-aware description, handle model not loaded
                    ActionCard(
                        icon: appState.isRecording ? "stop.circle.fill" : "mic.circle.fill",
                        title: appState.isRecording ? "Stop" : "Record",
                        description: recordDescription,
                        color: appState.isRecording ? .red : .blue
                    ) {
                        if !appState.isModelLoaded {
                            Log.general.info("Record pressed but model not loaded, switching to Model tab")
                            appState.errorMessage = "Please download a model first"
                            selectedTab = 2 // Switch to Model tab
                        } else {
                            appState.toggleRecording()
                        }
                    }

                    // Hotkey: click navigates to General tab to change it
                    ActionCard(
                        icon: "keyboard",
                        title: "Hotkey",
                        description: hotkeyDescription,
                        color: .orange
                    ) {
                        Log.general.info("Hotkey card pressed, switching to General tab")
                        selectedTab = 1 // Switch to General tab
                    }

                    // Accessibility: only prompt if not already granted
                    ActionCard(
                        icon: accessibilityGranted ? "checkmark.shield.fill" : "shield.checkered",
                        title: "Accessibility",
                        description: accessibilityGranted ? "Granted" : "Click to grant",
                        color: accessibilityGranted ? .green : .red
                    ) {
                        if accessibilityGranted {
                            Log.general.info("Accessibility already granted, no action needed")
                        } else {
                            Log.general.info("Requesting accessibility permission...")
                            TextInserter.requestAccessibilityPermission()
                            // Re-check after a delay (user may grant in System Settings)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                accessibilityGranted = AXIsProcessTrusted()
                            }
                        }
                    }
                }
            }

            // Error message
            if let error = appState.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.orange)
                    Spacer()
                    Button("Dismiss") {
                        appState.errorMessage = nil
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                }
                .padding(8)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(6)
            }

            // Last transcription
            if !appState.lastCleanedText.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Last Transcription")
                            .font(.headline)
                        Spacer()
                        Button("Copy") {
                            ClipboardManager.copy(appState.lastCleanedText)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    Text(appState.lastCleanedText)
                        .font(.body)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.secondary.opacity(0.08))
                        .cornerRadius(8)

                    if appState.lastTranscription != appState.lastCleanedText {
                        DisclosureGroup("Original (before filtering)") {
                            Text(appState.lastTranscription)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()
        }
        .padding()
        .onAppear {
            accessibilityGranted = AXIsProcessTrusted()
            Log.general.info("Dashboard appeared. Accessibility: \(accessibilityGranted), Model loaded: \(appState.isModelLoaded)")
        }
        .onReceive(accessibilityTimer) { _ in
            accessibilityGranted = AXIsProcessTrusted()
        }
    }

    private var hotkeyDescription: String {
        guard let mode = HotkeyMode(rawValue: hotkeyMode) else { return "Not set" }
        switch mode {
        case .optionDoubleTap: return "Double-tap Option"
        case .optionPress: return "Tap Option"
        case .customShortcut:
            return KeyboardShortcuts.getShortcut(for: .toggleRecording)?.description ?? "Not set"
        }
    }

    private var recordDescription: String {
        if appState.isRecording { return "Click to stop" }
        if appState.isTranscribing { return "Transcribing..." }
        if !appState.isModelLoaded { return "Model needed" }
        return "Press hotkey to start"
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    @ObservedObject var appState: AppState

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(statusText)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }

    private var statusColor: Color {
        if appState.isRecording { return .red }
        if appState.isTranscribing { return .orange }
        if appState.isModelLoaded { return .green }
        if appState.isModelDownloading { return .blue }
        return .gray
    }

    private var statusText: String {
        if appState.isRecording { return "Recording" }
        if appState.isTranscribing { return "Transcribing" }
        if appState.isModelLoaded { return "Ready" }
        if appState.isModelDownloading { return "Downloading" }
        return "Not Ready"
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let icon: String
    let title: String
    let value: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.secondary.opacity(0.06))
        .cornerRadius(10)
    }
}

// MARK: - Action Card

struct ActionCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color.secondary.opacity(0.06))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}
