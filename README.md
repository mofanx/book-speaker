# 📖 Book Speaker

A Flutter app that helps children learn English by turning textbook dialogues into an interactive, sentence-by-sentence reader with text-to-speech.

## Features

- **Text Import** — Paste dialogue text directly
- **OCR Import** — Take a photo of a textbook page to extract text
- **Sentence Splitting** — Automatically splits text into individual sentences with speaker detection
- **Tap-to-Read** — Tap any sentence to hear it spoken aloud
- **Playback Controls** — Continuous play, loop, speed adjustment (0.2x–2.0x)
- **Offline** — TTS and OCR work without internet (uses on-device engines)

## Development Setup

This project is designed to be developed entirely in **GitHub Codespaces** — no local Flutter or Android SDK required.

### Quick Start

1. Push this repo to GitHub
2. Open in Codespaces (the devcontainer will auto-install Flutter + Android SDK)
3. Edit code with Windsurf or the Codespaces web editor
4. Build APK:
   ```bash
   flutter build apk --release
   ```
5. Or just push to `main` — GitHub Actions will build the APK automatically

### Download APK

Go to **Actions** tab → latest workflow run → download the `book-speaker-apk` artifact.

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── models/
│   └── lesson.dart           # Lesson & Sentence data models
├── services/
│   ├── tts_service.dart      # Text-to-Speech wrapper
│   ├── ocr_service.dart      # OCR text recognition
│   └── storage_service.dart  # Local data persistence (Hive)
└── screens/
    ├── home_screen.dart      # Lesson list
    ├── import_screen.dart    # Text/OCR import
    └── reader_screen.dart    # Core tap-to-read interface
```

## Tech Stack

| Component | Solution |
|-----------|----------|
| Framework | Flutter 3.24+ |
| TTS | `flutter_tts` (system TTS engine) |
| OCR | `google_mlkit_text_recognition` (offline) |
| Storage | `hive_flutter` |
| CI/CD | GitHub Actions |
| Dev Env | GitHub Codespaces |
