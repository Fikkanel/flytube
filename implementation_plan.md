# FlyTube Boilerplate Implementation Plan

Tujuan dari plan ini adalah untuk membangun boilerplate aplikasi streaming "No-Ads" menggunakan Flutter, mengambil data langsung dari Invidious API, dan memutarnya di background menggunakan `just_audio` dan `audio_service`.

## Proposed Changes

Kita akan menerapkan arsitektur *Clean Code* dan State Management berbasis `Provider` (karena sangat cocok untuk aplikasi ukuran menengah tanpa overhead berlebihan). 

### 1. Inisialisasi Flutter & Dependencies
Menjalankan `flutter create .` di direktori `flytube` dan menambahkan packages berikut:
- `dio` (Networking)
- `provider` (State Management)
- `just_audio` (Audio Engine)
- `audio_service` (Background Playback & OS Notification)
- `shared_preferences` (Local Data)
- `cached_network_image` (Image Caching)
- `audio_session` (Audio Focus Management)

### 2. Struktur Folder & Kode Utama

Kita akan mengatur `lib/` menjadi seperti ini:
```text
lib/
 ┣ models/
 ┃ ┗ video_model.dart          # Data class untuk hasil pencarian Invidious
 ┣ services/
 ┃ ┣ api_service.dart          # Kelas untuk request Dio ke Invidious
 ┃ ┣ audio_handler.dart        # Implementasi BaseAudioHandler dari audio_service + just_audio
 ┃ ┗ storage_service.dart      # Wrapper untuk SharedPreferences
 ┣ providers/
 ┃ ┣ search_provider.dart      # Mengelola state pencarian & error handling
 ┃ ┗ player_provider.dart      # Opsional: untuk menghubungkan UI dengan audio_handler
 ┣ screens/
 ┃ ┣ home_screen.dart          # Halaman utama dengan SliverAppBar dan ListView hasil pencarian
 ┃ ┗ player_screen.dart        # Tampilan pemutar (Artwork berputar, progress, kontrol)
 ┣ theme/
 ┃ ┗ app_theme.dart            # Kumpulan warna minimalis 'Dark Mode' ala Spotify
 ┗ main.dart                   # Entry point, setup MultiProvider & inisialisasi AudioService
```

#### Komponen Kunci yang Harus Diimplementasikan:
1. **ApiService (lib/services/api_service.dart)**
   Akan ada fungsi `searchVideos(String query)` memanggil endpoint `https://api.invidious.io/api/v1/search?q=...`.

2. **AudioPlayerService / AudioHandler (lib/services/audio_handler.dart)**
   Saya akan merancang sistem *background service* dengan meng-extend `BaseAudioHandler` sehingga Play/Pause bisa dikendalikan dari Notification Bar OS, walau layar mati.

3. **HomeScreen (lib/screens/home_screen.dart)**
   Akan menggunakan `CustomScrollView` dan `SliverAppBar` agar memiliki efek scroll yang halus. Di dalamnya akan difetch data Invidious dan ditampilkan sebagai `ListTile` dengan `CachedNetworkImage` lengkap dengan Error Handling jika API mati / lambat.

4. **PlayerScreen (lib/screens/player_screen.dart)**
   Dilengkapi animasi rotasi `AnimationController` untuk Artwork, Slider untuk progress bar (dari `just_audio` position stream), dan Play/Next/Prev buttons.

## Open Questions

> [!NOTE]
> Instance `api.invidious.io` yang public sering kali terkena rate-limit atau tidak stabil tiap waktu. Apakah Anda ingin mencoba URL root API yang bisa dikonfigurasi / di-random dalam list, atau akan saya set hardcode satu server stabil (misal: `https://invidious.weblibre.org`) sebagai default dengan opsi merubahnya via `ApiService` nanti? 

## Verification Plan

1. **Automated Tests / Eksekusi Build**
   Saya akan menjalankan `flutter pub get` agar seluruh package resolve.
2. **Setup Background Execution OS**
   Memastikan `AndroidManifest.xml` telah di-tweak agar mendukung background service permission (`FOREGROUND_SERVICE` dan `FOREGROUND_SERVICE_MEDIA_PLAYBACK`).
3. Menulis file-file tersebut satu-persatu dan memastikan tidak ada error syntax.

Mohon konfirmasinya agar saya bisa mulai menulis kodenya!
