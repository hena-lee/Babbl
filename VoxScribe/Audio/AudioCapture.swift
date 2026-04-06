import AVFoundation
import Accelerate

final class AudioCapture {
    private var audioEngine: AVAudioEngine?
    private var recordedSamples: [Float] = []
    private let sampleRate: Double = 16000
    private let lock = NSLock()

    func startRecording() throws {
        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        )!

        guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            throw AudioCaptureError.converterCreationFailed
        }

        lock.lock()
        recordedSamples = []
        lock.unlock()

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            self?.processAudioBuffer(buffer, converter: converter, targetFormat: targetFormat)
        }

        engine.prepare()
        try engine.start()
        audioEngine = engine
    }

    func stopRecording() -> [Float]? {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil

        lock.lock()
        let samples = recordedSamples
        recordedSamples = []
        lock.unlock()

        return samples.isEmpty ? nil : samples
    }

    private func processAudioBuffer(
        _ buffer: AVAudioPCMBuffer,
        converter: AVAudioConverter,
        targetFormat: AVAudioFormat
    ) {
        let frameCount = AVAudioFrameCount(
            Double(buffer.frameLength) * sampleRate / buffer.format.sampleRate
        )
        guard frameCount > 0 else { return }

        guard let convertedBuffer = AVAudioPCMBuffer(
            pcmFormat: targetFormat,
            frameCapacity: frameCount
        ) else { return }

        var error: NSError?
        var hasData = true

        converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
            if hasData {
                outStatus.pointee = .haveData
                hasData = false
                return buffer
            }
            outStatus.pointee = .noDataNow
            return nil
        }

        if let error = error {
            print("Audio conversion error: \(error)")
            return
        }

        guard let channelData = convertedBuffer.floatChannelData?[0] else { return }
        let frameLength = Int(convertedBuffer.frameLength)

        lock.lock()
        recordedSamples.append(contentsOf: UnsafeBufferPointer(start: channelData, count: frameLength))
        lock.unlock()
    }
}

enum AudioCaptureError: LocalizedError {
    case converterCreationFailed
    case microphoneAccessDenied

    var errorDescription: String? {
        switch self {
        case .converterCreationFailed:
            return "Failed to create audio format converter"
        case .microphoneAccessDenied:
            return "Microphone access is required. Please grant permission in System Settings > Privacy & Security > Microphone."
        }
    }
}
