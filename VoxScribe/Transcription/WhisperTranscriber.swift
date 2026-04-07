import Foundation
import WhisperKit

enum WhisperModel: String, CaseIterable, Identifiable, Sendable {
    case tiny = "openai_whisper-tiny"
    case base = "openai_whisper-base"
    case small = "openai_whisper-small"
    case medium = "openai_whisper-medium"
    case largev3 = "openai_whisper-large-v3"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .tiny: return "Tiny (~75MB, fastest)"
        case .base: return "Base (~140MB, fast)"
        case .small: return "Small (~460MB, balanced)"
        case .medium: return "Medium (~1.5GB, recommended)"
        case .largev3: return "Large v3 (~3GB, best accuracy)"
        }
    }
}

@MainActor
final class WhisperTranscriber {
    private var whisperKit: WhisperKit?

    private static var downloadBase: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let folder = appSupport.appendingPathComponent("VoxScribe/Models", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    func loadModel(_ model: WhisperModel) async throws {
        let localModelDir = Self.localModelFolder(for: model)
        let needsDownload = !Self.modelExistsLocally(model)
        print("[VoxScribe:Transcriber] Loading model \(model.rawValue), download: \(needsDownload)")

        let kit: WhisperKit
        if needsDownload {
            kit = try await WhisperKit(
                model: model.rawValue,
                downloadBase: Self.downloadBase,
                verbose: false,
                prewarm: true,
                load: true,
                download: true
            )
        } else {
            kit = try await WhisperKit(
                downloadBase: Self.downloadBase,
                modelFolder: localModelDir.path,
                verbose: false,
                prewarm: true,
                load: true,
                download: false
            )
        }
        whisperKit = kit
    }

    private static func localModelFolder(for model: WhisperModel) -> URL {
        downloadBase.appendingPathComponent(
            "models/argmaxinc/whisperkit-coreml/\(model.rawValue)", isDirectory: true
        )
    }

    private static func modelExistsLocally(_ model: WhisperModel) -> Bool {
        let modelDir = localModelFolder(for: model)
        let requiredFiles = ["AudioEncoder.mlmodelc", "TextDecoder.mlmodelc", "MelSpectrogram.mlmodelc"]
        return requiredFiles.allSatisfy {
            FileManager.default.fileExists(atPath: modelDir.appendingPathComponent($0).path)
        }
    }

    func transcribe(audioSamples: [Float]) async throws -> String {
        guard let kit = whisperKit else {
            throw TranscriptionError.modelNotLoaded
        }

        let result = try await kit.transcribe(audioArray: audioSamples)
        let text = result.map { $0.text }.joined(separator: " ")
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum TranscriptionError: LocalizedError {
    case modelNotLoaded
    case transcriptionFailed(String)

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "Whisper model is not loaded. Please download a model first."
        case .transcriptionFailed(let detail):
            return "Transcription failed: \(detail)"
        }
    }
}
