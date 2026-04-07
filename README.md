# VoxScribe

Intelligent voice-to-text for macOS. Transcribe speech locally with automatic filler word removal.

## Features

- **Local transcription** — powered by WhisperKit, runs entirely on-device
- **Filler word removal** — automatically strips "um", "uh", "like", "you know", etc.
- **Menu bar app** — lives in your menu bar, no Dock icon
- **Option key hotkey** — double-tap Option to start/stop recording
- **Auto-paste** — transcribed text is pasted directly into the active app

## Requirements

- macOS 14.0+
- Apple Silicon Mac
- Xcode 16+ (for building)

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
4. Open `VoxScribe.xcodeproj` and run (Cmd+R)
5. Grant microphone and accessibility permissions when prompted

## Tech Stack

- Swift / SwiftUI
- WhisperKit (speech-to-text)
- KeyboardShortcuts (hotkey management)
- AVFoundation (audio capture)
