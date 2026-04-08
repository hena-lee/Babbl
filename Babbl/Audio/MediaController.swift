import Cocoa
import os.log

/// Pauses and resumes system media playback by simulating the media play/pause key.
/// Uses NSEvent.systemDefined which is App Store safe and requires no special entitlements.
final class MediaController {
    private var didPauseMedia = false

    /// Sends a media play/pause key press to pause any currently playing media.
    /// Tracks that we initiated the pause so `resumeIfPaused()` knows to resume.
    func pauseMedia() {
        Self.sendPlayPauseKey()
        didPauseMedia = true
        Log.audio.info("Sent media pause key")
    }

    /// Sends a media play/pause key press to resume, but only if we previously paused.
    func resumeIfPaused() {
        guard didPauseMedia else { return }
        didPauseMedia = false
        Self.sendPlayPauseKey()
        Log.audio.info("Sent media resume key")
    }

    /// Resets pause tracking without sending a key event.
    func reset() {
        didPauseMedia = false
    }

    // MARK: - Media Key Simulation

    private static let playPauseKeyType: Int32 = 16 // NX_KEYTYPE_PLAY

    private static func sendPlayPauseKey() {
        // Media key events encode key state inside data1:
        //   data1 = (keyType << 16) | (keyState << 8)
        //   keyState: 0x0a = key down, 0x0b = key up

        // Key down
        let downEvent = NSEvent.otherEvent(
            with: .systemDefined,
            location: .zero,
            modifierFlags: NSEvent.ModifierFlags(rawValue: 0xa00),
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            subtype: 8,
            data1: Int((playPauseKeyType << 16) | (0x0a << 8)),
            data2: -1
        )
        downEvent?.cgEvent?.post(tap: .cghidEventTap)

        usleep(10_000) // 10ms between down/up

        // Key up
        let upEvent = NSEvent.otherEvent(
            with: .systemDefined,
            location: .zero,
            modifierFlags: NSEvent.ModifierFlags(rawValue: 0xb00),
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            subtype: 8,
            data1: Int((playPauseKeyType << 16) | (0x0b << 8)),
            data2: -1
        )
        upEvent?.cgEvent?.post(tap: .cghidEventTap)
    }
}
