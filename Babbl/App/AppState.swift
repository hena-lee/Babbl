import SwiftUI
import Combine
import os.log

enum OverlayPhase: Equatable {
    case hidden
    case recording(startTime: Date)
    case transcribing
    case success
    case failure
    case noSpeech
}

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
    @Published var overlayPhase: OverlayPhase = .hidden

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
    let transcriptionStore = TranscriptionStore()
    let overlayController = OverlayWindowController()
    let mediaController = MediaController()
    var hotkeyManager: HotkeyManager?

    // Track the app that was active before we started recording
    private var previousApp: NSRunningApplication?
    private var recordingStartTime: Date?
    private var overlaySubscription: AnyCancellable?
    private var skipPasteForCurrentTranscription = false

    init() {
        totalWordsTranscribed = UserDefaults.standard.integer(forKey: "totalWordsTranscribed")
        totalFillersRemoved = UserDefaults.standard.integer(forKey: "totalFillersRemoved")
        totalSecondsTranscribed = UserDefaults.standard.double(forKey: "totalSecondsTranscribed")

        // Restore output mode preference
        let savedOutputMode = UserDefaults.standard.string(forKey: "outputMode") ?? "typing"
        textInserter.mode = savedOutputMode == "clipboard" ? .clipboard : .typing

        setupOverlayObserver()
    }

    private func setupOverlayObserver() {
        overlaySubscription = $overlayPhase
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] phase in
                guard let self else { return }
                switch phase {
                case .hidden:
                    self.overlayController.dismiss()
                default:
                    let view = RecordingOverlayView(
                        phase: phase,
                        amplitudePublisher: self.audioCapture.amplitudeSubject
                    )
                    self.overlayController.show(rootView: view)
                }
            }
    }

    /// Strips control characters and enforces a length limit on transcription output.
    private static func sanitize(_ text: String) -> String {
        let maxLength = 10_000
        let stripped = String(text.unicodeScalars.filter { scalar in
            scalar.value >= 0x20 || scalar == "\n" || scalar == "\t"
        })
        if stripped.count > maxLength {
            return String(stripped.prefix(maxLength))
        }
        return stripped
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
            Log.general.warning("Tried to record but model not loaded")
            return
        }

        // If transcription is in progress, let it finish in background (skip paste)
        if isTranscribing {
            Log.general.info("Re-triggered during transcription — background transcription will save to history, skip paste")
            skipPasteForCurrentTranscription = true
        }

        // Remember which app was active before recording
        previousApp = NSWorkspace.shared.frontmostApplication
        recordingStartTime = Date()
        Log.general.info("Starting recording")

        // Pause background media if the user enabled this setting
        if UserDefaults.standard.bool(forKey: "pauseMediaDuringRecording") {
            mediaController.pauseMedia()
        }

        do {
            try audioCapture.startRecording()
            isRecording = true
            errorMessage = nil
            overlayPhase = .recording(startTime: recordingStartTime!)
            Log.general.info("Recording started")
        } catch {
            errorMessage = "Failed to start recording: \(error.localizedDescription)"
            Log.general.error("Failed to start recording: \(error.localizedDescription)")
            mediaController.resumeIfPaused()
        }
    }

    private func stopRecording() {
        isRecording = false
        let audioBuffer = audioCapture.stopRecording()
        let recordingDuration = recordingStartTime.map { Date().timeIntervalSince($0) } ?? 0

        Log.general.info("Recording stopped. Duration: \(String(format: "%.1f", recordingDuration))s")

        guard let audio = audioBuffer, !audio.isEmpty else {
            errorMessage = "No audio recorded"
            overlayPhase = .hidden
            mediaController.resumeIfPaused()
            Log.general.warning("No audio data captured")
            return
        }

        isTranscribing = true
        overlayPhase = .transcribing

        // Capture whether this transcription should skip paste (re-trigger case)
        let shouldSkipPaste = skipPasteForCurrentTranscription
        skipPasteForCurrentTranscription = false

        // Restore focus to the previous app BEFORE transcription
        let targetApp = previousApp
        if let app = targetApp, !shouldSkipPaste {
            Log.general.info("Restoring focus to previous app")
            app.activate()
        }

        Task {
            do {
                Log.general.info("Starting transcription...")
                let startTime = Date()
                let rawText = try await transcriber.transcribe(audioSamples: audio)
                let transcribeTime = Date().timeIntervalSince(startTime)
                Log.general.info("Transcription completed in \(String(format: "%.1f", transcribeTime))s (\(rawText.count) chars)")

                lastTranscription = rawText

                let filteredText = fillerFilter.filter(rawText)
                let cleanedText = Self.sanitize(filteredText)
                lastCleanedText = cleanedText

                // Update stats
                let wordCount = cleanedText.split(separator: " ").count
                let fillerCount = rawText.split(separator: " ").count - wordCount
                totalWordsTranscribed += wordCount
                totalFillersRemoved += max(fillerCount, 0)
                totalSecondsTranscribed += recordingDuration

                // Save to history BEFORE paste attempt (safety net)
                let record = TranscriptionRecord(
                    rawText: rawText,
                    cleanedText: cleanedText,
                    durationSeconds: recordingDuration
                )
                transcriptionStore.save(record)
                Log.general.info("Transcription saved to history")

                if shouldSkipPaste {
                    Log.general.info("Skipping paste (re-triggered during transcription)")
                    isTranscribing = false
                    mediaController.resumeIfPaused()
                    return
                }

                guard !cleanedText.isEmpty else {
                    Log.general.warning("Transcription produced empty text, nothing to paste")
                    isTranscribing = false
                    mediaController.resumeIfPaused()
                    overlayPhase = .noSpeech
                    let phaseAtSet = overlayPhase
                    try await Task.sleep(nanoseconds: 3_000_000_000)
                    if overlayPhase == phaseAtSet {
                        overlayPhase = .hidden
                    }
                    return
                }

                // Delay to ensure target app has regained focus before pasting
                try await Task.sleep(nanoseconds: 400_000_000) // 400ms

                Log.general.info("Inserting text, accessibility: \(AXIsProcessTrusted())")
                let didPaste = textInserter.insertText(cleanedText)
                Log.general.info("Text insertion completed (pasted: \(didPaste))")

                isTranscribing = false
                mediaController.resumeIfPaused()
                overlayPhase = didPaste ? .success : .failure

                // Auto-dismiss overlay
                let dismissDelay: UInt64 = didPaste ? 2_000_000_000 : 5_000_000_000
                let phaseAtSet = overlayPhase
                try await Task.sleep(nanoseconds: dismissDelay)
                if overlayPhase == phaseAtSet {
                    overlayPhase = .hidden
                }
            } catch {
                errorMessage = "Transcription failed: \(error.localizedDescription)"
                Log.general.error("Transcription failed: \(error.localizedDescription)")
                isTranscribing = false
                mediaController.resumeIfPaused()

                if !shouldSkipPaste {
                    overlayPhase = .failure
                    let phaseAtSet = overlayPhase
                    try? await Task.sleep(nanoseconds: 5_000_000_000)
                    if overlayPhase == phaseAtSet {
                        overlayPhase = .hidden
                    }
                }
            }
        }
    }

    func loadModel() {
        guard !isModelLoaded && !isModelDownloading else { return }
        isModelDownloading = true
        Log.general.info("Loading model: \(self.selectedModel.rawValue)")

        Task {
            do {
                try await transcriber.loadModel(selectedModel)
                isModelLoaded = true
                isModelDownloading = false
                Log.general.info("Model loaded: \(self.selectedModel.rawValue)")
            } catch {
                errorMessage = "Failed to load model: \(error.localizedDescription)"
                isModelDownloading = false
                Log.general.error("Failed to load model: \(error.localizedDescription)")
            }
        }
    }

    func switchModel(to model: WhisperModel) {
        guard model != selectedModel || !isModelLoaded else { return }
        selectedModel = model
        isModelLoaded = false
        isModelDownloading = true
        errorMessage = nil
        Log.general.info("Switching model to: \(model.rawValue)")

        Task {
            do {
                try await transcriber.loadModel(model)
                isModelLoaded = true
                isModelDownloading = false
                Log.general.info("Model switched to: \(model.rawValue)")
            } catch {
                errorMessage = "Failed to load model: \(error.localizedDescription)"
                isModelDownloading = false
                Log.general.error("Failed to switch model: \(error.localizedDescription)")
            }
        }
    }
}
