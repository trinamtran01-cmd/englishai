import 'package:cloud_firestore/cloud_firestore.dart';

/// Model đại diện cho một bài luyện Shadowing (nghe & nhại lại câu).
///
/// Mỗi đối tượng ShadowingLesson tương ứng với một document
/// trong collection "shadowing_lessons" trên Firestore.
class ShadowingLesson {
  final String id;
  final String title;
  final String description;
  final String level;
  final DateTime? createdAt;

  const ShadowingLesson({
    required this.id,
    required this.title,
    required this.description,
    required this.level,
    this.createdAt,
  });

  /// Tạo đối tượng ShadowingLesson từ document Firestore.
  factory ShadowingLesson.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final Map<String, dynamic> data =
        document.data() ?? <String, dynamic>{};

    return ShadowingLesson(
      id: document.id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      level: data['level'] as String? ?? 'beginner',
      createdAt: _parseDateTime(data['createdAt']),
    );
  }

  /// Tạo đối tượng ShadowingLesson từ Map.
  factory ShadowingLesson.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    return ShadowingLesson(
      id: id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      level: data['level'] as String? ?? 'beginner',
      createdAt: _parseDateTime(data['createdAt']),
    );
  }

  /// Chuyển ShadowingLesson thành Map để lưu lên Firestore.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'title': title.trim(),
      'description': description.trim(),
      'level': level.trim().toLowerCase(),
      'createdAt': createdAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(createdAt!),
    };
  }

  /// Tạo bản sao của bài luyện Shadowing và thay đổi một số thuộc tính.
  ShadowingLesson copyWith({
    String? id,
    String? title,
    String? description,
    String? level,
    DateTime? createdAt,
  }) {
    return ShadowingLesson(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      level: level ?? this.level,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Kiểm tra dữ liệu bài luyện Shadowing có đủ nội dung bắt buộc hay không.
  bool get isValid {
    return title.trim().isNotEmpty;
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
    return 'ShadowingLesson('
        'id: $id, '
        'title: $title, '
        'level: $level'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is ShadowingLesson && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
