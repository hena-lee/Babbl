import SwiftUI
import Combine

struct RecordingOverlayView: View {
    let phase: OverlayPhase
    let amplitudePublisher: CurrentValueSubject<Float, Never>

    var body: some View {
        Group {
            switch phase {
            case .hidden:
                EmptyView()
            case .recording(let startTime):
                RecordingPhaseView(startTime: startTime, amplitudePublisher: amplitudePublisher)
            case .transcribing:
                TranscribingPhaseView()
            case .success:
                SuccessPhaseView()
            case .failure:
                FailurePhaseView()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .background(Color.black.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Recording Phase

private struct RecordingPhaseView: View {
    let startTime: Date
    let amplitudePublisher: CurrentValueSubject<Float, Never>

    @State private var elapsed: Int = 0
    @State private var amplitude: Float = 0

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 12) {
            AudioLevelBars(amplitude: amplitude)
                .frame(width: 32, height: 24)

            Text(formatTime(elapsed))
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundStyle(.white)
        }
        .onReceive(timer) { _ in
            elapsed = Int(Date().timeIntervalSince(startTime))
        }
        .onReceive(amplitudePublisher) { value in
            amplitude = value
        }
    }

    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Audio Level Bars

private struct AudioLevelBars: View {
    let amplitude: Float

    private let barCount = 5

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.red)
                    .frame(width: 3, height: barHeight(for: index))
                    .animation(.easeInOut(duration: 0.1), value: amplitude)
            }
        }
    }

    private func barHeight(for index: Int) -> CGFloat {
        let minHeight: CGFloat = 4
        let maxHeight: CGFloat = 24
        // Each bar responds slightly differently to amplitude for visual variety
        let scale = CGFloat(amplitude) * (1.0 + Float(index % 3) * 0.3).toCGFloat
        let height = minHeight + (maxHeight - minHeight) * min(scale * 8, 1.0)
        return max(minHeight, height)
    }
}

private extension Float {
    var toCGFloat: CGFloat { CGFloat(self) }
}

// MARK: - Transcribing Phase

private struct TranscribingPhaseView: View {
    var body: some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
                .colorScheme(.dark)

            Text("Transcribing...")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Success Phase

private struct SuccessPhaseView: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.system(size: 16))

            Text("Pasted!")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Failure Phase

private struct FailurePhaseView: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.on.clipboard")
                .foregroundStyle(.orange)
                .font(.system(size: 14))

            Text("Copied to clipboard — ⌘V to paste")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
        }
    }
}
