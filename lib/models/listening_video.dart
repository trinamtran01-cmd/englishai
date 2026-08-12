import 'package:cloud_firestore/cloud_firestore.dart';

/// Model đại diện cho một bài luyện nghe & nói bằng video YouTube.
///
/// Mỗi đối tượng ListeningVideo tương ứng với một document
/// trong collection "listening_videos" trên Firestore.
class ListeningVideo {
  final String id;
  final String title;
  final String youtubeVideoId;
  final String description;
  final List<String> transcriptWords;
  final String speakingPrompt;
  final String level;
  final DateTime? createdAt;

  const ListeningVideo({
    required this.id,
    required this.title,
    required this.youtubeVideoId,
    required this.description,
    required this.transcriptWords,
    required this.speakingPrompt,
    required this.level,
    this.createdAt,
  });

  /// Tạo đối tượng ListeningVideo từ document Firestore.
  factory ListeningVideo.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final Map<String, dynamic> data =
        document.data() ?? <String, dynamic>{};

    return ListeningVideo(
      id: document.id,
      title: data['title'] as String? ?? '',
      youtubeVideoId: data['youtubeVideoId'] as String? ?? '',
      description: data['description'] as String? ?? '',
      transcriptWords: _parseTranscriptWords(
        data['transcriptWords'],
      ),
      speakingPrompt: data['speakingPrompt'] as String? ?? '',
      level: data['level'] as String? ?? 'beginner',
      createdAt: _parseDateTime(data['createdAt']),
    );
  }

  /// Tạo đối tượng ListeningVideo từ Map.
  factory ListeningVideo.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    return ListeningVideo(
      id: id,
      title: data['title'] as String? ?? '',
      youtubeVideoId: data['youtubeVideoId'] as String? ?? '',
      description: data['description'] as String? ?? '',
      transcriptWords: _parseTranscriptWords(
        data['transcriptWords'],
      ),
      speakingPrompt: data['speakingPrompt'] as String? ?? '',
      level: data['level'] as String? ?? 'beginner',
      createdAt: _parseDateTime(data['createdAt']),
    );
  }

  /// Chuyển ListeningVideo thành Map để lưu lên Firestore.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'title': title.trim(),
      'youtubeVideoId': youtubeVideoId.trim(),
      'description': description.trim(),
      'transcriptWords': transcriptWords,
      'speakingPrompt': speakingPrompt.trim(),
      'level': level.trim().toLowerCase(),
      'createdAt': createdAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(createdAt!),
    };
  }

  /// Tạo bản sao của bài luyện nghe và thay đổi một số thuộc tính.
  ListeningVideo copyWith({
    String? id,
    String? title,
    String? youtubeVideoId,
    String? description,
    List<String>? transcriptWords,
    String? speakingPrompt,
    String? level,
    DateTime? createdAt,
  }) {
    return ListeningVideo(
      id: id ?? this.id,
      title: title ?? this.title,
      youtubeVideoId: youtubeVideoId ?? this.youtubeVideoId,
      description: description ?? this.description,
      transcriptWords: transcriptWords ??
          List<String>.from(this.transcriptWords),
      speakingPrompt: speakingPrompt ?? this.speakingPrompt,
      level: level ?? this.level,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Kiểm tra dữ liệu bài luyện nghe có đủ nội dung bắt buộc hay không.
  bool get isValid {
    return title.trim().isNotEmpty &&
        youtubeVideoId.trim().isNotEmpty;
  }

  /// Tên mức độ dùng để hiển thị.
  String get levelLabel {
    switch (level.trim().toLowerCase()) {
      case 'intermediate':
        return 'Trung cấp';

      case 'advanced':
        return 'Nâng cao';

      case 'beginner':
      default:
        return 'Cơ bản';
    }
  }

  /// URL ảnh thumbnail của video YouTube.
  String get thumbnailUrl {
    if (youtubeVideoId.trim().isEmpty) {
      return '';
    }

    return 'https://img.youtube.com/vi/'
        '${youtubeVideoId.trim()}/hqdefault.jpg';
  }

  /// Chuẩn hóa một đoạn transcript tự do thành danh sách từ.
  ///
  /// Tách theo khoảng trắng, loại bỏ dấu câu, chuyển về lowercase.
  static List<String> parseTranscriptText(String rawText) {
    final Iterable<String> matches = RegExp(r"[a-zA-Z']+")
        .allMatches(rawText)
        .map((RegExpMatch match) => match.group(0) ?? '');

    return matches
        .map((String word) => word.trim().toLowerCase())
        .where((String word) => word.isNotEmpty)
        .toList();
  }

  static List<String> _parseTranscriptWords(dynamic value) {
    if (value is! List) {
      return <String>[];
    }

    return value
        .map((dynamic word) => word.toString().toLowerCase())
        .toList();
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
    return 'ListeningVideo('
        'id: $id, '
        'title: $title, '
        'youtubeVideoId: $youtubeVideoId, '
        'level: $level, '
        'transcriptWords: ${transcriptWords.length}'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is ListeningVideo && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
