import SwiftUI
import KeyboardShortcuts

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 12) {
            // Status header
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(statusText)
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal)

            Divider()

            // Record button
            Button(action: { appState.toggleRecording() }) {
                HStack {
                    Image(systemName: appState.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.title2)
                        .foregroundColor(appState.isRecording ? .red : .accentColor)
                    Text(appState.isRecording ? "Stop Recording" : "Start Recording")
                    Spacer()
                    KeyboardShortcuts.Recorder(for: .toggleRecording)
                        .fixedSize()
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
            .disabled(appState.isTranscribing || !appState.isModelLoaded)

            // Model status
            if !appState.isModelLoaded {
                if appState.isModelDownloading {
                    VStack(spacing: 4) {
                        ProgressView(value: appState.modelDownloadProgress)
                        Text("Downloading model... \(Int(appState.modelDownloadProgress * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                } else {
                    Button("Download Model") {
                        appState.loadModel()
                    }
                    .padding(.horizontal)
                }
            }

            // Transcription status
            if appState.isTranscribing {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Transcribing...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
            }

            // Last transcription preview
            if !appState.lastCleanedText.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Last transcription:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(appState.lastCleanedText)
                        .font(.caption)
                        .lineLimit(3)
                        .textSelection(.enabled)
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(6)
                .padding(.horizontal)
            }

            // Error message
            if let error = appState.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }

            Divider()

            // Bottom actions
            HStack {
                Button("Open Babbl") {
                    print("[Babbl] Settings button pressed")
                    MainWindowController.shared.showWindow(appState: appState)
                }
                Spacer()
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 12)
        .frame(width: 320)
        .onAppear {
            appState.loadModel()
        }
    }

    private var statusColor: Color {
        if appState.isRecording { return .red }
        if appState.isTranscribing { return .orange }
        if appState.isModelLoaded { return .green }
        return .gray
    }

    private var statusText: String {
        if appState.isRecording { return "Recording..." }
        if appState.isTranscribing { return "Transcribing..." }
        if appState.isModelLoaded { return "Ready" }
        if appState.isModelDownloading { return "Downloading..." }
        return "Model not loaded"
    }
}
