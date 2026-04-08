import os.log
import AVFoundation
import Combine
import Accelerate

final class AudioCapture {
    private var recorder: AVAudioRecorder?
    private var tempFileURL: URL?
    private let targetSampleRate: Double = 16000

    /// Real-time audio amplitude for UI visualization (published on main thread)
    let amplitudeSubject = CurrentValueSubject<Float, Never>(0.0)
    private var meteringTimer: Timer?

    /// Request microphone access (call once at app launch). No-op if already granted.
    static func requestMicrophoneAccess() {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        if status == .notDetermined {
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                Log.audio.info("Microphone permission \(granted ? "granted" : "denied")")
            }
        }
    }

    func startRecording() throws {
        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        Log.audio.info("Microphone authorization status: \(micStatus.rawValue)")
        guard micStatus == .authorized else {
            throw AudioCaptureError.microphonePermissionDenied
        }

        // Record at the hardware's native sample rate to avoid triggering
        // audio device reconfiguration (which fails on some Macs).
        // We resample to 16kHz after recording.
        let nativeRate = Self.defaultInputSampleRate()
        Log.audio.info("Default input device sample rate: \(nativeRate)Hz")

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("babbl_\(UUID().uuidString).wav")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: nativeRate,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsBigEndianKey: false
        ]

        let rec = try AVAudioRecorder(url: url, settings: settings)
        rec.isMeteringEnabled = true

        guard rec.record() else {
            throw AudioCaptureError.recordingFailed
        }

        self.recorder = rec
        self.tempFileURL = url

        Log.audio.info("Recording started at \(nativeRate)Hz (will resample to \(self.targetSampleRate)Hz)")

        // Poll metering for overlay amplitude bars
        meteringTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self, let r = self.recorder, r.isRecording else { return }
            r.updateMeters()
            let power = r.averagePower(forChannel: 0)
            // Convert dB (-160..0) to linear (0..1)
            let linear = Float(pow(10.0, Double(power) / 20.0))
            self.amplitudeSubject.send(max(0, min(1, linear)))
        }
    }

    func stopRecording() -> [Float]? {
        meteringTimer?.invalidate()
        meteringTimer = nil

        let duration = recorder?.currentTime ?? 0
        recorder?.stop()
        recorder = nil

        amplitudeSubject.send(0.0)

        guard let url = tempFileURL else {
            Log.audio.warning("No temp file URL")
            return nil
        }
        tempFileURL = nil
        defer { try? FileManager.default.removeItem(at: url) }

        do {
            let audioFile = try AVAudioFile(forReading: url)
            let fileRate = audioFile.fileFormat.sampleRate
            let frameCount = AVAudioFrameCount(audioFile.length)
            guard frameCount > 0 else {
                Log.audio.warning("Audio file is empty")
                return nil
            }

            let format = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: fileRate,
                channels: 1,
                interleaved: false
            )!

            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
                Log.audio.error("Failed to create read buffer")
                return nil
            }

            try audioFile.read(into: buffer)

            guard let channelData = buffer.floatChannelData?[0] else {
                Log.audio.error("No channel data in buffer")
                return nil
            }

            var samples = Array(UnsafeBufferPointer(start: channelData, count: Int(buffer.frameLength)))

            let maxAmp = samples.reduce(Float(0)) { max($0, abs($1)) }
            Log.audio.info("Read \(samples.count) samples at \(fileRate)Hz (\(String(format: "%.1f", duration))s), max amplitude: \(maxAmp)")

            if maxAmp < 0.0001 {
                Log.audio.warning("Audio is silent — check System Settings > Sound > Input")
            }

            // Resample from native rate to 16kHz for Whisper
            if fileRate != targetSampleRate {
                samples = resample(samples, from: fileRate, to: targetSampleRate)
                Log.audio.info("Resampled to \(samples.count) samples at \(self.targetSampleRate)Hz")
            }

            return samples.isEmpty ? nil : samples
        } catch {
            Log.audio.error("Failed to read audio file: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Hardware Query

    /// Returns the default input device's native sample rate.
    private static func defaultInputSampleRate() -> Double {
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &deviceID
        ) == noErr else {
            Log.audio.warning("Could not get default input device, falling back to 48kHz")
            return 48000
        }

        // Log the device name
        var nameRef: CFString = "" as CFString
        var nameSize = UInt32(MemoryLayout<CFString>.size)
        var nameAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        if AudioObjectGetPropertyData(deviceID, &nameAddr, 0, nil, &nameSize, &nameRef) == noErr {
            Log.audio.info("Input device: \(nameRef as String)")
        }

        var rate = Float64(0)
        size = UInt32(MemoryLayout<Float64>.size)
        addr.mSelector = kAudioDevicePropertyNominalSampleRate

        guard AudioObjectGetPropertyData(deviceID, &addr, 0, nil, &size, &rate) == noErr, rate > 0 else {
            Log.audio.warning("Could not get device sample rate, falling back to 48kHz")
            return 48000
        }

        return rate
    }

    // MARK: - Resampling

    /// Resample audio using vDSP linear interpolation.
    private func resample(_ samples: [Float], from sourceRate: Double, to targetRate: Double) -> [Float] {
        guard sourceRate > 0, targetRate > 0, sourceRate != targetRate else { return samples }

        let ratio = sourceRate / targetRate
        let outputCount = Int(Double(samples.count) / ratio)
        guard outputCount > 0 else { return [] }

        // Build control vector: fractional source indices for each output sample
        var control = [Float](repeating: 0, count: outputCount)
        let maxIndex = Float(samples.count - 2) // vlint reads [i] and [i+1]
        for i in 0..<outputCount {
            control[i] = min(Float(Double(i) * ratio), maxIndex)
        }

        var output = [Float](repeating: 0, count: outputCount)
        samples.withUnsafeBufferPointer { srcPtr in
            vDSP_vlint(srcPtr.baseAddress!, &control, 1, &output, 1, vDSP_Length(outputCount), vDSP_Length(samples.count))
        }

        return output
    }
}

enum AudioCaptureError: LocalizedError {
    case microphonePermissionDenied
    case recordingFailed

    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return "Microphone access denied. Go to System Settings > Privacy & Security > Microphone and enable Babbl."
        case .recordingFailed:
            return "Failed to start recording. Check that your microphone is working in System Settings > Sound > Input."
        }
    }
}
