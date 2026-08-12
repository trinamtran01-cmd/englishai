import 'package:cloud_firestore/cloud_firestore.dart';

/// Model đại diện cho một đề bài Luyện Viết AI (IELTS Writing Task 1
/// hoặc Task 2).
///
/// Mỗi đối tượng WritingTask tương ứng với một document trong
/// collection "writing_tasks" trên Firestore.
class WritingTask {
  final String id;
  final String title;
  final String taskType;
  final String promptText;
  final String imageUrl;
  final String chartType;
  final int minWords;
  final String source;
  final DateTime? createdAt;

  const WritingTask({
    required this.id,
    required this.title,
    required this.taskType,
    required this.promptText,
    required this.imageUrl,
    required this.chartType,
    required this.minWords,
    required this.source,
    this.createdAt,
  });

  /// Tạo đối tượng WritingTask từ document Firestore.
  factory WritingTask.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final Map<String, dynamic> data =
        document.data() ?? <String, dynamic>{};

    return WritingTask(
      id: document.id,
      title: data['title'] as String? ?? '',
      taskType: data['taskType'] as String? ?? 'task1',
      promptText: data['promptText'] as String? ?? '',
      imageUrl: data['imageUrl'] as String? ?? '',
      chartType: data['chartType'] as String? ?? '',
      minWords: _parseMinWords(
        data['minWords'],
        data['taskType'] as String? ?? 'task1',
      ),
      source: data['source'] as String? ?? '',
      createdAt: _parseDateTime(data['createdAt']),
    );
  }

  /// Tạo đối tượng WritingTask từ Map.
  factory WritingTask.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    return WritingTask(
      id: id,
      title: data['title'] as String? ?? '',
      taskType: data['taskType'] as String? ?? 'task1',
      promptText: data['promptText'] as String? ?? '',
      imageUrl: data['imageUrl'] as String? ?? '',
      chartType: data['chartType'] as String? ?? '',
      minWords: _parseMinWords(
        data['minWords'],
        data['taskType'] as String? ?? 'task1',
      ),
      source: data['source'] as String? ?? '',
      createdAt: _parseDateTime(data['createdAt']),
    );
  }

  /// Chuyển WritingTask thành Map để lưu lên Firestore.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'title': title.trim(),
      'taskType': taskType.trim().toLowerCase(),
      'promptText': promptText.trim(),
      'imageUrl': imageUrl.trim(),
      'chartType': chartType.trim().toLowerCase(),
      'minWords': minWords,
      'source': source.trim(),
      'createdAt': createdAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(createdAt!),
    };
  }

  /// Tạo bản sao của đề bài và thay đổi một số thuộc tính.
  WritingTask copyWith({
    String? id,
    String? title,
    String? taskType,
    String? promptText,
    String? imageUrl,
    String? chartType,
    int? minWords,
    String? source,
    DateTime? createdAt,
  }) {
    return WritingTask(
      id: id ?? this.id,
      title: title ?? this.title,
      taskType: taskType ?? this.taskType,
      promptText: promptText ?? this.promptText,
      imageUrl: imageUrl ?? this.imageUrl,
      chartType: chartType ?? this.chartType,
      minWords: minWords ?? this.minWords,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Kiểm tra dữ liệu đề bài có đủ nội dung bắt buộc hay không.
  bool get isValid {
    return title.trim().isNotEmpty &&
        promptText.trim().isNotEmpty &&
        (taskType.trim() == 'task1' || taskType.trim() == 'task2');
  }

  /// Tên loại đề dùng để hiển thị.
  String get taskTypeLabel {
    return taskType.trim().toLowerCase() == 'task2'
        ? 'Writing Task 2'
        : 'Writing Task 1';
  }

  /// Số từ tối thiểu mặc định theo loại đề (150 cho Task 1, 250 cho
  /// Task 2) khi Firestore không có sẵn giá trị `minWords`.
  static int _parseMinWords(dynamic value, String taskType) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return taskType.trim().toLowerCase() == 'task2' ? 250 : 150;
  }

  /// Chuyển Timestamp hoặc DateTime thành DateTime.
  static DateTime? _parseDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }

  @override
  String toString() {
    return 'WritingTask('
        'id: $id, '
        'title: $title, '
        'taskType: $taskType, '
        'minWords: $minWords'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is WritingTask && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
