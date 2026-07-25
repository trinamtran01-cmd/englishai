import 'package:cloud_firestore/cloud_firestore.dart';

/// Model đại diện cho tiến độ học tập của một người dùng
/// đối với một bài học.
///
/// Mỗi document trong collection "learning_progress"
/// tương ứng với tiến độ của một người dùng trong một bài học.
class LearningProgress {
  final String id;
  final String userId;
  final String lessonId;
  final String lessonTitle;
  final int totalWords;
  final int viewedWords;
  final double completionPercentage;
  final bool isCompleted;
  final int studyCount;
  final DateTime? firstStudiedAt;
  final DateTime? lastStudiedAt;
  final DateTime? completedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const LearningProgress({
    required this.id,
    required this.userId,
    required this.lessonId,
    required this.lessonTitle,
    required this.totalWords,
    required this.viewedWords,
    required this.completionPercentage,
    required this.isCompleted,
    required this.studyCount,
    this.firstStudiedAt,
    this.lastStudiedAt,
    this.completedAt,
    this.createdAt,
    this.updatedAt,
  });

  /// Tạo đối tượng LearningProgress từ document Firestore.
  factory LearningProgress.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final Map<String, dynamic> data =
        document.data() ?? <String, dynamic>{};

    final int totalWords = _parseInteger(
      data['totalWords'],
      defaultValue: 0,
    );

    final int viewedWords = _parseInteger(
      data['viewedWords'],
      defaultValue: 0,
    );

