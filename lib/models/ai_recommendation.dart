import 'package:cloud_firestore/cloud_firestore.dart';

/// Loại đề xuất do hệ thống AI tạo ra.
enum RecommendationType {
  /// Người dùng cần học lại bài học.
  relearn,

  /// Người dùng cần ôn tập để củng cố kiến thức.
  review,

  /// Người dùng nên luyện tập thêm.
  practice,

  /// Người dùng nên hoàn thành bài học đang học dở.
  completeLesson,

  /// Người dùng nên làm bài kiểm tra.
  takeQuiz,

  /// Người dùng đã học tốt và có thể chuyển sang bài khác.
  continueLearning,
}

/// Model đại diện cho một gợi ý học tập từ AI.
///
/// Gợi ý được tạo bằng phương pháp:
/// - Rule-based: phân tích điểm và ngưỡng kết quả.
/// - Content-based: đề xuất dựa trên bài học cụ thể.
///
/// Trong giai đoạn hiện tại, gợi ý được tính trực tiếp từ:
/// - Tiến độ học tập.
/// - Kết quả kiểm tra.
/// - Số câu trả lời sai.
/// - Số lần làm bài.
class AiRecommendation {
  final String id;
  final String userId;
  final String lessonId;
  final String lessonTitle;
  final RecommendationType type;
  final String reason;
  final String suggestedAction;
  final int priorityScore;
  final double latestQuizScore;
  final double bestQuizScore;
  final double learningProgress;
  final int incorrectAnswers;
  final int quizAttempts;
  final bool hasQuizResult;
  final bool isLessonCompleted;
  final DateTime? generatedAt;

  const AiRecommendation({
    required this.id,
    required this.userId,
    required this.lessonId,
    required this.lessonTitle,
    required this.type,
    required this.reason,
    required this.suggestedAction,
    required this.priorityScore,
    required this.latestQuizScore,
    required this.bestQuizScore,
    required this.learningProgress,
    required this.incorrectAnswers,
    required this.quizAttempts,
    required this.hasQuizResult,
    required this.isLessonCompleted,
    this.generatedAt,
  });

  /// Tạo AiRecommendation từ document Firestore.
  factory AiRecommendation.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final Map<String, dynamic> data =
        document.data() ?? <String, dynamic>{};

