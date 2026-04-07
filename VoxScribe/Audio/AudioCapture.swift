import AVFoundation

final class AudioCapture {
    private var audioEngine: AVAudioEngine?
    private var recordedSamples: [Float] = []
    private let sampleRate: Double = 16000
    private let lock = NSLock()

    func startRecording() throws {
        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        print("[VoxScribe:Audio] Input format: \(inputFormat.sampleRate)Hz, \(inputFormat.channelCount)ch, \(inputFormat.commonFormat.rawValue)")

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

        var bufferCount = 0
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            bufferCount += 1
            if bufferCount <= 3 {
                // Log first few buffers to verify we're getting real audio
                if let data = buffer.floatChannelData?[0] {
                    let samples = Array(UnsafeBufferPointer(start: data, count: min(Int(buffer.frameLength), 10)))
                    let maxVal = samples.map { abs($0) }.max() ?? 0
                    print("[VoxScribe:Audio] Buffer #\(bufferCount): \(buffer.frameLength) frames, max amplitude: \(maxVal)")
                }
            }
            self?.processAudioBuffer(buffer, converter: converter, targetFormat: targetFormat)
        }

        engine.prepare()
        try engine.start()
        audioEngine = engine
        print("[VoxScribe:Audio] Engine started")
    }

    func stopRecording() -> [Float]? {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil

        lock.lock()
        let samples = recordedSamples
        recordedSamples = []
        lock.unlock()

        if !samples.isEmpty {
            let maxAmplitude = samples.map { abs($0) }.max() ?? 0
            let rms = sqrt(samples.map { $0 * $0 }.reduce(0, +) / Float(samples.count))
            print("[VoxScribe:Audio] Captured \(samples.count) samples (\(String(format: "%.1f", Double(samples.count) / sampleRate))s), max amplitude: \(maxAmplitude), RMS: \(rms)")
        } else {
            print("[VoxScribe:Audio] No samples captured!")
        }

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
            print("[VoxScribe:Audio] Conversion error: \(error)")
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

    var errorDescription: String? {
        switch self {
        case .converterCreationFailed:
            return "Failed to create audio format converter"
        }
    }
}
