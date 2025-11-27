# Proyek Aplikasi VPN dengan Flutter

## Gambaran Umum

Proyek ini bertujuan untuk membangun aplikasi VPN fungsional untuk Android menggunakan Flutter. Tujuan utamanya adalah menyediakan alat yang mudah digunakan bagi pengguna untuk mengamankan dan mengalihkan seluruh lalu lintas internet perangkat mereka melalui server. Aplikasi ini akan menampilkan antarmuka yang sederhana dan intuitif untuk mengelola koneksi VPN.

## Fitur Utama

*   **Koneksi VPN Sistem-Luas:** Mengalihkan semua lalu lintas internet dari perangkat.
*   **Antarmuka Sederhana:** UI minimalis dengan tombol "Connect/Disconnect" yang jelas dan tampilan status koneksi.
*   **Manajemen Status Koneksi:** Memberikan umpan balik visual yang jelas tentang status VPN (Disconnected, Connecting, Connected, Disconnecting).
*   **Izin Asli (Native Permission):** Menangani permintaan izin VPN dari sistem operasi Android secara benar.

## Arsitektur & Pustaka

*   **Manajemen State:** `provider`
*   **Manajemen VPN (Native):** `flutter_vpn` (paket yang dipilih setelah evaluasi)
*   **Penyimpanan Lokal (Direncanakan):** `shared_preferences` untuk menyimpan detail koneksi.

---

## Rencana Implementasi Saat Ini: Integrasi `flutter_vpn`

**Tujuan:** Mengganti logika simulasi dengan implementasi VPN fungsional menggunakan paket `flutter_vpn`.

**Histori Keputusan (Penting):**
Upaya awal menggunakan paket `flutter_vpn_service` gagal. Paket tersebut tampaknya ditinggalkan atau tidak stabil (hanya ~35 unduhan), yang menyebabkan serangkaian error API yang tidak dapat diselesaikan. Sebagai respons, kami telah **menghapus `flutter_vpn_service`** dan beralih ke paket **`flutter_vpn`** yang lebih matang dan banyak digunakan. Proyek sekarang berada dalam keadaan bersih dan siap untuk integrasi baru.

**Langkah-langkah Rinci Berikutnya:**

1.  **Studi Paket `flutter_vpn`:**
    *   Mencari dokumentasi dan contoh resmi untuk `flutter_vpn`.
    *   Memahami API utamanya, termasuk metode untuk `connect`, `disconnect`, dan cara mendengarkan perubahan status.

2.  **Konfigurasi Proyek Android (jika diperlukan):**
    *   Memeriksa dokumentasi `flutter_vpn` untuk setiap konfigurasi `AndroidManifest.xml` atau `build.gradle` yang diperlukan. Umumnya, ini melibatkan penambahan izin `android.permission.BIND_VPN_SERVICE`.

3.  **Implementasi Logika di `VpnProvider` (`lib/main.dart`):**
    *   Mengimpor `package:flutter_vpn/flutter_vpn.dart`.
    *   Mengganti metode `connect()` dan `disconnect()` yang disimulasikan dengan panggilan API `flutter_vpn` yang sebenarnya.
    *   Mengatur listener untuk perubahan status dari `flutter_vpn` dan memperbarui state `VpnProvider` sesuai dengan itu.
    *   Menangani logika untuk meminta izin VPN dari pengguna saat pertama kali koneksi.

4.  **Pengujian & Iterasi:**
    *   Menjalankan aplikasi di perangkat Android fisik (emulator mungkin tidak mendukung VpnService).
    *   Memverifikasi bahwa tombol "Connect" berhasil meminta izin dan membuat koneksi VPN.
    *   Memverifikasi bahwa tombol "Disconnect" menghentikan koneksi.
    *   Memeriksa log untuk setiap error selama siklus hidup koneksi.