    return AiRecommendation(
      id: document.id,
      userId: data['userId'] as String? ?? '',
      lessonId: data['lessonId'] as String? ?? '',
      lessonTitle: data['lessonTitle'] as String? ?? '',
      type: _parseRecommendationType(
        data['type'],
      ),
      reason: data['reason'] as String? ?? '',
      suggestedAction:
          data['suggestedAction'] as String? ?? '',
      priorityScore: _parseInteger(
        data['priorityScore'],
        defaultValue: 0,
      ),
      latestQuizScore: _parseDouble(
        data['latestQuizScore'],
        defaultValue: 0,
      ),
      bestQuizScore: _parseDouble(
        data['bestQuizScore'],
        defaultValue: 0,
      ),
      learningProgress: _parseDouble(
        data['learningProgress'],
        defaultValue: 0,
      ),
      incorrectAnswers: _parseInteger(
        data['incorrectAnswers'],
        defaultValue: 0,
      ),
      quizAttempts: _parseInteger(
        data['quizAttempts'],
        defaultValue: 0,
      ),
      hasQuizResult:
          data['hasQuizResult'] as bool? ?? false,
      isLessonCompleted:
          data['isLessonCompleted'] as bool? ?? false,
      generatedAt: _parseDateTime(
        data['generatedAt'],
      ),
    );
  }

  /// Tạo AiRecommendation từ Map.
  factory AiRecommendation.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    return AiRecommendation(
      id: id,
      userId: data['userId'] as String? ?? '',
      lessonId: data['lessonId'] as String? ?? '',
      lessonTitle: data['lessonTitle'] as String? ?? '',
      type: _parseRecommendationType(
        data['type'],
      ),
      reason: data['reason'] as String? ?? '',
      suggestedAction:
          data['suggestedAction'] as String? ?? '',
      priorityScore: _parseInteger(
        data['priorityScore'],
        defaultValue: 0,
      ),
      latestQuizScore: _parseDouble(
        data['latestQuizScore'],
        defaultValue: 0,
      ),
      bestQuizScore: _parseDouble(
        data['bestQuizScore'],
        defaultValue: 0,
      ),
      learningProgress: _parseDouble(
        data['learningProgress'],
        defaultValue: 0,
      ),
      incorrectAnswers: _parseInteger(
        data['incorrectAnswers'],
        defaultValue: 0,
      ),
      quizAttempts: _parseInteger(
        data['quizAttempts'],
        defaultValue: 0,
      ),
      hasQuizResult:
          data['hasQuizResult'] as bool? ?? false,
      isLessonCompleted:
          data['isLessonCompleted'] as bool? ?? false,
      generatedAt: _parseDateTime(
        data['generatedAt'],
      ),
    );
  }

  /// Chuyển gợi ý thành Map để lưu lên Firestore.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'userId': userId.trim(),
      'lessonId': lessonId.trim(),
      'lessonTitle': lessonTitle.trim(),
      'type': type.name,
      'reason': reason.trim(),
      'suggestedAction': suggestedAction.trim(),
      'priorityScore': safePriorityScore,
      'latestQuizScore': safeLatestQuizScore,
      'bestQuizScore': safeBestQuizScore,
      'learningProgress': safeLearningProgress,
      'incorrectAnswers': incorrectAnswers,
      'quizAttempts': quizAttempts,
      'hasQuizResult': hasQuizResult,
      'isLessonCompleted': isLessonCompleted,
      'generatedAt': generatedAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(generatedAt!),
    };
  }

  /// Tạo bản sao và thay đổi một số thuộc tính.
  AiRecommendation copyWith({
    String? id,
    String? userId,
    String? lessonId,
    String? lessonTitle,
    RecommendationType? type,
    String? reason,
    String? suggestedAction,
    int? priorityScore,
    double? latestQuizScore,
    double? bestQuizScore,
    double? learningProgress,
    int? incorrectAnswers,
    int? quizAttempts,
    bool? hasQuizResult,
    bool? isLessonCompleted,
    DateTime? generatedAt,
  }) {
    return AiRecommendation(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      lessonId: lessonId ?? this.lessonId,
      lessonTitle: lessonTitle ?? this.lessonTitle,
      type: type ?? this.type,
      reason: reason ?? this.reason,
      suggestedAction:
          suggestedAction ?? this.suggestedAction,
      priorityScore:
          priorityScore ?? this.priorityScore,
      latestQuizScore:
          latestQuizScore ?? this.latestQuizScore,
      bestQuizScore:
          bestQuizScore ?? this.bestQuizScore,
      learningProgress:
          learningProgress ?? this.learningProgress,
      incorrectAnswers:
          incorrectAnswers ?? this.incorrectAnswers,
      quizAttempts: quizAttempts ?? this.quizAttempts,
      hasQuizResult:
          hasQuizResult ?? this.hasQuizResult,
      isLessonCompleted:
          isLessonCompleted ?? this.isLessonCompleted,
      generatedAt: generatedAt ?? this.generatedAt,
    );
  }

  /// Điểm ưu tiên được giới hạn trong khoảng 0-100.
  ///
  /// Gợi ý có điểm cao hơn sẽ được hiển thị trước.
  int get safePriorityScore {
    if (priorityScore < 0) {
      return 0;
    }

    if (priorityScore > 100) {
      return 100;
    }

    return priorityScore;
  }

  /// Điểm kiểm tra gần nhất trong khoảng 0-100.
  double get safeLatestQuizScore {
    return _clampPercentage(latestQuizScore);
  }

  /// Điểm kiểm tra cao nhất trong khoảng 0-100.
  double get safeBestQuizScore {
    return _clampPercentage(bestQuizScore);
  }

  /// Tiến độ bài học trong khoảng 0-100.
  double get safeLearningProgress {
    return _clampPercentage(learningProgress);
  }

  /// Tiến độ dùng cho LinearProgressIndicator.
  double get progressValue {
    return safeLearningProgress / 100;
  }

  /// Nhãn loại đề xuất bằng tiếng Việt.
  String get typeLabel {
    switch (type) {
      case RecommendationType.relearn:
        return 'Cần học lại';

      case RecommendationType.review:
        return 'Nên ôn tập';

      case RecommendationType.practice:
        return 'Luyện tập thêm';

      case RecommendationType.completeLesson:
        return 'Hoàn thành bài học';

      case RecommendationType.takeQuiz:
        return 'Làm bài kiểm tra';

      case RecommendationType.continueLearning:
        return 'Tiếp tục học';
    }
  }

  /// Tên biểu tượng dùng để chọn icon trong giao diện.
  String get iconName {
    switch (type) {
      case RecommendationType.relearn:
        return 'restart_alt';

      case RecommendationType.review:
        return 'history_edu';

      case RecommendationType.practice:
        return 'fitness_center';

      case RecommendationType.completeLesson:
        return 'menu_book';

      case RecommendationType.takeQuiz:
        return 'quiz';

      case RecommendationType.continueLearning:
        return 'trending_up';
    }
  }

  /// Mã màu mặc định cho từng loại đề xuất.
  int get colorValue {
    switch (type) {
      case RecommendationType.relearn:
        return 0xFFE03131;

      case RecommendationType.review:
        return 0xFFF59F00;

      case RecommendationType.practice:
        return 0xFF9C36B5;

      case RecommendationType.completeLesson:
        return 0xFF3B5BDB;

      case RecommendationType.takeQuiz:
        return 0xFF0C8599;

      case RecommendationType.continueLearning:
        return 0xFF2F9E44;
    }
  }

  /// Kiểm tra dữ liệu đề xuất có hợp lệ hay không.
  bool get isValid {
    return userId.trim().isNotEmpty &&
        lessonId.trim().isNotEmpty &&
        lessonTitle.trim().isNotEmpty &&
        reason.trim().isNotEmpty &&
        suggestedAction.trim().isNotEmpty;
  }

  /// Tạo ID cố định cho đề xuất.
  ///
  /// Mỗi người dùng chỉ có một đề xuất hiện tại
  /// cho mỗi bài học.
  static String createDocumentId({
    required String userId,
    required String lessonId,
  }) {
    return '${userId.trim()}_${lessonId.trim()}';
  }

  static RecommendationType _parseRecommendationType(
    dynamic value,
  ) {
    final String typeName =
        value?.toString().trim() ?? '';

    for (final RecommendationType type
        in RecommendationType.values) {
      if (type.name == typeName) {
        return type;
      }
    }

    return RecommendationType.continueLearning;
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

  static double _parseDouble(
    dynamic value, {
    required double defaultValue,
  }) {
    if (value is double) {
      return value;
    }

    if (value is num) {
      return value.toDouble();
    }

    if (value is String) {
      return double.tryParse(value) ?? defaultValue;
    }

    return defaultValue;
  }

  static double _clampPercentage(double value) {
    if (value < 0) {
      return 0;
    }

    if (value > 100) {
      return 100;
    }

    return value;
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

  @override
  String toString() {
    return 'AiRecommendation('
        'id: $id, '
        'lessonId: $lessonId, '
        'lessonTitle: $lessonTitle, '
        'type: ${type.name}, '
        'priorityScore: $priorityScore, '
        'latestQuizScore: $latestQuizScore, '
        'learningProgress: $learningProgress'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is AiRecommendation &&
        other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}