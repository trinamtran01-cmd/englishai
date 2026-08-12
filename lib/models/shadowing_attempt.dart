import 'package:cloud_firestore/cloud_firestore.dart';

/// Model đại diện cho kết quả 1 lần luyện nhại câu (shadowing) của
/// người dùng cho 1 câu cụ thể.
///
/// Mỗi đối tượng ShadowingAttempt tương ứng với một document
/// trong collection "shadowing_attempts" trên Firestore.
class ShadowingAttempt {
  final String id;
  final String userId;
  final String segmentId;
  final String lessonId;
  final String transcriptFromAudio;
  final List<Map<String, dynamic>> wordResults;
  final double accuracyPercent;
  final DateTime? createdAt;

  const ShadowingAttempt({
    required this.id,
    required this.userId,
    required this.segmentId,
    required this.lessonId,
    required this.transcriptFromAudio,
    required this.wordResults,
    required this.accuracyPercent,
    this.createdAt,
  });

  /// Tạo đối tượng ShadowingAttempt từ document Firestore.
  factory ShadowingAttempt.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final Map<String, dynamic> data =
        document.data() ?? <String, dynamic>{};

    return ShadowingAttempt(
      id: document.id,
      userId: data['userId'] as String? ?? '',
      segmentId: data['segmentId'] as String? ?? '',
      lessonId: data['lessonId'] as String? ?? '',
      transcriptFromAudio:
          data['transcriptFromAudio'] as String? ?? '',
      wordResults: _parseWordResults(data['wordResults']),
      accuracyPercent: _parseDouble(data['accuracyPercent']),
      createdAt: _parseDateTime(data['createdAt']),
    );
  }

  /// Tạo đối tượng ShadowingAttempt từ Map.
  factory ShadowingAttempt.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    return ShadowingAttempt(
      id: id,
      userId: data['userId'] as String? ?? '',
      segmentId: data['segmentId'] as String? ?? '',
      lessonId: data['lessonId'] as String? ?? '',
      transcriptFromAudio:
          data['transcriptFromAudio'] as String? ?? '',
      wordResults: _parseWordResults(data['wordResults']),
      accuracyPercent: _parseDouble(data['accuracyPercent']),
      createdAt: _parseDateTime(data['createdAt']),
    );
  }

  /// Chuyển ShadowingAttempt thành Map để lưu lên Firestore.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'userId': userId.trim(),
      'segmentId': segmentId.trim(),
      'lessonId': lessonId.trim(),
      'transcriptFromAudio': transcriptFromAudio.trim(),
      'wordResults': wordResults,
      'accuracyPercent': accuracyPercent,
      'createdAt': createdAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(createdAt!),
    };
  }

  /// Tạo bản sao của kết quả và thay đổi một số thuộc tính.
  ShadowingAttempt copyWith({
    String? id,
    String? userId,
    String? segmentId,
    String? lessonId,
    String? transcriptFromAudio,
    List<Map<String, dynamic>>? wordResults,
    double? accuracyPercent,
    DateTime? createdAt,
  }) {
    return ShadowingAttempt(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      segmentId: segmentId ?? this.segmentId,
      lessonId: lessonId ?? this.lessonId,
      transcriptFromAudio:
          transcriptFromAudio ?? this.transcriptFromAudio,
      wordResults: wordResults ??
          List<Map<String, dynamic>>.from(this.wordResults),
      accuracyPercent: accuracyPercent ?? this.accuracyPercent,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Kiểm tra dữ liệu có đủ nội dung bắt buộc hay không.
  bool get isValid {
    return userId.trim().isNotEmpty &&
        segmentId.trim().isNotEmpty &&
        lessonId.trim().isNotEmpty;
  }

  /// Điểm chính xác làm tròn để hiển thị.
  int get roundedAccuracyPercent => accuracyPercent.round();

  /// Số từ đúng trong wordResults.
  int get correctWordCount {
    return wordResults.where((Map<String, dynamic> item) {
      return item['isCorrect'] == true;
    }).length;
  }

  static List<Map<String, dynamic>> _parseWordResults(
    dynamic value,
  ) {
    if (value is! List) {
      return <Map<String, dynamic>>[];
    }

    return value
        .whereType<Map<dynamic, dynamic>>()
        .map(
          (Map<dynamic, dynamic> item) => Map<String, dynamic>.from(
            item,
          ),
        )
        .toList();
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
    return 'ShadowingAttempt('
        'id: $id, '
        'userId: $userId, '
        'segmentId: $segmentId, '
        'accuracyPercent: $accuracyPercent'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is ShadowingAttempt && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
