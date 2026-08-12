import 'package:cloud_firestore/cloud_firestore.dart';

/// Model đại diện cho kết quả bước nghe & điền từ của một người dùng.
///
/// Mỗi đối tượng ListeningAttempt tương ứng với một document
/// trong collection "listening_attempts" trên Firestore.
class ListeningAttempt {
  final String id;
  final String userId;
  final String videoId;
  final List<String> typedWords;
  final int correctCount;
  final int incorrectCount;
  final double score;
  final DateTime? createdAt;

  const ListeningAttempt({
    required this.id,
    required this.userId,
    required this.videoId,
    required this.typedWords,
    required this.correctCount,
    required this.incorrectCount,
    required this.score,
    this.createdAt,
  });

  /// Tạo đối tượng ListeningAttempt từ document Firestore.
  factory ListeningAttempt.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final Map<String, dynamic> data =
        document.data() ?? <String, dynamic>{};

    return ListeningAttempt(
      id: document.id,
      userId: data['userId'] as String? ?? '',
      videoId: data['videoId'] as String? ?? '',
      typedWords: _parseStringList(data['typedWords']),
      correctCount: _parseInteger(
        data['correctCount'],
        defaultValue: 0,
      ),
      incorrectCount: _parseInteger(
        data['incorrectCount'],
        defaultValue: 0,
      ),
      score: _parseDouble(data['score']),
      createdAt: _parseDateTime(data['createdAt']),
    );
  }

  /// Tạo đối tượng ListeningAttempt từ Map.
  factory ListeningAttempt.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    return ListeningAttempt(
      id: id,
      userId: data['userId'] as String? ?? '',
      videoId: data['videoId'] as String? ?? '',
      typedWords: _parseStringList(data['typedWords']),
      correctCount: _parseInteger(
        data['correctCount'],
        defaultValue: 0,
      ),
      incorrectCount: _parseInteger(
        data['incorrectCount'],
        defaultValue: 0,
      ),
      score: _parseDouble(data['score']),
      createdAt: _parseDateTime(data['createdAt']),
    );
  }

  /// Chuyển ListeningAttempt thành Map để lưu lên Firestore.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'userId': userId.trim(),
      'videoId': videoId.trim(),
      'typedWords': typedWords,
      'correctCount': correctCount,
      'incorrectCount': incorrectCount,
      'score': score,
      'createdAt': createdAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(createdAt!),
    };
  }

  /// Tạo bản sao của kết quả và thay đổi một số thuộc tính.
  ListeningAttempt copyWith({
    String? id,
    String? userId,
    String? videoId,
    List<String>? typedWords,
    int? correctCount,
    int? incorrectCount,
    double? score,
    DateTime? createdAt,
  }) {
    return ListeningAttempt(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      videoId: videoId ?? this.videoId,
      typedWords:
          typedWords ?? List<String>.from(this.typedWords),
      correctCount: correctCount ?? this.correctCount,
      incorrectCount: incorrectCount ?? this.incorrectCount,
      score: score ?? this.score,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Kiểm tra dữ liệu có đủ nội dung bắt buộc hay không.
  bool get isValid {
    return userId.trim().isNotEmpty && videoId.trim().isNotEmpty;
  }

  /// Điểm số làm tròn để hiển thị.
  int get roundedScore => score.round();

  static List<String> _parseStringList(dynamic value) {
    if (value is! List) {
      return <String>[];
    }

    return value.map((dynamic word) => word.toString()).toList();
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

  static double _parseDouble(dynamic value) {
    if (value is double) {
      return value;
    }

    if (value is num) {
      return value.toDouble();
    }

    if (value is String) {
      return double.tryParse(value) ?? 0;
    }

    return 0;
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
    return 'ListeningAttempt('
        'id: $id, '
        'userId: $userId, '
        'videoId: $videoId, '
        'correctCount: $correctCount, '
        'incorrectCount: $incorrectCount, '
        'score: $score'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is ListeningAttempt && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
