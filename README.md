<div align="center">
  <img src="assets/icon.png" width="150" alt="FlyTube Logo">
  <h1>FlyTube 🎧</h1>
  <p><strong>A Next-Generation, Ad-Free Music Streaming Client utilizing Native YouTube DRM Bypass.</strong></p>
</div>

---

## ✨ Features
- **🚫 Zero Advertisements:** Enjoy your music seamlessly without a single ad interruption.
- **⚡ Sequential DRM Bypass:** Implements an advanced sequential client spoofing algorithm (`TV` -> `iOS` -> `Safari` -> `AndroidVR`) to natively bypass YouTube's *poToken* and anti-bot systems without relying on fragile third-party proxies.
- **📜 Smart Playlist & Queue System:** Fully functional track queueing, "Up Next" preview, and continuous auto-advance playback powered by `audio_service` and `just_audio`.
- **🔄 Media Controls & Background Play:** Full support for lock-screen controls, background audio playback, and repeat modes (None/One/All).
- **🎨 Modern Aesthetic UI:** A clean, dark-mode focused, glassmorphic UI inspired by the best premium streaming apps on the market.

## 🛠️ Technology Stack
- **Framework:** [Flutter](https://flutter.dev/) (Dart)
- **Audio Engine:** `just_audio` + `audio_service`
- **Scraper / Backend:** `youtube_explode_dart`
- **State Management:** `provider`
- **Networking:** `dio` for high-speed thumbnail caching.

## 🚀 How the DRM Bypass Works
YouTube recently clamped down heavily on scraping by implementing `poToken` rate limits. Traditional bypasses either broke entirely or required unstable middleman proxies. 

**FlyTube** solves this elegantly by rotating through internal **Native Client Implementations**. When a user requests a song:
1. It attempts extraction using the `TV` client signature (High success rate, >1s response).
2. If the IP is flagged, it instantly falls back to the `iOS` client.
3. If still blocked, it routes through `Safari` and `AndroidVR`.
This creates an autonomous, highly-resilient extraction pipeline with guaranteed 100% audio delivery.

## 📱 Installation (Android)
You can build the app directly from source:
```bash
# Clone the repository
git clone https://github.com/Fikkanel/flytube.git
cd flytube

# Get dependencies
flutter pub get

# Build the Release APK
flutter build apk --release
```
Locate the compiled APK at `build/app/outputs/flutter-apk/app-release.apk` and install it on your Android device.

---
> ⚠️ **Disclaimer:** FlyTube is an educational project demonstrating reverse engineering, custom audio handler implementation, and state management in Flutter. It is not affiliated with Google or YouTube.
