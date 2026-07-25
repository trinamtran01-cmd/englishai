import 'package:cloud_firestore/cloud_firestore.dart';

/// Model đại diện cho một câu hỏi trắc nghiệm.
///
/// Mỗi đối tượng QuizQuestion tương ứng với một document
/// trong collection "quiz_questions" trên Firestore.
class QuizQuestion {
  final String id;
  final String lessonId;
  final String lessonTitle;
  final String question;
  final List<String> options;
  final int correctAnswerIndex;
  final String explanation;
  final String difficulty;
  final int order;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const QuizQuestion({
    required this.id,
    required this.lessonId,
    required this.lessonTitle,
    required this.question,
    required this.options,
    required this.correctAnswerIndex,
    required this.explanation,
    required this.difficulty,
    required this.order,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  /// Tạo QuizQuestion từ document Firestore.
  factory QuizQuestion.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final Map<String, dynamic> data =
        document.data() ?? <String, dynamic>{};

    return QuizQuestion(
      id: document.id,
      lessonId: data['lessonId'] as String? ?? '',
      lessonTitle: data['lessonTitle'] as String? ?? '',
      question: data['question'] as String? ?? '',
      options: _parseOptions(data['options']),
      correctAnswerIndex: _parseInteger(
        data['correctAnswerIndex'],
        defaultValue: 0,
      ),
      explanation: data['explanation'] as String? ?? '',
      difficulty: data['difficulty'] as String? ?? 'easy',
      order: _parseInteger(
        data['order'],
        defaultValue: 0,
      ),
      isActive: data['isActive'] as bool? ?? true,
      createdAt: _parseDateTime(data['createdAt']),
      updatedAt: _parseDateTime(data['updatedAt']),
    );
  }

  /// Tạo QuizQuestion từ Map.
  factory QuizQuestion.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    return QuizQuestion(
      id: id,
      lessonId: data['lessonId'] as String? ?? '',
      lessonTitle: data['lessonTitle'] as String? ?? '',
      question: data['question'] as String? ?? '',
      options: _parseOptions(data['options']),
      correctAnswerIndex: _parseInteger(
        data['correctAnswerIndex'],
        defaultValue: 0,
      ),
      explanation: data['explanation'] as String? ?? '',
      difficulty: data['difficulty'] as String? ?? 'easy',
      order: _parseInteger(
        data['order'],
        defaultValue: 0,
      ),
      isActive: data['isActive'] as bool? ?? true,
      createdAt: _parseDateTime(data['createdAt']),
      updatedAt: _parseDateTime(data['updatedAt']),
    );
  }

  /// Chuyển câu hỏi thành Map để lưu lên Firestore.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'lessonId': lessonId.trim(),
      'lessonTitle': lessonTitle.trim(),
      'question': question.trim(),
      'options': options
          .map((String option) => option.trim())
          .toList(),
      'correctAnswerIndex': correctAnswerIndex,
      'explanation': explanation.trim(),
      'difficulty': difficulty.trim().toLowerCase(),
      'order': order,
      'isActive': isActive,
      'createdAt': createdAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(createdAt!),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Tạo một bản sao và thay đổi một số thuộc tính.
  QuizQuestion copyWith({
    String? id,
    String? lessonId,
    String? lessonTitle,
    String? question,
    List<String>? options,
    int? correctAnswerIndex,
    String? explanation,
    String? difficulty,
    int? order,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return QuizQuestion(
      id: id ?? this.id,
      lessonId: lessonId ?? this.lessonId,
      lessonTitle: lessonTitle ?? this.lessonTitle,
      question: question ?? this.question,
      options: options ?? List<String>.from(this.options),
      correctAnswerIndex:
          correctAnswerIndex ?? this.correctAnswerIndex,
      explanation: explanation ?? this.explanation,
      difficulty: difficulty ?? this.difficulty,
      order: order ?? this.order,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Kiểm tra một đáp án có đúng hay không.
  bool isCorrectAnswer(int selectedAnswerIndex) {
    return selectedAnswerIndex == correctAnswerIndex;
  }

  /// Nội dung đáp án đúng.
  String get correctAnswer {
    if (correctAnswerIndex < 0 ||
        correctAnswerIndex >= options.length) {
      return '';
    }

    return options[correctAnswerIndex];
  }

  /// Tên mức độ khó dùng để hiển thị.
  String get difficultyLabel {
    switch (difficulty.trim().toLowerCase()) {
      case 'medium':
        return 'Trung bình';

      case 'hard':
        return 'Khó';

      case 'easy':
      default:
        return 'Dễ';
    }
  }

  /// Kiểm tra dữ liệu câu hỏi có hợp lệ không.
  bool get isValid {
    if (lessonId.trim().isEmpty ||
        question.trim().isEmpty ||
        options.length < 2) {
      return false;
    }

    if (correctAnswerIndex < 0 ||
        correctAnswerIndex >= options.length) {
      return false;
    }

    return options.every(
      (String option) => option.trim().isNotEmpty,
    );
  }

  static List<String> _parseOptions(dynamic value) {
    if (value is! List) {
      return <String>[];
    }

    return value
        .map((dynamic option) => option.toString())
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
    return 'QuizQuestion('
        'id: $id, '
        'lessonId: $lessonId, '
        'question: $question, '
        'options: ${options.length}, '
        'correctAnswerIndex: $correctAnswerIndex, '
        'difficulty: $difficulty, '
        'order: $order'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is QuizQuestion && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}