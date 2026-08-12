import '../models/shadowing_lesson.dart';
import '../models/shadowing_segment.dart';
import '../services/shadowing_lesson_service.dart';

/// Script tiện ích: thêm 1 bài luyện Shadowing mẫu vào Firestore để
/// có dữ liệu test ngay cho tính năng Luyện Shadowing.
///
/// Được gọi từ nút "Tạo dữ liệu mẫu" trên AdminShadowingScreen (chỉ
/// admin mới gọi được, đúng theo Firestore Rules). Hàm tự kiểm tra
/// collection đã có dữ liệu hay chưa trước khi thêm, tránh tạo trùng
/// khi bấm nút nhiều lần.
Future<void> seedSampleShadowingLesson() async {
  final ShadowingLessonService lessonService =
      ShadowingLessonService();

  final bool alreadyHasLessons = await lessonService.hasLessons();

  if (alreadyHasLessons) {
    return;
  }

  final String lessonId = await lessonService.addLesson(
    const ShadowingLesson(
      id: '',
      title: 'Giao tiếp cơ bản nơi công sở',
      description:
          'Luyện nhại các câu giao tiếp thường gặp trong môi '
          'trường làm việc',
      level: 'beginner',
    ),
  );

  const List<String> sampleSentences = <String>[
    'Good morning, how are you today?',
    'Could you send me that report by noon?',
    'Thank you so much for your help.',
  ];

  for (int index = 0; index < sampleSentences.length; index++) {
    await lessonService.addSegment(
      ShadowingSegment(
        id: '',
        lessonId: lessonId,
        order: index + 1,
        text: sampleSentences[index],
        ipaPronunciation: '',
      ),
    );
  }
}
