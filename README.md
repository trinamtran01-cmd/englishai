# English AI App

Ứng dụng học tiếng Anh đa nền tảng (Android & Web) viết bằng Flutter, dùng Firebase (Authentication, Cloud Firestore, Hosting) và Google Gemini API cho các công cụ luyện tập AI: AI Camera từ vựng, Từ điển AI, Luyện Nghe & Nói, Luyện Shadowing, Luyện Viết (chấm theo IELTS).

Bản Web đang chạy: https://english-ai-app-9b33e.web.app

## Yêu cầu

- Flutter SDK (Dart 3), Android Studio / Android SDK nếu chạy Android
- Khoá Gemini API (lấy miễn phí tại https://aistudio.google.com/apikey)

## Chạy dự án

1. Cài thư viện:
   ```
   flutter pub get
   ```
2. Tạo tệp `.env` ở thư mục gốc (sao chép từ `.env.example`) và điền khoá Gemini:
   ```
   GEMINI_API_KEY=khoa_cua_ban
   ```
   Tệp `.env` không được đưa lên Git; thiếu tệp này các tính năng AI sẽ không hoạt động.
3. Chạy ứng dụng:
   ```
   flutter run -d chrome      # Web
   flutter run                # Android (thiết bị/máy ảo đang kết nối)
   ```

Cấu hình Firebase (`lib/firebase_options.dart`, `android/app/google-services.json`) đã có sẵn và trỏ tới project `english-ai-app-9b33e`. Tài khoản đăng ký mới mặc định là học viên; quyền quản trị được gán qua trường `role = "admin"` trong document `users/{uid}` trên Firestore.

## Triển khai bản Web

```
flutter build web
cp -r web/writing_task_images build/web/
mkdir -p build/web/shadowing_audio && cp web/shadowing_audio/*.wav build/web/shadowing_audio/
firebase deploy --only hosting
```

Hai lệnh `cp` là bắt buộc: `flutter build web` không tự chép ảnh đề Luyện Viết và audio Shadowing vào `build/web`.

## Cấu trúc thư mục

- `lib/models` — lớp dữ liệu (fromFirestore / toMap)
- `lib/services` — nghiệp vụ, gọi Firebase và Gemini
- `lib/screens` — giao diện học viên; `lib/screens/admin` — giao diện quản trị
- `firestore.rules` — phân quyền Firestore theo vai trò
- `tools/` — script Node.js sinh nội dung/audio Shadowing và nhập dữ liệu hàng loạt (cần `ADMIN_EMAIL`/`ADMIN_PASSWORD` qua biến môi trường khi chạy)
