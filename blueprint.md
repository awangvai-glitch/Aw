# Proyek Klien SSH Flutter

## Gambaran Umum

Aplikasi ini adalah klien SSH lintas platform yang dibuat dengan Flutter. Awalnya dirancang untuk mendelegasikan logika proksi ke alat eksternal, proyek ini sekarang beralih untuk **mengintegrasikan fungsionalitas proksi secara langsung** untuk kemudahan penggunaan.

Tujuan utamanya adalah menyediakan klien SSH mandiri yang dapat membuat terowongan koneksi melalui **proksi HTTP**, memungkinkan pengguna untuk terhubung ke server dengan aman dari belakang jaringan yang terbatas.

## Fitur yang Diterapkan

*   **Manajemen Koneksi:**
    *   Menyimpan detail koneksi terakhir (host, port, nama pengguna) menggunakan `shared_preferences`.
    *   Memuat detail ini secara otomatis saat aplikasi dimulai.
*   **Klien SSH Inti:**
    *   Terhubung ke server SSH menggunakan paket `dartssh2`.
    *   Mendukung autentikasi berbasis kata sandi.
    *   Menampilkan output dari server dan memungkinkan pengiriman perintah.
*   **Desain & UX:**
    *   Tema terang dan gelap dengan `provider`.
    *   Tipografi modern menggunakan `google_fonts`.

## Arsitektur & Pustaka

*   **Manajemen State:** `provider`
*   **Konektivitas SSH:** `dartssh2`
*   **Penyimpanan Lokal:** `shared_preferences`
*   **Gaya & Font:** `google_fonts`

## Rencana Saat Ini: Integrasi "SSH over HTTP Proxy"

**Tujuan:** Mengizinkan pengguna untuk terhubung ke server SSH melalui proksi HTTP langsung dari dalam aplikasi.

**Langkah-langkah Rinci:**

1.  **Perbarui UI (`lib/main.dart`):**
    *   Tambahkan `TextEditingController` untuk host dan port proksi.
    *   Tambahkan widget `TextField` di antarmuka pengguna agar pengguna dapat memasukkan alamat dan port proksi HTTP.

2.  **Modifikasi Logika Koneksi (`_connect` method):**
    *   Buat fungsi baru, misalnya `_createProxySocket`, yang akan menangani logika koneksi proksi.
    *   Fungsi ini akan:
        *   Membuka koneksi `Socket` ke proksi HTTP yang ditentukan.
        *   Mengirim permintaan `CONNECT <ssh_host>:<ssh_port> HTTP/1.1`.
        *   Memvalidasi respons dari proksi untuk memastikan koneksi `200 OK` diterima.
        *   Mengembalikan `Socket` yang sudah ditunnel jika berhasil.
    *   Ubah pemanggilan `SSHClient` untuk menggunakan `Socket` yang dibuat oleh proksi, bukan koneksi langsung.

3.  **Manajemen State & Error:**
    *   Simpan detail proksi menggunakan `shared_preferences` seperti detail koneksi lainnya.
    *   Tangani potensi eror selama koneksi proksi (misalnya, proksi tidak terjangkau, autentikasi gagal, dll.) dan tampilkan pesan yang jelas kepada pengguna.

4.  **Verifikasi & Pembersihan:**
    *   Uji fungsionalitas baru secara menyeluruh.
    *   Hapus referensi atau logika yang terkait dengan ketergantungan eksternal (`sing-box`) karena tidak lagi relevan.
