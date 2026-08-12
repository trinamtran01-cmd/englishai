# Quy trình viết báo cáo tuần (đồ án English AI App)

Ghi chú quy trình để tự áp dụng nhất quán ở các báo cáo tuần tiếp theo, không cần hỏi lại từ đầu.

## 1. Vị trí & tên file

- Đề cương và tất cả báo cáo tuần trước nằm ở `C:\Users\Nam\Desktop\DACS` (file `.docx`, không phải trong repo này).
- Báo cáo tuần mới đặt tên `Bao_cao_tuan_X.docx`, lưu cùng thư mục `C:\Users\Nam\Desktop\DACS`.
- Các file `.docx` không đọc được bằng tool Read trực tiếp — dùng Python + `python-docx` (`pip install python-docx` nếu máy chưa có) để trích xuất/ghi nội dung. Khi in ra console, luôn chạy với `PYTHONIOENCODING=utf-8` để tránh lỗi encoding tiếng Việt.
- Lưu ý path: Bash tool trên máy này là Git Bash, còn Python là bản Windows native → không dùng path kiểu `/c/Users/...`, phải dùng path Windows đầy đủ (`C:\Users\...`) khi truyền cho script Python.

## 2. Format / style tài liệu

Style lấy chuẩn từ báo cáo tuần 1–4 (đã trích xuất bằng python-docx, xem style XML để biết chính xác):

- Khổ giấy A4, margin top/bottom/right = 2 cm, left = 2.5 cm.
- Font chữ nội dung (style `Normal`): **Times New Roman**, cỡ 12–13pt tùy dòng, line spacing đơn, không có space-after mặc định.
- Heading 1: font **Trebuchet MS**, cỡ 20pt, **bold**, màu xanh olive `#6B911C`.
- Heading 2: font **Trebuchet MS**, cỡ 16pt, **bold**, cùng màu `#6B911C`.
- Trang bìa/tiêu đề (không dùng style Heading, dùng Normal + override thủ công, căn giữa):
  - "BỘ GIÁO DỤC VÀ ĐÀO TẠO" / "TRƯỜNG ĐẠI HỌC CÔNG NGHỆ TP. HCM" — bold 13pt
  - "BÁO CÁO TUẦN X" — bold 20pt
  - "ĐỒ ÁN CƠ SỞ NGÀNH CÔNG NGHỆ THÔNG TIN" — bold 14pt
  - "Đề tài: ỨNG DỤNG DI ĐỘNG HỌC TIẾNG ANH DỰA TRÊN AI" — bold 13pt
  - Dòng GVHD / SV thực hiện / Lớp — thường (không bold)
  - "TP. Hồ Chí Minh, 2026" — italic
- Bảng: style viền đơn (`Table Grid`), hàng header tô nền xanh dương `#3B5BDB`, chữ header bold 10pt; các ô dữ liệu chữ thường 10pt.
- Ảnh minh họa: căn giữa, chèn ngay dưới đoạn mô tả liên quan; chú thích dạng `Hình N. <mô tả>` — italic, 10pt, màu xám `#555555`, căn giữa, đánh số lại từ Hình 1 cho mỗi báo cáo tuần (không nối tiếp số của tuần trước).
- Khi chưa có ảnh thật lúc soạn thảo: chèn khung placeholder (bảng 1 ô, viền đứt màu xám, nền `#F2F2F2`, chữ italic xám) ghi rõ "[ Chỗ chèn ảnh chụp màn hình — Hình N ]", kèm caption `Hình N. <mô tả>` ngay bên dưới — để biết chỗ cần thay ảnh thật sau.

Script mẫu tạo văn bản đúng style này (tạo `docx.Document()` từ đầu bằng python-docx, set style Normal/Heading1/Heading2, thêm bảng, thêm placeholder ảnh) đã dùng ở tuần 4 — tham khảo lại cấu trúc đó khi viết báo cáo tuần mới thay vì thiết kế lại từ đầu.

## 3. Cấu trúc mục lục chuẩn

Mỗi báo cáo tuần dùng đúng khung mục sau (đánh số Heading 1, có thể thêm Heading 2 con nếu nội dung dài):

1. Mục tiêu tuần
2. Công việc đã thực hiện (chia nhỏ theo module bằng Heading 2 nếu cần, chèn ảnh minh họa ngay dưới phần liên quan)
3. Kết quả đạt được (nên có bảng tổng hợp trạng thái từng chức năng)
4. Khó khăn & hướng giải quyết (nên có bảng 2 cột: khó khăn | hướng giải quyết)
5. Kế hoạch tuần tiếp theo
6. Kết luận tuần X

## 4. Quy trình viết nội dung (không bịa)

