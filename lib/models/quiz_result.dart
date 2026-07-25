import 'package:cloud_firestore/cloud_firestore.dart';

/// Model lưu kết quả một lần làm bài kiểm tra.
///
/// Mỗi QuizResult tương ứng với một document
/// trong collection "quiz_results" trên Firestore.
class QuizResult {
  final String id;
  final String userId;
  final String lessonId;
  final String lessonTitle;
  final int totalQuestions;
  final int correctAnswers;
  final int incorrectAnswers;
  final double scorePercentage;
  final bool isPassed;
  final int attemptNumber;
  final Map<String, int> selectedAnswers;
  final List<String> incorrectQuestionIds;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const QuizResult({
    required this.id,
    required this.userId,
    required this.lessonId,
    required this.lessonTitle,
    required this.totalQuestions,
    required this.correctAnswers,
    required this.incorrectAnswers,
    required this.scorePercentage,
    required this.isPassed,
    required this.attemptNumber,
    required this.selectedAnswers,
    required this.incorrectQuestionIds,
    this.startedAt,
    this.completedAt,
    this.createdAt,
    this.updatedAt,
  });

  /// Tạo QuizResult từ document Firestore.
  factory QuizResult.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final Map<String, dynamic> data =
        document.data() ?? <String, dynamic>{};

    final int totalQuestions = _parseInteger(
      data['totalQuestions'],
      defaultValue: 0,
    );

    final int correctAnswers = _parseInteger(
      data['correctAnswers'],
      defaultValue: 0,
    );

    final int incorrectAnswers = _parseInteger(
      data['incorrectAnswers'],
      defaultValue:
          totalQuestions > correctAnswers
              ? totalQuestions - correctAnswers
              : 0,
    );

