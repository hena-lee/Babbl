# Babbl

Intelligent voice-to-text for macOS. Transcribe speech locally with automatic filler word removal.

**Free and open source.** If Babbl is useful to you, consider [supporting the project](#support).

## Features

- **Local transcription** — powered by WhisperKit, runs entirely on-device. No data leaves your Mac.
- **Filler word removal** — automatically strips "um", "uh", "like", "you know", etc.
- **Menu bar app** — lives in your menu bar, no Dock icon
- **Option key hotkey** — double-tap Option to start/stop recording
- **Auto-paste** — transcribed text is pasted directly into the active app
- **Recording overlay** — floating waveform + timer while recording, status on completion
- **Transcription history** — every transcription is saved locally, so nothing is ever lost

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

## Tech Stack

- Swift / SwiftUI
- WhisperKit (on-device speech-to-text)
- KeyboardShortcuts (hotkey management)
- AVFoundation (audio capture)

## Support

Babbl is free to use. If it saves you time, consider supporting its development — pay whatever you feel it's worth.

- [Ko-fi](https://ko-fi.com/babbl) — one-time or recurring, no account needed
- [GitHub Sponsors](https://github.com/sponsors/hena-lee) — for developers with a GitHub account

## License

[MIT](LICENSE)
