import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/writing_task.dart';

/// Quản lý dữ liệu đề bài Luyện Viết AI trên Firebase Firestore.
///
/// Collection sử dụng: writing_tasks
class WritingTaskService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _tasksCollection {
    return _firestore.collection('writing_tasks');
  }

  /// Theo dõi danh sách đề bài.
  ///
  /// Sắp xếp mới nhất trước, thực hiện trong Flutter để không yêu
  /// cầu composite index trên Firebase.
  Stream<List<WritingTask>> getAllTasks() {
    return _tasksCollection.snapshots().map(
      (QuerySnapshot<Map<String, dynamic>> snapshot) {
        final List<WritingTask> tasks =
            snapshot.docs.map(WritingTask.fromFirestore).toList();

        tasks.sort(
          (WritingTask first, WritingTask second) {
            final DateTime firstDate = first.createdAt ??
                DateTime.fromMillisecondsSinceEpoch(0);

            final DateTime secondDate = second.createdAt ??
                DateTime.fromMillisecondsSinceEpoch(0);

            return secondDate.compareTo(firstDate);
          },
        );

        return tasks;
      },
    );
  }

  /// Lấy toàn bộ danh sách đề bài một lần.
  ///
  /// Dùng cho màn hình quản trị (tải lại thủ công sau khi thêm/sửa/xóa)
  /// thay vì lắng nghe stream liên tục, để tránh màn hình phía sau tự
  /// rebuild trong lúc dialog thêm/sửa đang đóng.
  Future<List<WritingTask>> getAllTasksOnce() async {
    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot =
          await _tasksCollection.get();

      final List<WritingTask> tasks =
          snapshot.docs.map(WritingTask.fromFirestore).toList();

      tasks.sort(
        (WritingTask first, WritingTask second) {
          final DateTime firstDate = first.createdAt ??
              DateTime.fromMillisecondsSinceEpoch(0);

          final DateTime secondDate = second.createdAt ??
              DateTime.fromMillisecondsSinceEpoch(0);

          return secondDate.compareTo(firstDate);
        },
      );

      return tasks;
    } on FirebaseException catch (error) {
      throw Exception(
        'Không thể tải danh sách đề bài: ${error.code}',
      );
    }
  }

  /// Lấy thông tin một đề bài theo ID.
  ///
  /// Trả về null nếu đề bài không tồn tại.
  Future<WritingTask?> getTaskById(String id) async {
    final String cleanId = id.trim();

    if (cleanId.isEmpty) {
      throw ArgumentError('ID đề bài không được để trống.');
    }

    try {
      final DocumentSnapshot<Map<String, dynamic>> document =
          await _tasksCollection.doc(cleanId).get();

      if (!document.exists) {
        return null;
      }

      return WritingTask.fromFirestore(document);
    } on FirebaseException catch (error) {
      throw Exception(
        'Không thể tải thông tin đề bài: ${error.code}',
      );
    }
  }

  /// Thêm một đề bài mới.
  ///
  /// Trả về ID của đề bài vừa được tạo.
  Future<String> addTask(WritingTask task) async {
    if (!task.isValid) {
      throw ArgumentError(
        'Đề bài phải có title, promptText và taskType hợp lệ.',
      );
    }

    try {
      final DocumentReference<Map<String, dynamic>> document =
          await _tasksCollection.add(task.toMap());

      return document.id;
    } on FirebaseException catch (error) {
      throw Exception('Không thể thêm đề bài: ${error.code}');
    }
  }

  /// Cập nhật thông tin một đề bài.
  Future<void> updateTask(WritingTask task) async {
    final String cleanId = task.id.trim();

    if (cleanId.isEmpty) {
      throw ArgumentError('ID đề bài không được để trống.');
    }

    if (!task.isValid) {
      throw ArgumentError(
        'Đề bài phải có title, promptText và taskType hợp lệ.',
      );
    }

    try {
      final Map<String, dynamic> data = task.toMap();

      // Không thay đổi thời gian tạo khi cập nhật.
      data.remove('createdAt');

      await _tasksCollection.doc(cleanId).update(data);
    } on FirebaseException catch (error) {
      throw Exception('Không thể cập nhật đề bài: ${error.code}');
    }
  }

  /// Kiểm tra collection đã có đề bài nào chưa.
  Future<bool> hasTasks() async {
    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot =
          await _tasksCollection.limit(1).get();

      return snapshot.docs.isNotEmpty;
    } on FirebaseException catch (error) {
      throw Exception(
        'Không thể kiểm tra dữ liệu đề bài: ${error.code}',
      );
    }
  }

  /// Xóa một đề bài khỏi Firestore.
  Future<void> deleteTask(String id) async {
    final String cleanId = id.trim();

    if (cleanId.isEmpty) {
      throw ArgumentError('ID đề bài không được để trống.');
    }

    try {
      await _tasksCollection.doc(cleanId).delete();
    } on FirebaseException catch (error) {
      throw Exception('Không thể xóa đề bài: ${error.code}');
    }
  }
}