    return QuizResult(
      id: document.id,
      userId: data['userId'] as String? ?? '',
      lessonId: data['lessonId'] as String? ?? '',
      lessonTitle:
          data['lessonTitle'] as String? ?? '',
      totalQuestions: totalQuestions,
      correctAnswers: correctAnswers,
      incorrectAnswers: incorrectAnswers,
      scorePercentage: _parsePercentage(
        data['scorePercentage'],
        correctAnswers: correctAnswers,
        totalQuestions: totalQuestions,
      ),
      isPassed: data['isPassed'] as bool? ?? false,
      attemptNumber: _parseInteger(
        data['attemptNumber'],
        defaultValue: 1,
      ),
      selectedAnswers: _parseSelectedAnswers(
        data['selectedAnswers'],
      ),
      incorrectQuestionIds: _parseStringList(
        data['incorrectQuestionIds'],
      ),
      startedAt: _parseDateTime(
        data['startedAt'],
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

  /// Tạo QuizResult từ Map.
  factory QuizResult.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    final int totalQuestions = _parseInteger(
      data['totalQuestions'],
      defaultValue: 0,
    );

    final int correctAnswers = _parseInteger(
      data['correctAnswers'],
      defaultValue: 0,
    );

    final int incorrectAnswers = _parseInteger(
      data['incorrectAnswers'],
      defaultValue:
          totalQuestions > correctAnswers
              ? totalQuestions - correctAnswers
              : 0,
    );

    return QuizResult(
      id: id,
      userId: data['userId'] as String? ?? '',
      lessonId: data['lessonId'] as String? ?? '',
      lessonTitle:
          data['lessonTitle'] as String? ?? '',
      totalQuestions: totalQuestions,
      correctAnswers: correctAnswers,
      incorrectAnswers: incorrectAnswers,
      scorePercentage: _parsePercentage(
        data['scorePercentage'],
        correctAnswers: correctAnswers,
        totalQuestions: totalQuestions,
      ),
      isPassed: data['isPassed'] as bool? ?? false,
      attemptNumber: _parseInteger(
        data['attemptNumber'],
        defaultValue: 1,
      ),
      selectedAnswers: _parseSelectedAnswers(
        data['selectedAnswers'],
      ),
      incorrectQuestionIds: _parseStringList(
        data['incorrectQuestionIds'],
      ),
      startedAt: _parseDateTime(
        data['startedAt'],
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

  /// Chuyển kết quả kiểm tra thành Map để lưu vào Firestore.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'userId': userId.trim(),
      'lessonId': lessonId.trim(),
      'lessonTitle': lessonTitle.trim(),
      'totalQuestions': totalQuestions,
      'correctAnswers': correctAnswers,
      'incorrectAnswers': incorrectAnswers,
      'scorePercentage': safeScorePercentage,
      'isPassed': isPassed,
      'attemptNumber': attemptNumber,
      'selectedAnswers': selectedAnswers,
      'incorrectQuestionIds': incorrectQuestionIds,
      'startedAt': _dateTimeToTimestamp(startedAt),
      'completedAt':
          _dateTimeToTimestamp(completedAt),
      'createdAt': createdAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(createdAt!),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Tạo bản sao của kết quả và thay đổi một số thuộc tính.
  QuizResult copyWith({
    String? id,
    String? userId,
    String? lessonId,
    String? lessonTitle,
    int? totalQuestions,
    int? correctAnswers,
    int? incorrectAnswers,
    double? scorePercentage,
    bool? isPassed,
    int? attemptNumber,
    Map<String, int>? selectedAnswers,
    List<String>? incorrectQuestionIds,
    DateTime? startedAt,
    DateTime? completedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return QuizResult(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      lessonId: lessonId ?? this.lessonId,
      lessonTitle:
          lessonTitle ?? this.lessonTitle,
      totalQuestions:
          totalQuestions ?? this.totalQuestions,
      correctAnswers:
          correctAnswers ?? this.correctAnswers,
      incorrectAnswers:
          incorrectAnswers ?? this.incorrectAnswers,
      scorePercentage:
          scorePercentage ?? this.scorePercentage,
      isPassed: isPassed ?? this.isPassed,
      attemptNumber:
          attemptNumber ?? this.attemptNumber,
      selectedAnswers: selectedAnswers ??
          Map<String, int>.from(
            this.selectedAnswers,
          ),
      incorrectQuestionIds:
          incorrectQuestionIds ??
              List<String>.from(
                this.incorrectQuestionIds,
              ),
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Điểm số được giới hạn trong khoảng từ 0 đến 100.
  double get safeScorePercentage {
    if (scorePercentage < 0) {
      return 0;
    }

    if (scorePercentage > 100) {
      return 100;
    }

    return scorePercentage;
  }

  /// Điểm đã làm tròn dùng để hiển thị.
  int get roundedScore {
    return safeScorePercentage.round();
  }

  /// Số câu đúng không vượt quá tổng số câu.
  int get safeCorrectAnswers {
    if (correctAnswers < 0) {
      return 0;
    }

    if (totalQuestions > 0 &&
        correctAnswers > totalQuestions) {
      return totalQuestions;
    }

    return correctAnswers;
  }

  /// Số câu sai không vượt quá tổng số câu.
  int get safeIncorrectAnswers {
    if (incorrectAnswers < 0) {
      return 0;
    }

    if (totalQuestions > 0 &&
        incorrectAnswers > totalQuestions) {
      return totalQuestions;
    }

    return incorrectAnswers;
  }

  /// Số câu chưa trả lời.
  int get unansweredQuestions {
    final int answeredQuestions =
        selectedAnswers.length;

    if (answeredQuestions >= totalQuestions) {
      return 0;
    }

    return totalQuestions - answeredQuestions;
  }

  /// Nhãn đánh giá kết quả.
  String get resultLabel {
    if (safeScorePercentage >= 90) {
      return 'Xuất sắc';
    }

    if (safeScorePercentage >= 80) {
      return 'Rất tốt';
    }

    if (safeScorePercentage >= 70) {
      return 'Tốt';
    }

    if (safeScorePercentage >= 50) {
      return 'Đạt';
    }

    return 'Cần cố gắng thêm';
  }

  /// Kiểm tra dữ liệu kết quả có hợp lệ hay không.
  bool get isValid {
    return userId.trim().isNotEmpty &&
        lessonId.trim().isNotEmpty &&
        totalQuestions > 0 &&
        correctAnswers >= 0 &&
        incorrectAnswers >= 0 &&
        correctAnswers <= totalQuestions &&
        incorrectAnswers <= totalQuestions;
  }

  /// Tính phần trăm điểm dựa trên số câu đúng.
  static double calculateScorePercentage({
    required int correctAnswers,
    required int totalQuestions,
  }) {
    if (totalQuestions <= 0 ||
        correctAnswers <= 0) {
      return 0;
    }

    final int safeCorrectAnswers =
        correctAnswers > totalQuestions
            ? totalQuestions
            : correctAnswers;

    return (safeCorrectAnswers / totalQuestions) * 100;
  }

  /// Kiểm tra người dùng có đạt bài kiểm tra hay không.
  ///
  /// Mặc định cần đạt từ 50% trở lên.
  static bool calculateIsPassed({
    required double scorePercentage,
    double passingScore = 50,
  }) {
    return scorePercentage >= passingScore;
  }

  static Map<String, int> _parseSelectedAnswers(
    dynamic value,
  ) {
    if (value is! Map) {
      return <String, int>{};
    }

    final Map<String, int> result =
        <String, int>{};

    value.forEach(
      (dynamic key, dynamic answerIndex) {
        final String questionId =
            key.toString();

        if (answerIndex is int) {
          result[questionId] = answerIndex;
        } else if (answerIndex is num) {
          result[questionId] =
              answerIndex.toInt();
        } else if (answerIndex is String) {
          final int? parsedIndex =
              int.tryParse(answerIndex);

          if (parsedIndex != null) {
            result[questionId] = parsedIndex;
          }
        }
      },
    );

    return result;
  }

  static List<String> _parseStringList(
    dynamic value,
  ) {
    if (value is! List) {
      return <String>[];
    }

    return value
        .map((dynamic item) => item.toString())
        .toList();
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
    required int correctAnswers,
    required int totalQuestions,
  }) {
    double percentage;

    if (value is num) {
      percentage = value.toDouble();
    } else if (value is String) {
      percentage = double.tryParse(value) ??
          calculateScorePercentage(
            correctAnswers: correctAnswers,
            totalQuestions: totalQuestions,
          );
    } else {
      percentage = calculateScorePercentage(
        correctAnswers: correctAnswers,
        totalQuestions: totalQuestions,
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

  static DateTime? _parseDateTime(
    dynamic value,
  ) {
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
    return 'QuizResult('
        'id: $id, '
        'userId: $userId, '
        'lessonId: $lessonId, '
        'lessonTitle: $lessonTitle, '
        'correctAnswers: $correctAnswers/$totalQuestions, '
        'scorePercentage: $scorePercentage, '
        'isPassed: $isPassed, '
        'attemptNumber: $attemptNumber'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is QuizResult && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}