    return LearningProgress(
      id: document.id,
      userId: data['userId'] as String? ?? '',
      lessonId: data['lessonId'] as String? ?? '',
      lessonTitle: data['lessonTitle'] as String? ?? '',
      totalWords: totalWords,
      viewedWords: viewedWords,
      completionPercentage: _parsePercentage(
        data['completionPercentage'],
        totalWords: totalWords,
        viewedWords: viewedWords,
      ),
      isCompleted: data['isCompleted'] as bool? ?? false,
      studyCount: _parseInteger(
        data['studyCount'],
        defaultValue: 0,
      ),
      firstStudiedAt: _parseDateTime(
        data['firstStudiedAt'],
      ),
      lastStudiedAt: _parseDateTime(
        data['lastStudiedAt'],
      ),
      completedAt: _parseDateTime(
        data['completedAt'],
      ),
      createdAt: _parseDateTime(
        data['createdAt'],
      ),
      updatedAt: _parseDateTime(
        data['updatedAt'],
      ),
    );
  }

  /// Tạo đối tượng LearningProgress từ Map.
  factory LearningProgress.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    final int totalWords = _parseInteger(
      data['totalWords'],
      defaultValue: 0,
    );

    final int viewedWords = _parseInteger(
      data['viewedWords'],
      defaultValue: 0,
    );

    return LearningProgress(
      id: id,
      userId: data['userId'] as String? ?? '',
      lessonId: data['lessonId'] as String? ?? '',
      lessonTitle: data['lessonTitle'] as String? ?? '',
      totalWords: totalWords,
      viewedWords: viewedWords,
      completionPercentage: _parsePercentage(
        data['completionPercentage'],
        totalWords: totalWords,
        viewedWords: viewedWords,
      ),
      isCompleted: data['isCompleted'] as bool? ?? false,
      studyCount: _parseInteger(
        data['studyCount'],
        defaultValue: 0,
      ),
      firstStudiedAt: _parseDateTime(
        data['firstStudiedAt'],
      ),
      lastStudiedAt: _parseDateTime(
        data['lastStudiedAt'],
      ),
      completedAt: _parseDateTime(
        data['completedAt'],
      ),
      createdAt: _parseDateTime(
        data['createdAt'],
      ),
      updatedAt: _parseDateTime(
        data['updatedAt'],
      ),
    );
  }

  /// Chuyển tiến độ thành Map để lưu lên Firestore.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'userId': userId.trim(),
      'lessonId': lessonId.trim(),
      'lessonTitle': lessonTitle.trim(),
      'totalWords': totalWords,
      'viewedWords': viewedWords,
      'completionPercentage': safeCompletionPercentage,
      'isCompleted': isCompleted,
      'studyCount': studyCount,
      'firstStudiedAt': _dateTimeToTimestamp(
        firstStudiedAt,
      ),
      'lastStudiedAt': _dateTimeToTimestamp(
        lastStudiedAt,
      ),
      'completedAt': _dateTimeToTimestamp(
        completedAt,
      ),
      'createdAt': createdAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(createdAt!),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Tạo bản sao và thay đổi một số thông tin tiến độ.
  LearningProgress copyWith({
    String? id,
    String? userId,
    String? lessonId,
    String? lessonTitle,
    int? totalWords,
    int? viewedWords,
    double? completionPercentage,
    bool? isCompleted,
    int? studyCount,
    DateTime? firstStudiedAt,
    DateTime? lastStudiedAt,
    DateTime? completedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LearningProgress(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      lessonId: lessonId ?? this.lessonId,
      lessonTitle: lessonTitle ?? this.lessonTitle,
      totalWords: totalWords ?? this.totalWords,
      viewedWords: viewedWords ?? this.viewedWords,
      completionPercentage:
          completionPercentage ?? this.completionPercentage,
      isCompleted: isCompleted ?? this.isCompleted,
      studyCount: studyCount ?? this.studyCount,
      firstStudiedAt:
          firstStudiedAt ?? this.firstStudiedAt,
      lastStudiedAt: lastStudiedAt ?? this.lastStudiedAt,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Phần trăm hoàn thành giới hạn trong khoảng 0-100.
  double get safeCompletionPercentage {
    if (completionPercentage < 0) {
      return 0;
    }

    if (completionPercentage > 100) {
      return 100;
    }

    return completionPercentage;
  }

  /// Giá trị tiến độ trong khoảng 0.0-1.0,
  /// dùng trực tiếp cho LinearProgressIndicator.
  double get progressValue {
    return safeCompletionPercentage / 100;
  }

  /// Phần trăm hoàn thành đã làm tròn để hiển thị.
  int get roundedPercentage {
    return safeCompletionPercentage.round();
  }

  /// Số từ đã xem, giới hạn không vượt quá tổng số từ.
  int get safeViewedWords {
    if (viewedWords < 0) {
      return 0;
    }

    if (totalWords > 0 && viewedWords > totalWords) {
      return totalWords;
    }

    return viewedWords;
  }

  /// Kiểm tra dữ liệu tiến độ có hợp lệ hay không.
  bool get isValid {
    return userId.trim().isNotEmpty &&
        lessonId.trim().isNotEmpty &&
        totalWords >= 0 &&
        viewedWords >= 0;
  }

  /// Tính phần trăm hoàn thành dựa trên số từ đã xem.
  static double calculateCompletionPercentage({
    required int viewedWords,
    required int totalWords,
  }) {
    if (totalWords <= 0 || viewedWords <= 0) {
      return 0;
    }

    final int safeViewedWords =
        viewedWords > totalWords ? totalWords : viewedWords;

    return (safeViewedWords / totalWords) * 100;
  }

  /// Kiểm tra bài học đã hoàn thành dựa trên số từ đã xem.
  static bool calculateIsCompleted({
    required int viewedWords,
    required int totalWords,
  }) {
    return totalWords > 0 && viewedWords >= totalWords;
  }

  static int _parseInteger(
    dynamic value, {
    required int defaultValue,
  }) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    if (value is String) {
      return int.tryParse(value) ?? defaultValue;
    }

    return defaultValue;
  }

  static double _parsePercentage(
    dynamic value, {
    required int totalWords,
    required int viewedWords,
  }) {
    double percentage;

    if (value is num) {
      percentage = value.toDouble();
    } else if (value is String) {
      percentage = double.tryParse(value) ??
          calculateCompletionPercentage(
            viewedWords: viewedWords,
            totalWords: totalWords,
          );
    } else {
      percentage = calculateCompletionPercentage(
        viewedWords: viewedWords,
        totalWords: totalWords,
      );
    }

    if (percentage < 0) {
      return 0;
    }

    if (percentage > 100) {
      return 100;
    }

    return percentage;
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    return null;
  }

  static dynamic _dateTimeToTimestamp(
    DateTime? dateTime,
  ) {
    if (dateTime == null) {
      return null;
    }

    return Timestamp.fromDate(dateTime);
  }

  @override
  String toString() {
    return 'LearningProgress('
        'id: $id, '
        'userId: $userId, '
        'lessonId: $lessonId, '
        'lessonTitle: $lessonTitle, '
        'viewedWords: $viewedWords/$totalWords, '
        'completionPercentage: $completionPercentage, '
        'isCompleted: $isCompleted, '
        'studyCount: $studyCount'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is LearningProgress &&
        other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}