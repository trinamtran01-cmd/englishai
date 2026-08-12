import 'package:cloud_firestore/cloud_firestore.dart';

/// Model đại diện cho một câu (segment) trong bài luyện Shadowing.
///
/// Mỗi đối tượng ShadowingSegment tương ứng với một document
/// trong collection "shadowing_segments" trên Firestore.
class ShadowingSegment {
  final String id;
  final String lessonId;
  final int order;
  final String text;
  final String ipaPronunciation;
  final String vietnameseTranslation;

  const ShadowingSegment({
    required this.id,
    required this.lessonId,
    required this.order,
    required this.text,
    required this.ipaPronunciation,
    this.vietnameseTranslation = '',
  });

  /// Tạo đối tượng ShadowingSegment từ document Firestore.
  factory ShadowingSegment.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final Map<String, dynamic> data =
        document.data() ?? <String, dynamic>{};

    return ShadowingSegment(
      id: document.id,
      lessonId: data['lessonId'] as String? ?? '',
      order: _parseInteger(data['order'], defaultValue: 0),
      text: _collapseWhitespace(data['text'] as String? ?? ''),
      ipaPronunciation: _collapseWhitespace(
        data['ipaPronunciation'] as String? ?? '',
      ),
      vietnameseTranslation: _collapseWhitespace(
        data['vietnameseTranslation'] as String? ?? '',
      ),
    );
  }

  /// Tạo đối tượng ShadowingSegment từ Map.
  factory ShadowingSegment.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    return ShadowingSegment(
      id: id,
      lessonId: data['lessonId'] as String? ?? '',
      order: _parseInteger(data['order'], defaultValue: 0),
      text: _collapseWhitespace(data['text'] as String? ?? ''),
      ipaPronunciation: _collapseWhitespace(
        data['ipaPronunciation'] as String? ?? '',
      ),
      vietnameseTranslation: _collapseWhitespace(
        data['vietnameseTranslation'] as String? ?? '',
      ),
    );
  }

  /// Chuyển ShadowingSegment thành Map để lưu lên Firestore.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'lessonId': lessonId.trim(),
      'order': order,
      'text': _collapseWhitespace(text),
      'ipaPronunciation': _collapseWhitespace(ipaPronunciation),
      'vietnameseTranslation': _collapseWhitespace(
        vietnameseTranslation,
      ),
    };
  }

  /// Tạo bản sao của câu và thay đổi một số thuộc tính.
  ShadowingSegment copyWith({
    String? id,
    String? lessonId,
    int? order,
    String? text,
    String? ipaPronunciation,
    String? vietnameseTranslation,
  }) {
    return ShadowingSegment(
      id: id ?? this.id,
      lessonId: lessonId ?? this.lessonId,
      order: order ?? this.order,
      text: text ?? this.text,
      ipaPronunciation:
          ipaPronunciation ?? this.ipaPronunciation,
      vietnameseTranslation:
          vietnameseTranslation ?? this.vietnameseTranslation,
    );
  }

  /// Kiểm tra dữ liệu câu có đủ nội dung bắt buộc hay không.
  bool get isValid {
    return lessonId.trim().isNotEmpty && text.trim().isNotEmpty;
  }

  /// Gộp mọi khoảng trắng liên tiếp (bao gồm xuống dòng `\n`, tab...)
  /// thành 1 dấu cách, để câu luôn hiển thị như văn bản liền mạch.
  ///
  /// Xử lý ngay khi đọc từ Firestore để tự sửa cả dữ liệu cũ lỡ bị
  /// lưu với ký tự xuống dòng (ví dụ dán từ nguồn có line-break),
  /// không chỉ dữ liệu mới lưu sau khi có fix này.
  static String _collapseWhitespace(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
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

  @override
  String toString() {
    return 'ShadowingSegment('
        'id: $id, '
        'lessonId: $lessonId, '
        'order: $order, '
        'text: $text'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is ShadowingSegment && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
