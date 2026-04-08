# Babbl

Intelligent voice-to-text for macOS. Transcribe speech locally with automatic filler word removal.

**Free and open source.** If Babbl is useful to you, consider [supporting the project](#support).

## Features

- **Local transcription** — powered by WhisperKit, runs entirely on-device with zero network calls
- **Smart filler removal** — context-aware filtering of "um", "like", "you know", "basically", etc. with per-word toggles in Settings
- **Media pause/resume** — automatically pauses YouTube, Spotify, or any playing media during recording, resumes when done
- **Recording overlay** — floating waveform visualization + timer while recording, status on completion
- **Auto-paste** — transcribed text is pasted directly into the active app, with clipboard fallback
- **Configurable hotkeys** — double-tap Option (default), or set a custom shortcut
- **Multiple Whisper models** — choose from Tiny to Large depending on speed/accuracy needs
- **Encrypted history** — transcription history is AES-256-GCM encrypted with Keychain-managed keys
- **Menu bar app** — lives in your menu bar, no Dock icon
- **Launch at login** — optional, configurable in Settings

## Requirements

- macOS 14.0+
- Apple Silicon Mac
- Xcode 16+ (for building from source)

## Setup

1. Clone the repo
2. Create a `Local.xcconfig` file in the project root:
   ```
   DEVELOPMENT_TEAM = YOUR_TEAM_ID
   ```
3. Generate the Xcode project:
   ```
   xcodegen generate
   ```
4. Open `Babbl.xcodeproj` and run (Cmd+R)
5. Grant microphone and accessibility permissions when prompted

## Privacy & Security

- No network access — audio and transcriptions never leave your Mac
- Transcription history encrypted at rest (AES-256-GCM, keys stored in macOS Keychain)
- Clipboard cleared after paste
- Temporary audio files cleaned up immediately after processing
- Hardened runtime enabled
- Minimal entitlements (microphone access only)

## Tech Stack

- Swift / SwiftUI
- WhisperKit (on-device speech-to-text)
- Core Audio / vDSP (native sample rate recording + resampling)
- CryptoKit (AES-256-GCM encryption)
- KeyboardShortcuts (hotkey management)
- AVFoundation (audio capture)

## Support

Babbl is free to use. If it saves you time, consider supporting its development — pay whatever you feel it's worth.

- [Ko-fi](https://ko-fi.com/h555exe) — one-time or recurring, no account needed

## License

[MIT](LICENSE)
