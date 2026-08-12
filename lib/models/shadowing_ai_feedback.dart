import 'package:cloud_firestore/cloud_firestore.dart';

/// Model đại diện cho kết quả phân tích phát âm chi tiết do "AI
/// Pronunciation Coach" đưa ra cho 1 câu shadowing.
///
/// Mỗi đối tượng ShadowingAiFeedback tương ứng với một document
/// trong collection "shadowing_ai_feedbacks" trên Firestore.
class ShadowingAiFeedback {
  final String id;
  final String userId;
  final String segmentId;
  final String overallAssessment;
  final List<String> strengths;
  final List<String> improvements;
  final List<String> practiceTips;
  final DateTime? createdAt;

  const ShadowingAiFeedback({
    required this.id,
    required this.userId,
    required this.segmentId,
    required this.overallAssessment,
    required this.strengths,
    required this.improvements,
    required this.practiceTips,
    this.createdAt,
  });

  /// Tạo đối tượng ShadowingAiFeedback từ document Firestore.
  factory ShadowingAiFeedback.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final Map<String, dynamic> data =
        document.data() ?? <String, dynamic>{};

    return ShadowingAiFeedback(
      id: document.id,
      userId: data['userId'] as String? ?? '',
      segmentId: data['segmentId'] as String? ?? '',
      overallAssessment:
          data['overallAssessment'] as String? ?? '',
      strengths: _parseStringList(data['strengths']),
      improvements: _parseStringList(data['improvements']),
      practiceTips: _parseStringList(data['practiceTips']),
      createdAt: _parseDateTime(data['createdAt']),
    );
  }

  /// Tạo đối tượng ShadowingAiFeedback từ Map.
  factory ShadowingAiFeedback.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    return ShadowingAiFeedback(
      id: id,
      userId: data['userId'] as String? ?? '',
      segmentId: data['segmentId'] as String? ?? '',
      overallAssessment:
          data['overallAssessment'] as String? ?? '',
      strengths: _parseStringList(data['strengths']),
      improvements: _parseStringList(data['improvements']),
      practiceTips: _parseStringList(data['practiceTips']),
      createdAt: _parseDateTime(data['createdAt']),
    );
  }

  /// Chuyển ShadowingAiFeedback thành Map để lưu lên Firestore.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'userId': userId.trim(),
      'segmentId': segmentId.trim(),
      'overallAssessment': overallAssessment.trim(),
      'strengths': strengths,
      'improvements': improvements,
      'practiceTips': practiceTips,
      'createdAt': createdAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(createdAt!),
    };
  }

  /// Tạo bản sao của kết quả và thay đổi một số thuộc tính.
  ShadowingAiFeedback copyWith({
    String? id,
    String? userId,
    String? segmentId,
    String? overallAssessment,
    List<String>? strengths,
    List<String>? improvements,
    List<String>? practiceTips,
    DateTime? createdAt,
  }) {
    return ShadowingAiFeedback(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      segmentId: segmentId ?? this.segmentId,
      overallAssessment:
          overallAssessment ?? this.overallAssessment,
      strengths: strengths ?? List<String>.from(this.strengths),
      improvements:
          improvements ?? List<String>.from(this.improvements),
      practiceTips:
          practiceTips ?? List<String>.from(this.practiceTips),
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Kiểm tra dữ liệu có đủ nội dung bắt buộc hay không.
  bool get isValid {
    return userId.trim().isNotEmpty && segmentId.trim().isNotEmpty;
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
    return 'ShadowingAiFeedback('
        'id: $id, '
        'userId: $userId, '
        'segmentId: $segmentId'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is ShadowingAiFeedback && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
