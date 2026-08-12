import 'package:cloud_firestore/cloud_firestore.dart';

/// Model đại diện cho kết quả phân tích giọng nói do AI đưa ra.
///
/// Mỗi đối tượng SpeakingFeedback tương ứng với một document
/// trong collection "speaking_feedbacks" trên Firestore.
class SpeakingFeedback {
  final String id;
  final String userId;
  final String videoId;
  final String transcriptFromAudio;
  final String overallFeedback;
  final List<String> pronunciationIssues;
  final int pronunciationScore;
  final DateTime? createdAt;

  const SpeakingFeedback({
    required this.id,
    required this.userId,
    required this.videoId,
    required this.transcriptFromAudio,
    required this.overallFeedback,
    required this.pronunciationIssues,
    required this.pronunciationScore,
    this.createdAt,
  });

  /// Tạo đối tượng SpeakingFeedback từ document Firestore.
  factory SpeakingFeedback.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final Map<String, dynamic> data =
        document.data() ?? <String, dynamic>{};

    return SpeakingFeedback(
      id: document.id,
      userId: data['userId'] as String? ?? '',
      videoId: data['videoId'] as String? ?? '',
      transcriptFromAudio:
          data['transcriptFromAudio'] as String? ?? '',
      overallFeedback: data['overallFeedback'] as String? ?? '',
      pronunciationIssues: _parseStringList(
        data['pronunciationIssues'],
      ),
      pronunciationScore: _parseInteger(
        data['pronunciationScore'],
        defaultValue: 0,
      ),
      createdAt: _parseDateTime(data['createdAt']),
    );
  }

  /// Tạo đối tượng SpeakingFeedback từ Map.
  factory SpeakingFeedback.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    return SpeakingFeedback(
      id: id,
      userId: data['userId'] as String? ?? '',
      videoId: data['videoId'] as String? ?? '',
      transcriptFromAudio:
          data['transcriptFromAudio'] as String? ?? '',
      overallFeedback: data['overallFeedback'] as String? ?? '',
      pronunciationIssues: _parseStringList(
        data['pronunciationIssues'],
      ),
      pronunciationScore: _parseInteger(
        data['pronunciationScore'],
        defaultValue: 0,
      ),
      createdAt: _parseDateTime(data['createdAt']),
    );
  }

  /// Chuyển SpeakingFeedback thành Map để lưu lên Firestore.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'userId': userId.trim(),
      'videoId': videoId.trim(),
      'transcriptFromAudio': transcriptFromAudio.trim(),
      'overallFeedback': overallFeedback.trim(),
      'pronunciationIssues': pronunciationIssues,
      'pronunciationScore': pronunciationScore,
      'createdAt': createdAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(createdAt!),
    };
  }

  /// Tạo bản sao của kết quả và thay đổi một số thuộc tính.
  SpeakingFeedback copyWith({
    String? id,
    String? userId,
    String? videoId,
    String? transcriptFromAudio,
    String? overallFeedback,
    List<String>? pronunciationIssues,
    int? pronunciationScore,
    DateTime? createdAt,
  }) {
    return SpeakingFeedback(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      videoId: videoId ?? this.videoId,
      transcriptFromAudio:
          transcriptFromAudio ?? this.transcriptFromAudio,
      overallFeedback: overallFeedback ?? this.overallFeedback,
      pronunciationIssues: pronunciationIssues ??
          List<String>.from(this.pronunciationIssues),
      pronunciationScore:
          pronunciationScore ?? this.pronunciationScore,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Kiểm tra dữ liệu có đủ nội dung bắt buộc hay không.
  bool get isValid {
    return userId.trim().isNotEmpty && videoId.trim().isNotEmpty;
  }

  static List<String> _parseStringList(dynamic value) {
    if (value is! List) {
      return <String>[];
    }

    return value.map((dynamic item) => item.toString()).toList();
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
    return 'SpeakingFeedback('
        'id: $id, '
        'userId: $userId, '
        'videoId: $videoId, '
        'pronunciationScore: $pronunciationScore'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is SpeakingFeedback && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
