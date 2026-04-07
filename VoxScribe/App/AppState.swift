import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {
    @Published var isRecording = false
    @Published var isTranscribing = false
    @Published var isModelLoaded = false
    @Published var isModelDownloading = false
    @Published var modelDownloadProgress: Double = 0
    @Published var lastTranscription = ""
    @Published var lastCleanedText = ""
    @Published var errorMessage: String?
    @Published var selectedModel: WhisperModel = .small

    // Stats (persisted via UserDefaults)
    @Published var totalWordsTranscribed: Int {
        didSet { UserDefaults.standard.set(totalWordsTranscribed, forKey: "totalWordsTranscribed") }
    }
    @Published var totalFillersRemoved: Int {
        didSet { UserDefaults.standard.set(totalFillersRemoved, forKey: "totalFillersRemoved") }
    }
    @Published var totalSecondsTranscribed: Double {
        didSet { UserDefaults.standard.set(totalSecondsTranscribed, forKey: "totalSecondsTranscribed") }
    }

    let audioCapture = AudioCapture()
    let transcriber = WhisperTranscriber()
    let fillerFilter = FillerFilter()
    let textInserter = TextInserter()
    var hotkeyManager: HotkeyManager?

    // Track the app that was active before we started recording
    private var previousApp: NSRunningApplication?
    private var recordingStartTime: Date?

    init() {
        totalWordsTranscribed = UserDefaults.standard.integer(forKey: "totalWordsTranscribed")
        totalFillersRemoved = UserDefaults.standard.integer(forKey: "totalFillersRemoved")
        totalSecondsTranscribed = UserDefaults.standard.double(forKey: "totalSecondsTranscribed")

        // Restore output mode preference
        let savedOutputMode = UserDefaults.standard.string(forKey: "outputMode") ?? "typing"
        textInserter.mode = savedOutputMode == "clipboard" ? .clipboard : .typing
    }

    var formattedTimeSaved: String {
        // Estimate: average person types 40 WPM, speaks 130 WPM
        // Time saved = words * (1/40 - 1/130) minutes
        let minutesSaved = Double(totalWordsTranscribed) * (1.0/40.0 - 1.0/130.0)
        let totalSeconds = Int(minutesSaved * 60)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%dh %dm", hours, minutes)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, seconds)
        } else {
            return String(format: "%ds", max(seconds, 0))
        }
    }

    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        guard isModelLoaded else {
            errorMessage = "Model not loaded. Please wait for download to complete."
            print("[VoxScribe] ERROR: Tried to record but model not loaded")
            return
        }

        // Remember which app was active before recording
        previousApp = NSWorkspace.shared.frontmostApplication
        recordingStartTime = Date()
        print("[VoxScribe] Starting recording... Previous app: \(previousApp?.localizedName ?? "unknown")")

        do {
            try audioCapture.startRecording()
            isRecording = true
            errorMessage = nil
            print("[VoxScribe] Recording started successfully")
        } catch {
            errorMessage = "Failed to start recording: \(error.localizedDescription)"
            print("[VoxScribe] ERROR starting recording: \(error)")
        }
    }

    private func stopRecording() {
        isRecording = false
        let audioBuffer = audioCapture.stopRecording()
        let recordingDuration = recordingStartTime.map { Date().timeIntervalSince($0) } ?? 0

        print("[VoxScribe] Recording stopped. Duration: \(String(format: "%.1f", recordingDuration))s, samples: \(audioBuffer?.count ?? 0)")

        guard let audio = audioBuffer, !audio.isEmpty else {
            errorMessage = "No audio recorded"
            print("[VoxScribe] ERROR: No audio data captured")
            return
        }

        isTranscribing = true

        // Restore focus to the previous app BEFORE transcription
        let targetApp = previousApp
        if let app = targetApp {
            print("[VoxScribe] Restoring focus to: \(app.localizedName ?? "unknown")")
            app.activate()
        }

        Task {
            do {
                print("[VoxScribe] Starting transcription...")
                let startTime = Date()
                let rawText = try await transcriber.transcribe(audioSamples: audio)
                let transcribeTime = Date().timeIntervalSince(startTime)
                print("[VoxScribe] Transcription completed in \(String(format: "%.1f", transcribeTime))s: \"\(rawText)\"")

                lastTranscription = rawText

                let cleanedText = fillerFilter.filter(rawText)
                lastCleanedText = cleanedText
                print("[VoxScribe] After filler removal: \"\(cleanedText)\"")

                // Update stats
                let wordCount = cleanedText.split(separator: " ").count
                let fillerCount = rawText.split(separator: " ").count - wordCount
                totalWordsTranscribed += wordCount
                totalFillersRemoved += max(fillerCount, 0)
                totalSecondsTranscribed += recordingDuration

                // Small delay to ensure target app has focus before pasting
                try await Task.sleep(nanoseconds: 200_000_000) // 200ms

                print("[VoxScribe] Inserting text into active app...")
                print("[VoxScribe] Accessibility trusted: \(AXIsProcessTrusted())")
                textInserter.insertText(cleanedText)
                print("[VoxScribe] Text insertion completed")

                isTranscribing = false
            } catch {
                errorMessage = "Transcription failed: \(error.localizedDescription)"
                print("[VoxScribe] ERROR during transcription: \(error)")
                isTranscribing = false
            }
        }
    }

    func loadModel() {
        guard !isModelLoaded && !isModelDownloading else { return }
        isModelDownloading = true
        print("[VoxScribe] Loading model: \(selectedModel.rawValue)...")

        Task {
            do {
                try await transcriber.loadModel(selectedModel)
                isModelLoaded = true
                isModelDownloading = false
                print("[VoxScribe] Model loaded successfully: \(selectedModel.rawValue)")
            } catch {
                errorMessage = "Failed to load model: \(error.localizedDescription)"
                isModelDownloading = false
                print("[VoxScribe] ERROR loading model: \(error)")
            }
        }
    }

    func switchModel(to model: WhisperModel) {
        guard model != selectedModel || !isModelLoaded else { return }
        selectedModel = model
        isModelLoaded = false
        isModelDownloading = true
        errorMessage = nil
        print("[VoxScribe] Switching model to: \(model.rawValue)...")

        Task {
            do {
                try await transcriber.loadModel(model)
                isModelLoaded = true
                isModelDownloading = false
                print("[VoxScribe] Model switched successfully to: \(model.rawValue)")
            } catch {
                errorMessage = "Failed to load model: \(error.localizedDescription)"
                isModelDownloading = false
                print("[VoxScribe] ERROR switching model: \(error)")
            }
        }
    }
}
