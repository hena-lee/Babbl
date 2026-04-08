import Cocoa
import os.log

/// Pauses and resumes system media playback by simulating the media play/pause key.
/// Uses NSEvent.systemDefined which is App Store safe and requires no special entitlements.
/// Checks if media is actually playing before sending keys to avoid launching Music.app.
final class MediaController {
    private var didPauseMedia = false

    // MARK: - MediaRemote Integration

    private typealias MRNowPlayingIsPlayingFunc =
        @convention(c) (DispatchQueue, @escaping (Bool) -> Void) -> Void

    private static let mediaRemoteBundle: CFBundle? = {
        let path = "/System/Library/PrivateFrameworks/MediaRemote.framework"
        guard let url = CFURLCreateWithFileSystemPath(
            kCFAllocatorDefault, path as CFString, CFURLPathStyle.cfurlposixPathStyle, true
        ) else { return nil }
        return CFBundleCreate(kCFAllocatorDefault, url)
    }()

    /// Checks whether any app is currently playing media via the system Now Playing API.
    private static func isMediaPlaying() -> Bool {
        guard let bundle = mediaRemoteBundle,
              let pointer = CFBundleGetFunctionPointerForName(
                  bundle, "MRMediaRemoteGetNowPlayingApplicationIsPlaying" as CFString
              ) else {
            Log.audio.warning("MediaRemote not available, skipping media check")
            return false
        }

        let function = unsafeBitCast(pointer, to: MRNowPlayingIsPlayingFunc.self)

        let semaphore = DispatchSemaphore(value: 0)
        var isPlaying = false

        function(DispatchQueue.global(qos: .userInteractive)) { playing in
            isPlaying = playing
            semaphore.signal()
        }

        let result = semaphore.wait(timeout: .now() + 0.5)
        if result == .timedOut {
            Log.audio.warning("MediaRemote check timed out")
            return false
        }
        return isPlaying
    }

    /// Sends a media play/pause key press to pause any currently playing media.
    /// Only pauses if media is actually playing, to avoid launching Music.app.
    func pauseMedia() {
        guard Self.isMediaPlaying() else {
            Log.audio.info("No media playing, skipping pause")
            return
        }
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
