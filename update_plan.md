# Rencana Pembaruan FlyTube (Update Roadmap)

Pembaruan selanjutnya akan difokuskan pada peningkatan navigasi, manajemen koleksi pribadi (Playlist), dan pengalaman pencarian yang lebih pintar.

## Fitur yang Akan Dikembangkan

### 1. Sistem Navigasi Bawah (Bottom Navigation Bar)
*   **Perubahan Struktur:** Mengubah struktur `_AppShell` / `HomeScreen` menjadi aplikasi dengan tab navigasi di bagian bawah.
*   **Tab yang Tersedia:**
    *   🏠 **Home:** Halaman pencarian dan hasil utama (seperti tampilan saat ini).
    *   📚 **Playlist:** Halaman khusus untuk melihat daftar playlist pengguna.

### 2. Manajemen Playlist (Daftar Putar Pribadi)
*   **Penyimpanan Lokal:** Menggunakan `shared_preferences` (sudah tersedia di aplikasi) untuk menyimpan data playlist secara lokal dalam format JSON. Data tidak akan hilang saat aplikasi ditutup.
*   **Fitur CRUD Playlist:**
    *   **Buat (Create):** Membuat playlist baru dengan nama khusus (misal: "Playlist Belajar", "Pengantar Tidur").
    *   **Tambah/Hapus Video:** Menambahkan video dari hasil pencarian ke dalam playlist tertentu, serta menghapus video dari playlist.
    *   **Hapus Playlist (Delete):** Menghapus seluruh playlist jika sudah tidak dibutuhkan.
    *   **Putar Playlist:** Saat memilih playlist, pengguna akan masuk ke halaman daftar video di dalamnya dan bisa memutarnya.

### 3. Rekomendasi Pencarian (Search Suggestions)
*   **Auto-Complete:** Saat pengguna mulai mengetik di kolom pencarian, akan muncul *dropdown* atau *list* di bawah kolom yang berisi saran pencarian yang relevan (seperti di YouTube/Google).
*   **Integrasi API:** Menggunakan fitur bawaan `youtube_explode_dart` yaitu `getSearchSuggestions(query)` untuk menarik data rekomendasi secara *real-time*.

---

## ⚠️ User Review Required
Silakan tinjau dan berikan persetujuan Anda:
1. **Penyimpanan:** Playlist akan disimpan secara lokal di perangkat. Artinya, jika Anda menghapus *data aplikasi* atau meng-uninstall aplikasi, data playlist akan hilang. Apakah ini dapat diterima untuk versi saat ini?
2. **Bottom Navigation:** Saat ini *Mini Video Player* berada di atas layar bawah. Dengan adanya Bottom Navigation, *Mini Player* akan digeser sedikit ke atas agar tidak menutupi menu tab.

## Proposed Changes

### UI & Navigation
#### [MODIFY] `lib/main.dart`
- Menyesuaikan `_AppShell` untuk menggunakan `BottomNavigationBar` dengan 2 tab: Home dan Playlist.
- Menyesuaikan posisi *Mini Video Player* agar tidak menutupi *Bottom Navigation Bar*.

#### [NEW] `lib/screens/main_tab_screen.dart`
- Membuat layar induk yang mengatur transisi antar tab (Home vs Playlist).

### Playlist Feature
#### [NEW] `lib/providers/playlist_provider.dart`
- Membuat State Management baru untuk mengatur logika *Create, Read, Update, Delete* (CRUD) playlist.
- Menggunakan `SharedPreferences` untuk menyimpan data playlist ke format JSON.

#### [NEW] `lib/models/playlist_model.dart`
- Struktur data yang menyimpan ID playlist, nama, dan daftar `VideoModel`.

#### [NEW] `lib/screens/playlist_screen.dart`
- Halaman Tab ke-2 yang menampilkan daftar Playlist pengguna.
- Tombol *Floating Action Button* untuk membuat playlist baru.

#### [NEW] `lib/screens/playlist_detail_screen.dart`
- Halaman saat sebuah playlist diklik, menampilkan daftar lagu di dalamnya beserta tombol hapus.

### Search Suggestions
#### [MODIFY] `lib/screens/home_screen.dart`
- Mengubah `TextField` pencarian biasa menjadi `Autocomplete` atau menambahkan daftar saran (*overlay list*) yang merespons perubahan teks secara *real-time*.
- Menghubungkan fungsi *onChanged* ke provider untuk memuat saran pencarian.

#### [MODIFY] `lib/providers/search_provider.dart`
- Menambahkan fungsi `fetchSuggestions(String query)` yang memanggil *API Search Suggestions*.

## Verification Plan
### Manual Verification
- Mengetik "Alan Walk" di pencarian dan memastikan saran seperti "Alan Walker Faded" muncul di bawahnya.
- Membuat playlist baru, memasukkan 2 lagu, lalu menutup aplikasi secara paksa (*Force Close*).
- Membuka kembali aplikasi, berpindah ke tab Playlist, dan memastikan data playlist yang dibuat masih ada.
