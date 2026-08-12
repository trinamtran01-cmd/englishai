import 'package:cloud_firestore/cloud_firestore.dart';

/// Model đại diện cho một lần nộp bài Luyện Viết AI.
///
/// Mỗi đối tượng WritingAttempt tương ứng với một document trong
/// collection "writing_attempts" trên Firestore.
class WritingAttempt {
  final String id;
  final String userId;
  final String taskId;
  final String userText;
  final int wordCount;
  final DateTime? createdAt;

  const WritingAttempt({
    required this.id,
    required this.userId,
    required this.taskId,
    required this.userText,
    required this.wordCount,
    this.createdAt,
  });

  /// Tạo đối tượng WritingAttempt từ document Firestore.
  factory WritingAttempt.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final Map<String, dynamic> data =
        document.data() ?? <String, dynamic>{};

    return WritingAttempt(
      id: document.id,
      userId: data['userId'] as String? ?? '',
      taskId: data['taskId'] as String? ?? '',
      userText: data['userText'] as String? ?? '',
      wordCount: (data['wordCount'] as num?)?.toInt() ?? 0,
      createdAt: _parseDateTime(data['createdAt']),
    );
  }

  /// Tạo đối tượng WritingAttempt từ Map.
  factory WritingAttempt.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    return WritingAttempt(
      id: id,
      userId: data['userId'] as String? ?? '',
      taskId: data['taskId'] as String? ?? '',
      userText: data['userText'] as String? ?? '',
      wordCount: (data['wordCount'] as num?)?.toInt() ?? 0,
      createdAt: _parseDateTime(data['createdAt']),
    );
  }

  /// Chuyển WritingAttempt thành Map để lưu lên Firestore.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'userId': userId.trim(),
      'taskId': taskId.trim(),
      'userText': userText,
      'wordCount': wordCount,
      'createdAt': createdAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(createdAt!),
    };
  }

  /// Tạo bản sao của lần nộp bài và thay đổi một số thuộc tính.
  WritingAttempt copyWith({
    String? id,
    String? userId,
    String? taskId,
    String? userText,
    int? wordCount,
    DateTime? createdAt,
  }) {
    return WritingAttempt(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      taskId: taskId ?? this.taskId,
      userText: userText ?? this.userText,
      wordCount: wordCount ?? this.wordCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Kiểm tra dữ liệu có đủ nội dung bắt buộc hay không.
  bool get isValid {
    return userId.trim().isNotEmpty &&
        taskId.trim().isNotEmpty &&
        userText.trim().isNotEmpty;
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
    return 'WritingAttempt('
        'id: $id, '
        'taskId: $taskId, '
        'wordCount: $wordCount'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is WritingAttempt && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
