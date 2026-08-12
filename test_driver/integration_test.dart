import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

/// Driver chạy trên máy host. Sau khi bài test kết thúc, đọc dữ liệu
/// ảnh chụp màn hình (được gửi lên qua binding.takeScreenshot()) từ
/// reportData và ghi từng ảnh PNG vào thư mục ./screenshots_tuan4
/// phục vụ báo cáo tuần 4.
Future<void> main() async {
  await integrationDriver(
    // Lưu ảnh đã chụp được ngay cả khi bài test thất bại giữa
    // chừng, để có thể xem đã dừng lại ở màn hình nào.
    writeResponseOnFailure: true,
    responseDataCallback: (Map<String, dynamic>? data) async {
      if (data == null) {
        return;
      }

      final List<dynamic>? screenshots = data['screenshots'] as List<dynamic>?;

      if (screenshots == null) {
        return;
      }

      final Directory outputDir = Directory('screenshots_tuan4');

      if (!outputDir.existsSync()) {
        outputDir.createSync(recursive: true);
      }

      for (final dynamic raw in screenshots) {
        final Map<String, dynamic> shot = raw as Map<String, dynamic>;
        final String name = shot['screenshotName'] as String;
        final List<dynamic> rawBytes = shot['bytes'] as List<dynamic>;
        final List<int> bytes =
            rawBytes.map((dynamic e) => (e as num).toInt()).toList();

        final File file = File('${outputDir.path}/$name.png');
        await file.writeAsBytes(bytes);

        // ignore: avoid_print
        print('Saved screenshot: ${file.path}');
      }
    },
  );
}
