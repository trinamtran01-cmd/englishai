import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:english_ai_app/main.dart' as app;

/// Tài khoản test được truyền vào lúc build bằng --dart-define,
/// KHÔNG được ghi cứng trong source code để tránh lộ mật khẩu
/// khi mã nguồn được lưu trên Git.
///
/// Ví dụ chạy (thay `deviceId` bằng id thiết bị/emulator thực tế):
/// flutter drive --driver=test_driver/integration_test.dart
///   --target=integration_test/screenshot_test.dart -d deviceId
///   --dart-define=TEST_EMAIL=... --dart-define=TEST_PASSWORD=...
///   --dart-define=TEST_ADMIN_EMAIL=... --dart-define=TEST_ADMIN_PASSWORD=...
const String testEmail = String.fromEnvironment('TEST_EMAIL');
const String testPassword = String.fromEnvironment('TEST_PASSWORD');
const String testAdminEmail = String.fromEnvironment('TEST_ADMIN_EMAIL');
const String testAdminPassword =
    String.fromEnvironment('TEST_ADMIN_PASSWORD');

/// Bơm khung hình liên tục cho đến khi tìm thấy [finder] hoặc hết
/// [timeout]. Dùng thay cho pumpAndSettle() ở những màn hình có
/// CircularProgressIndicator (animation vô hạn khiến pumpAndSettle
/// không bao giờ ổn định và luôn báo lỗi timeout).
Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
  Duration step = const Duration(milliseconds: 250),
}) async {
  final DateTime deadline = DateTime.now().add(timeout);

  while (DateTime.now().isBefore(deadline)) {
    if (finder.evaluate().isNotEmpty) {
      return;
    }

    await tester.pump(step);
  }

  if (finder.evaluate().isEmpty) {
    throw TestFailure(
      'pumpUntilFound: không tìm thấy widget sau '
      '${timeout.inSeconds}s: $finder',
    );
  }
}

/// Bơm khung hình liên tục cho đến khi [finder] KHÔNG còn trên cây
/// widget nữa hoặc hết [timeout]. Dùng để chờ một trạng thái loading
/// (ví dụ "AI đang phân tích...") biến mất trước khi chụp ảnh, thay
/// vì đoán đại một khoảng thời gian chờ cố định.
Future<void> pumpUntilGone(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
  Duration step = const Duration(milliseconds: 250),
}) async {
  final DateTime deadline = DateTime.now().add(timeout);

  while (DateTime.now().isBefore(deadline)) {
    if (finder.evaluate().isEmpty) {
      return;
    }

    await tester.pump(step);
  }
}

/// Giống pumpUntilFound nhưng chấp nhận nhiều finder, trả về chỉ số
/// finder đầu tiên xuất hiện. Dùng để nhận diện màn hình khởi động
/// (login / home / admin dashboard) mà không biết trước trạng thái
/// đăng nhập còn lưu lại từ lần chạy test trước hay không.
Future<int> pumpUntilAnyFound(
  WidgetTester tester,
  List<Finder> finders, {
  Duration timeout = const Duration(seconds: 45),
  Duration step = const Duration(milliseconds: 250),
}) async {
  final DateTime deadline = DateTime.now().add(timeout);

  while (DateTime.now().isBefore(deadline)) {
    for (int i = 0; i < finders.length; i++) {
      if (finders[i].evaluate().isNotEmpty) {
        return i;
      }
    }

    await tester.pump(step);
  }

  throw TestFailure(
    'pumpUntilAnyFound: không tìm thấy widget nào sau '
    '${timeout.inSeconds}s',
  );
}

/// Luôn chờ [finder] thực sự xuất hiện trên cây widget ngay trước
/// khi bấm, thay vì bấm ngay sau một pumpAndSettle() đơn lẻ — tránh
/// trường hợp bấm hụt vì StreamBuilder/FutureBuilder chưa kịp dựng
/// xong nội dung (ví dụ vừa gọi Firestore để tải thống kê/dữ liệu).
Future<void> tapWhenReady(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  await pumpUntilFound(tester, finder, timeout: timeout);
  await tester.tap(finder);
  await tester.pump(const Duration(milliseconds: 400));
}

