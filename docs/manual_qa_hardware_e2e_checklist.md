# Manual QA Hardware E2E Checklist

Tujuan: verifikasi fitur yang tidak bisa tervalidasi penuh lewat test otomatis (kamera, permission OS, upload native, kondisi jaringan real, dan UX lintas role).

## 0) Persiapan

- Build terbaru terpasang di perangkat Android dan iOS.
- Gunakan minimal 4 akun:
  - `member`
  - `coach`
  - `staff`
  - `admin`
- Pastikan bucket Supabase:
  - `kta_app` private
  - `payment_proofs` private
- Pastikan migration sudah dijalankan:
  - `sql/hardening_rls_and_storage.sql`
  - `sql/competition_v4_sync.sql`

## 1) Auth + Profil

- Registrasi akun baru dari app.
  - Ekspektasi: akun auth terbentuk, profil `public.users` terbentuk, login sukses.
- Login akun existing.
  - Ekspektasi: masuk dashboard sesuai role aktif.
- Update profil (nama/telepon/tanggal lahir/alamat).
  - Ekspektasi: data tersimpan setelah relogin.
- Coba ubah field sensitif dari client (`roles`, `member_status`, `member_number`).
  - Ekspektasi: ditolak oleh RLS/grant.

## 2) KTA Flow

- User upload foto KTA dari galeri dan kamera.
  - Ekspektasi: upload ke path `kta/<uid>/...`.
- Submit KTA application.
  - Ekspektasi: status `pending`.
- Staff/Admin review: approve/reject.
  - Ekspektasi approve: role `member` terpasang, `active_role` jadi `member`, tanggal KTA terisi.
  - Ekspektasi reject: alasan tersimpan, role tidak berubah.

## 3) Payment Flow

- Member upload bukti bayar bulanan.
  - Ekspektasi: file ke `payment_proofs/payments/<uid>/...`.
- Create row payment `pending`.
- Staff/Admin verify payment.
  - Ekspektasi: status `verified`, `verified_by`, `verified_at` terisi.
- Uji signed URL bukti pembayaran dari role yang berhak.
  - Ekspektasi: URL aktif dan file bisa diakses.
- Uji akses file user lain.
  - Ekspektasi: ditolak.

## 4) Latihan + Skor

- Member buat sesi latihan (individual + group).
- Input skor panah lengkap, edit sebagian, lalu hapus sebagian.
  - Ekspektasi: `total_score` dan `accuracy_percentage` sinkron.
- Hapus sesi latihan.
  - Ekspektasi: `score_details` ikut terhapus (cascade) dan riwayat bersih.

## 5) Kelas + Attendance QR

- Coach buat kelas.
- Coach generate QR session.
  - Ekspektasi: session aktif 1, session sebelumnya nonaktif.
- Member scan QR valid.
  - Ekspektasi: `attendance_records` tercatat sekali per user per session.
- Scan QR invalid/expired.
  - Ekspektasi: gagal dengan pesan validasi.
- Staff/Admin lihat rekap attendance.
  - Ekspektasi: bisa baca seluruh record sesuai policy.

## 6) Notifikasi

- Admin/Staff kirim notifikasi:
  - broadcast (`user_id = null`)
  - personal (`user_id = target uid`)
- User buka halaman notifikasi.
  - Ekspektasi: hanya notifikasi global + miliknya.
- Tandai read.
  - Ekspektasi: status berubah untuk notifikasi miliknya.

## 7) Competition / Lomba

- Staff/Admin create competition news published + unpublished.
- Tambah winners (gold/silver/bronze).
- User member buka feed lomba.
  - Ekspektasi: hanya data published.
- Verifikasi `winner_names` + `medals` tampil sesuai data winners.
- Update dan delete berita kompetisi.
  - Ekspektasi: relasi winners aman, tidak ada orphan.

## 8) Role & Access Matrix

- Member:
  - bisa akses data miliknya
  - tidak bisa akses/ubah data user lain
- Coach:
  - bisa kelola kelas sendiri
  - bisa lihat data latihan sesuai policy
- Staff:
  - bisa proses payment/KTA/notifikasi
- Admin:
  - full operational access sesuai policy

## 9) Ketahanan Operasional

- Uji offline saat submit form kritikal:
  - registrasi/login
  - upload bukti bayar
  - scan attendance
  - simpan latihan
- Uji koneksi fluktuatif (wifi <-> seluler).
  - Ekspektasi: retry/error message jelas, tidak data corrupt.

## 10) Keamanan Dasar

- Coba path traversal pada nama file upload.
  - Ekspektasi: ditolak.
- Coba akses object bucket user lain via path manual.
  - Ekspektasi: ditolak.
- Coba update kolom sensitif via SQL client role `authenticated`.
  - Ekspektasi: ditolak.

## 11) Sign-off Criteria

- Semua skenario di atas lulus tanpa regresi.
- Tidak ada error RLS `42501` pada flow yang harus allowed.
- Tidak ada data lintas-user yang bocor.
- Tidak ada crash aplikasi pada flow kritikal.

