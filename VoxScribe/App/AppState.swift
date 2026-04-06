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
    @Published var selectedModel: WhisperModel = .medium

    let audioCapture = AudioCapture()
    let transcriber = WhisperTranscriber()
    let fillerFilter = FillerFilter()
    let textInserter = TextInserter()

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
            return
        }

        do {
            try audioCapture.startRecording()
            isRecording = true
            errorMessage = nil
        } catch {
            errorMessage = "Failed to start recording: \(error.localizedDescription)"
        }
    }

    private func stopRecording() {
        isRecording = false
        let audioBuffer = audioCapture.stopRecording()

        guard let audio = audioBuffer, !audio.isEmpty else {
            errorMessage = "No audio recorded"
            return
        }

        isTranscribing = true

        Task {
            do {
                let rawText = try await transcriber.transcribe(audioSamples: audio)
                lastTranscription = rawText
                let cleanedText = fillerFilter.filter(rawText)
                lastCleanedText = cleanedText
                textInserter.insertText(cleanedText)
                isTranscribing = false
            } catch {
                errorMessage = "Transcription failed: \(error.localizedDescription)"
                isTranscribing = false
            }
        }
    }

    func loadModel() {
        guard !isModelLoaded && !isModelDownloading else { return }
        isModelDownloading = true

        Task {
            do {
                try await transcriber.loadModel(selectedModel)
                isModelLoaded = true
                isModelDownloading = false
            } catch {
                errorMessage = "Failed to load model: \(error.localizedDescription)"
                isModelDownloading = false
            }
        }
    }
}