/// Cuộn màn hình (nếu cần) rồi bấm vào [finder].
///
/// Nhiều màn hình trong app dùng ListView/GridView bên trong — với
/// Sliver, các item nằm ngoài vùng nhìn thấy (+ cache extent) CHƯA
/// được mount vào cây widget, nên find.text()/tester.tap() sẽ không
/// thấy chúng dù đúng chữ. scrollUntilVisible() vừa cuộn vừa kiểm
/// tra lại cho đến khi widget xuất hiện.
Future<void> scrollAndTap(
  WidgetTester tester,
  Finder finder, {
  double delta = 300,
  int maxScrolls = 20,
}) async {
  await tester.scrollUntilVisible(
    finder,
    delta,
    scrollable: find.byType(Scrollable).first,
    maxScrolls: maxScrolls,
  );
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  final IntegrationTestWidgetsFlutterBinding binding =
      IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  binding.defaultTestTimeout = const Timeout(Duration(minutes: 15));

  final Finder loginHeadline = find.text('Học tiếng Anh cùng AI');
  final Finder homeHeadline = find.text('Bạn muốn học gì hôm nay?');
  final Finder adminHeadline = find.text('Trang quản trị hệ thống');
  final Finder backButton = find.byTooltip('Back');

  Future<void> login(
    WidgetTester tester, {
    required String email,
    required String password,
  }) async {
    final Finder emailField = find.byType(TextFormField).at(0);
    final Finder passwordField = find.byType(TextFormField).at(1);

    await tester.enterText(emailField, email);
    await tester.pump();
    await tester.enterText(passwordField, password);
    await tester.pump();

    await tapWhenReady(
      tester,
      find.widgetWithText(ElevatedButton, 'Đăng nhập'),
    );
  }

  Future<void> logout(WidgetTester tester) async {
    await tapWhenReady(tester, find.byTooltip('Đăng xuất'));
    await tester.pumpAndSettle();

    await tapWhenReady(
      tester,
      find.widgetWithText(FilledButton, 'Đăng xuất'),
    );

    await pumpUntilFound(
      tester,
      loginHeadline,
      timeout: const Duration(seconds: 30),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Đăng nhập, điều hướng và chụp ảnh 5 màn hình cho báo cáo tuần 4',
    (WidgetTester tester) async {
      if (testEmail.isEmpty ||
          testPassword.isEmpty ||
          testAdminEmail.isEmpty ||
          testAdminPassword.isEmpty) {
        fail(
          'Thiếu tài khoản test. Hãy chạy flutter drive kèm '
          '--dart-define=TEST_EMAIL=... --dart-define=TEST_PASSWORD=... '
          '--dart-define=TEST_ADMIN_EMAIL=... '
          '--dart-define=TEST_ADMIN_PASSWORD=...',
        );
      }

      app.main();
      await tester.pump(const Duration(seconds: 2));

      // Bắt buộc trên Android trước khi gọi takeScreenshot(), nếu
      // không sẽ ném StateError khi chụp ảnh đầu tiên.
      await binding.convertFlutterSurfaceToImage();
      await tester.pump();

      // Nhận diện trạng thái khởi động: có thể đang ở màn hình đăng
      // nhập, hoặc vẫn còn phiên đăng nhập từ lần chạy test trước.
      final int initialState = await pumpUntilAnyFound(
        tester,
        <Finder>[loginHeadline, homeHeadline, adminHeadline],
        timeout: const Duration(seconds: 45),
      );

      if (initialState != 0) {
        await logout(tester);
      }

      await pumpUntilFound(tester, loginHeadline);
      await tester.pumpAndSettle();

      // ===== Hình 1: màn hình đăng nhập =====
      await binding.takeScreenshot('01_login');

      // ----- Đăng nhập học viên để đảm bảo có dữ liệu bài học mẫu -----
      await login(tester, email: testEmail, password: testPassword);
      await pumpUntilFound(
        tester,
        homeHeadline,
        timeout: const Duration(seconds: 30),
      );
      await tester.pumpAndSettle();

      await scrollAndTap(tester, find.text('Bài học tiếng Anh'));
      await pumpUntilFound(
        tester,
        backButton,
        timeout: const Duration(seconds: 30),
      );
      // Chờ LessonListScreen tạo dữ liệu bài học mẫu (nếu chưa có).
      await tester.pump(const Duration(seconds: 3));

      await tapWhenReady(tester, backButton);
      await tester.pumpAndSettle();
      await pumpUntilFound(tester, homeHeadline);

      await logout(tester);

      // ----- Đăng nhập admin: chụp dashboard + tạo câu hỏi mẫu -----
      await login(
        tester,
        email: testAdminEmail,
        password: testAdminPassword,
      );
      await pumpUntilFound(
        tester,
        adminHeadline,
        timeout: const Duration(seconds: 30),
      );
      await tester.pumpAndSettle();
      // Cho GridView/ListView của dashboard dựng xong hoàn toàn.
      await tester.pump(const Duration(seconds: 1));

      // ===== Hình 4: trang quản trị hệ thống =====
      await binding.takeScreenshot('04_admin_dashboard');

      await scrollAndTap(tester, find.text('Quản lý câu hỏi'));
      await pumpUntilFound(
        tester,
        find.text('Chọn bài học'),
        timeout: const Duration(seconds: 30),
      );
      await tester.pump(const Duration(seconds: 2));

      final Finder sampleQuestionButton = find.widgetWithText(
        OutlinedButton,
        'Tạo câu hỏi mẫu',
      );

      if (sampleQuestionButton.evaluate().isNotEmpty) {
        await tapWhenReady(tester, sampleQuestionButton);
        await tester.pump(const Duration(seconds: 3));
      }

      await tapWhenReady(tester, backButton);
      await tester.pumpAndSettle();
      await pumpUntilFound(tester, adminHeadline);

      await logout(tester);

      // ----- Đăng nhập lại học viên: chụp quiz, gợi ý AI, tiến độ -----
      await login(tester, email: testEmail, password: testPassword);
      await pumpUntilFound(
        tester,
        homeHeadline,
        timeout: const Duration(seconds: 30),
      );
      await tester.pumpAndSettle();

      await scrollAndTap(tester, find.text('Kiểm tra kiến thức'));
      await pumpUntilFound(
        tester,
        find.text('Chọn chủ đề kiểm tra'),
        timeout: const Duration(seconds: 30),
      );
      await tester.pump(const Duration(seconds: 2));

      // Danh sách bài kiểm tra nằm trong ListView, khác với các Card
      // ở màn hình Home (nằm trong Column) — tránh nhầm lẫn khi tìm.
      final Finder firstQuizLessonCard = find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Card),
          )
          .first;

      await tapWhenReady(
        tester,
        firstQuizLessonCard,
        timeout: const Duration(seconds: 20),
      );
      await tester.pump(const Duration(seconds: 1));

      final Finder noQuestionOkButton = find.widgetWithText(
        FilledButton,
        'Đã hiểu',
      );

      if (noQuestionOkButton.evaluate().isNotEmpty) {
        // Bài học đầu tiên chưa có câu hỏi (không tạo được dữ liệu mẫu
        // ở bước admin) — đóng thông báo và bỏ qua ảnh quiz thật.
        await tapWhenReady(tester, noQuestionOkButton);
        await tester.pumpAndSettle();
      } else {
        final Finder startQuizButton = find.widgetWithText(
          FilledButton,
          'Bắt đầu',
        );

        await tapWhenReady(
          tester,
          startQuizButton,
          timeout: const Duration(seconds: 15),
        );
        await tester.pumpAndSettle();

        // ===== Hình 2: màn hình làm bài kiểm tra =====
        await binding.takeScreenshot('02_quiz');

        // Chưa chọn đáp án nào => thoát không hiện dialog xác nhận.
        await tapWhenReady(tester, backButton);
        await tester.pumpAndSettle();
      }

      await tapWhenReady(tester, backButton);
      await tester.pumpAndSettle();
      await pumpUntilFound(tester, homeHeadline);

      await scrollAndTap(tester, find.text('Gợi ý từ AI'));
      await pumpUntilFound(
        tester,
        backButton,
        timeout: const Duration(seconds: 30),
      );
      // Chờ AiRecommendationService phân tích và sinh gợi ý xong hẳn
      // (chờ dòng "AI đang phân tích..." biến mất) thay vì đoán thời
      // gian chờ cố định — tránh chụp trúng lúc còn đang loading.
      await pumpUntilGone(
        tester,
        find.text('AI đang phân tích kết quả học tập...'),
        timeout: const Duration(seconds: 30),
      );
      await tester.pumpAndSettle();

      // ===== Hình 3: màn hình gợi ý học tập từ AI =====
      await binding.takeScreenshot('03_ai_recommendation');

      await tapWhenReady(tester, backButton);
      await tester.pumpAndSettle();
      await pumpUntilFound(tester, homeHeadline);

      await scrollAndTap(tester, find.text('Tiến độ học tập'));
      await pumpUntilFound(
        tester,
        backButton,
        timeout: const Duration(seconds: 30),
      );
      await tester.pump(const Duration(seconds: 2));

      // ===== Hình 5: màn hình tiến độ học tập =====
      await binding.takeScreenshot('05_progress');
    },
  );
}
