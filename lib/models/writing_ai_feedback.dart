import 'package:cloud_firestore/cloud_firestore.dart';

/// Model đại diện cho kết quả AI chấm điểm một bài Luyện Viết.
///
/// Mỗi đối tượng WritingAiFeedback tương ứng với một document trong
/// collection "writing_ai_feedbacks" trên Firestore.
class WritingAiFeedback {
  final String id;
  final String attemptId;
  final String userId;
  final double bandOverall;
  final double bandLexicalResource;
  final double bandTaskAchievement;
  final double bandGrammaticalRange;
  final double bandCoherenceCohesion;
  final List<String> strengths;
  final List<String> priorityFixes;
  final List<String> missingParts;
  final String generalComment;
  final DateTime? createdAt;

  const WritingAiFeedback({
    required this.id,
    required this.attemptId,
    required this.userId,
    required this.bandOverall,
    required this.bandLexicalResource,
    required this.bandTaskAchievement,
    required this.bandGrammaticalRange,
    required this.bandCoherenceCohesion,
    required this.strengths,
    required this.priorityFixes,
    required this.missingParts,
    required this.generalComment,
    this.createdAt,
  });

  /// Tạo đối tượng WritingAiFeedback từ document Firestore.
  factory WritingAiFeedback.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final Map<String, dynamic> data =
        document.data() ?? <String, dynamic>{};

    return WritingAiFeedback(
      id: document.id,
      attemptId: data['attemptId'] as String? ?? '',
      userId: data['userId'] as String? ?? '',
      bandOverall: _parseBand(data['bandOverall']),
      bandLexicalResource: _parseBand(data['bandLexicalResource']),
      bandTaskAchievement: _parseBand(data['bandTaskAchievement']),
      bandGrammaticalRange: _parseBand(data['bandGrammaticalRange']),
      bandCoherenceCohesion: _parseBand(data['bandCoherenceCohesion']),
      strengths: _parseStringList(data['strengths']),
      priorityFixes: _parseStringList(data['priorityFixes']),
      missingParts: _parseStringList(data['missingParts']),
      generalComment: data['generalComment'] as String? ?? '',
      createdAt: _parseDateTime(data['createdAt']),
    );
  }

  /// Tạo đối tượng WritingAiFeedback từ Map.
  factory WritingAiFeedback.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    return WritingAiFeedback(
      id: id,
      attemptId: data['attemptId'] as String? ?? '',
      userId: data['userId'] as String? ?? '',
      bandOverall: _parseBand(data['bandOverall']),
      bandLexicalResource: _parseBand(data['bandLexicalResource']),
      bandTaskAchievement: _parseBand(data['bandTaskAchievement']),
      bandGrammaticalRange: _parseBand(data['bandGrammaticalRange']),
      bandCoherenceCohesion: _parseBand(data['bandCoherenceCohesion']),
      strengths: _parseStringList(data['strengths']),
      priorityFixes: _parseStringList(data['priorityFixes']),
      missingParts: _parseStringList(data['missingParts']),
      generalComment: data['generalComment'] as String? ?? '',
      createdAt: _parseDateTime(data['createdAt']),
    );
  }

  /// Chuyển WritingAiFeedback thành Map để lưu lên Firestore.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'attemptId': attemptId.trim(),
      'userId': userId.trim(),
      'bandOverall': bandOverall,
      'bandLexicalResource': bandLexicalResource,
      'bandTaskAchievement': bandTaskAchievement,
      'bandGrammaticalRange': bandGrammaticalRange,
      'bandCoherenceCohesion': bandCoherenceCohesion,
      'strengths': strengths,
      'priorityFixes': priorityFixes,
      'missingParts': missingParts,
      'generalComment': generalComment.trim(),
      'createdAt': createdAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(createdAt!),
    };
  }

  /// Tạo bản sao của kết quả chấm điểm và thay đổi một số thuộc tính.
  WritingAiFeedback copyWith({
    String? id,
    String? attemptId,
    String? userId,
    double? bandOverall,
    double? bandLexicalResource,
    double? bandTaskAchievement,
    double? bandGrammaticalRange,
    double? bandCoherenceCohesion,
    List<String>? strengths,
    List<String>? priorityFixes,
    List<String>? missingParts,
    String? generalComment,
    DateTime? createdAt,
  }) {
    return WritingAiFeedback(
      id: id ?? this.id,
      attemptId: attemptId ?? this.attemptId,
      userId: userId ?? this.userId,
      bandOverall: bandOverall ?? this.bandOverall,
      bandLexicalResource:
          bandLexicalResource ?? this.bandLexicalResource,
      bandTaskAchievement:
          bandTaskAchievement ?? this.bandTaskAchievement,
      bandGrammaticalRange:
          bandGrammaticalRange ?? this.bandGrammaticalRange,
      bandCoherenceCohesion:
          bandCoherenceCohesion ?? this.bandCoherenceCohesion,
      strengths: strengths ?? List<String>.from(this.strengths),
      priorityFixes:
          priorityFixes ?? List<String>.from(this.priorityFixes),
      missingParts:
          missingParts ?? List<String>.from(this.missingParts),
      generalComment: generalComment ?? this.generalComment,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Kiểm tra dữ liệu có đủ nội dung bắt buộc hay không.
  bool get isValid {
    return attemptId.trim().isNotEmpty &&
        userId.trim().isNotEmpty &&
        bandOverall > 0;
  }

  /// Ép giá trị band về đúng thang điểm IELTS 0.0 - 9.0.
  static double _parseBand(dynamic value) {
    double band;

    if (value is num) {
      band = value.toDouble();
    } else {
      band = 0;
    }

    if (band < 0) {
      return 0;
    }

    if (band > 9) {
      return 9;
    }

    return band;
  }

  static List<String> _parseStringList(dynamic value) {
    if (value is! List) {
      return <String>[];
    }

    return value.map((dynamic item) => item.toString()).toList();
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
    return 'WritingAiFeedback('
        'id: $id, '
        'attemptId: $attemptId, '
        'bandOverall: $bandOverall'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is WritingAiFeedback && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