1. Đọc đề cương gốc + toàn bộ báo cáo tuần trước trong `C:\Users\Nam\Desktop\DACS` (qua python-docx) để nắm mục tiêu đồ án, những gì đã báo cáo — tránh lặp nội dung cũ.
2. Đọc source code thực tế trong `lib/` của project này (models/services/screens) để xác định chính xác cái gì đã code xong, đang dở, hay chưa làm. Nếu file nhiều/dài, có thể dùng subagent Explore để tổng hợp thay vì đọc thủ công từng file.
3. Đối chiếu: nếu không có commit/thay đổi code mới kể từ báo cáo tuần trước (kiểm tra `git log`, mtime file trong `lib/`), KHÔNG bịa ra "đã code thêm X" — báo lại tình huống này cho người dùng và đề xuất hướng nội dung phù hợp (ví dụ: tuần đó tập trung kiểm thử/hoàn thiện thay vì code mới), hỏi xác nhận trước khi viết.
4. Nếu thiếu thông tin (không rõ việc đã làm trong tuần, chưa có ảnh minh họa, v.v.) — hỏi lại người dùng trước khi viết, không tự suy đoán nội dung báo cáo.

## 5. Quy trình chụp ảnh minh họa (screenshot tự động)

Project đã có sẵn bộ test tự động chụp ảnh 5 màn hình chính (đăng nhập, quiz, gợi ý AI, admin dashboard, tiến độ học tập):

- `integration_test/screenshot_test.dart` — kịch bản: đăng nhập học viên → mở "Bài học tiếng Anh" (seed dữ liệu mẫu nếu Firestore rỗng) → đăng xuất → đăng nhập admin → chụp dashboard → tạo câu hỏi mẫu cho bài học đầu tiên (nếu chưa có) → đăng xuất → đăng nhập lại học viên → làm quiz (chụp câu hỏi đầu tiên) → xem gợi ý AI (đợi phân tích xong hẳn rồi mới chụp) → xem tiến độ học tập.
- `test_driver/integration_test.dart` — driver nhận ảnh (PNG bytes) từ `binding.takeScreenshot()`, lưu ra thư mục `./screenshots_tuan_X` (đổi tên thư mục output theo đúng tuần đang làm — hiện driver đang trỏ tới `screenshots_tuan4`, cần sửa lại tên thư mục trong `test_driver/integration_test.dart` cho tuần mới trước khi chạy).

Các bước chạy lại cho tuần mới:

1. Bật emulator Android, xác nhận bằng `flutter devices`.
2. Sửa tên thư mục output trong `test_driver/integration_test.dart` (`Directory('screenshots_tuan_X')`) nếu muốn tách riêng ảnh theo từng tuần.
3. Chạy:
   ```
   flutter drive --driver=test_driver/integration_test.dart \
     --target=integration_test/screenshot_test.dart -d <deviceId> \
     --dart-define=TEST_EMAIL=... --dart-define=TEST_PASSWORD=... \
     --dart-define=TEST_ADMIN_EMAIL=... --dart-define=TEST_ADMIN_PASSWORD=...
   ```
4. Kiểm tra `exit code` và log — nếu fail giữa chừng, ảnh đã chụp được vẫn được lưu (driver dùng `writeResponseOnFailure: true`). Xem log để biết dừng ở bước nào, sửa finder/thời gian chờ nếu app đổi UI.
5. Mở từng ảnh bằng tool Read để kiểm tra chất lượng trước khi chèn vào docx (tránh chèn nhầm ảnh đang loading, lỗi overflow, màn hình sai...).
6. Chèn ảnh vào đúng vị trí placeholder trong file `.docx` bằng script python-docx: tìm bảng 1 ô có text bắt đầu bằng `[` và chứa `Hình N ]`, thay bằng đoạn văn căn giữa chứa ảnh (dùng `run.add_picture(path, height=Cm(11))` — ảnh chụp màn hình điện thoại là ảnh dọc, nên set theo chiều cao ~11cm để width tự co giãn hợp lý), xóa bảng placeholder cũ đi.

Lưu ý kỹ thuật khi viết/sửa `integration_test/screenshot_test.dart`:
- KHÔNG dùng `tester.pumpAndSettle()` ngay sau các thao tác gọi mạng (login, load Firestore) vì `CircularProgressIndicator` chạy animation vô hạn sẽ làm `pumpAndSettle` timeout. Dùng helper `pumpUntilFound` / `pumpUntilGone` (bơm frame theo chu kỳ, kiểm tra finder) đã có sẵn trong file.
- Các phần tử nằm trong `ListView`/`GridView` (không phải `Column` thường) có thể CHƯA được mount vào cây widget nếu nằm ngoài viewport (Sliver lazy-mount) — dùng helper `scrollAndTap` (dựa trên `tester.scrollUntilVisible`) thay vì `tester.tap(find.text(...))` trực tiếp cho các item có thể nằm dưới màn hình (ví dụ 4 thẻ chức năng quản lý trên Admin Dashboard).

## 6. Tài khoản test — không hardcode vào CLAUDE.md

- Tài khoản test (email/mật khẩu học viên và admin) **không được ghi vào file này hay bất kỳ file nào trong repo** — chỉ truyền vào lúc chạy qua `--dart-define=TEST_EMAIL=... --dart-define=TEST_PASSWORD=... --dart-define=TEST_ADMIN_EMAIL=... --dart-define=TEST_ADMIN_PASSWORD=...` như hướng dẫn ở mục 5.
- File `integration_test/screenshot_test.dart` đọc các giá trị này qua `String.fromEnvironment(...)`, không hardcode giá trị thật trong source.
- Nếu người dùng cung cấp tài khoản test trực tiếp trong chat, chỉ dùng để chạy lệnh `flutter drive`, không lưu lại vào file cấu hình/markdown nào của project.
