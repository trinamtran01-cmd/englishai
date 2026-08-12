import '../models/listening_video.dart';
import '../services/listening_video_service.dart';

/// Script tiện ích: thêm 1 bài luyện nghe mẫu vào Firestore để có
/// dữ liệu test ngay cho tính năng Luyện Nghe & Nói AI.
///
/// Được gọi từ nút "Tạo dữ liệu mẫu" trên AdminListeningScreen
/// (chỉ admin mới gọi được, đúng theo Firestore Rules). Hàm tự kiểm
/// tra collection đã có dữ liệu hay chưa trước khi thêm, tránh tạo
/// trùng khi bấm nút nhiều lần.
///
/// transcriptWords được để trống có chủ đích: transcript thật cần lấy
/// trực tiếp từ YouTube (nút "Show transcript" dưới video) hoặc từ
/// trang BBC Learning English gốc, sau đó dán vào qua màn hình
/// AdminListeningScreen (Admin sẽ tự tách thành danh sách từ).
Future<void> seedSampleListeningVideo() async {
  final ListeningVideoService videoService =
      ListeningVideoService();

  final bool alreadyHasVideos = await videoService.hasVideos();

  if (alreadyHasVideos) {
    return;
  }

  final ListeningVideo sampleVideo = ListeningVideo(
    id: '',
    title: 'Learning multiple languages',
    youtubeVideoId: '9ifQ3xRz4hM',
    description:
        'Is learning languages good for you? Bài 6 Minute English '
        'của BBC Learning English, chủ đề học ngoại ngữ có tốt cho '
        'não bộ không.',
    transcriptWords: const <String>[],
    speakingPrompt:
        'Describe one benefit of learning a new language, in your '
        'own words.',
    level: 'intermediate',
    createdAt: DateTime.now(),
  );

  await videoService.addVideo(sampleVideo);
}
