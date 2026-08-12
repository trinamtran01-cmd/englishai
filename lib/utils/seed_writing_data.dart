import '../models/writing_task.dart';
import '../services/writing_task_service.dart';

/// Script tiện ích: thêm 1 đề Writing Task 1 mẫu vào Firestore để có
/// dữ liệu test ngay cho tính năng Luyện Viết AI.
///
/// Được gọi từ nút "Tạo dữ liệu mẫu" trên AdminWritingScreen (chỉ
/// admin mới gọi được, đúng theo Firestore Rules). Hàm tự kiểm tra
/// collection đã có dữ liệu hay chưa trước khi thêm, tránh tạo trùng
/// khi bấm nút nhiều lần.
///
/// imageUrl được để trống có chủ đích: chưa có ảnh biểu đồ thật (tránh
/// dùng ảnh có bản quyền), admin tự thêm link ảnh thật sau qua màn
/// hình AdminWritingScreen.
Future<void> seedSampleWritingTask() async {
  final WritingTaskService taskService = WritingTaskService();

  final bool alreadyHasTasks = await taskService.hasTasks();

  if (alreadyHasTasks) {
    return;
  }

  final WritingTask sampleTask = WritingTask(
    id: '',
    title: 'Biểu đồ chi tiêu hộ gia đình theo tháng',
    taskType: 'task1',
    promptText:
        'The chart below shows how a typical household in a '
        'European country spent its income in a particular month. '
        'Summarise the information by selecting and reporting the '
        'main features, and make comparisons where relevant.',
    imageUrl: '',
    chartType: 'pie',
    minWords: 150,
    source: '',
    createdAt: DateTime.now(),
  );

  await taskService.addTask(sampleTask);
}
