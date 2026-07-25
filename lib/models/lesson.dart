import 'package:cloud_firestore/cloud_firestore.dart';

/// Model đại diện cho một bài học tiếng Anh.
///
/// Mỗi đối tượng Lesson tương ứng với một document
/// trong collection "lessons" trên Firestore.
class Lesson {
  final String id;
  final String title;
  final String topic;
  final String description;
  final String icon;
  final int color;
  final int order;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Lesson({
    required this.id,
    required this.title,
    required this.topic,
    required this.description,
    required this.icon,
    required this.color,
    required this.order,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  /// Tạo đối tượng Lesson từ document Firestore.
  factory Lesson.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final Map<String, dynamic> data =
        document.data() ?? <String, dynamic>{};

    return Lesson(
      id: document.id,
      title: data['title'] as String? ?? '',
      topic: data['topic'] as String? ?? '',
      description: data['description'] as String? ?? '',
      icon: data['icon'] as String? ?? 'menu_book',
      color: _parseInteger(
        data['color'],
        defaultValue: 0xFF3B5BDB,
      ),
      order: _parseInteger(
        data['order'],
        defaultValue: 0,
      ),
      isActive: data['isActive'] as bool? ?? true,
      createdAt: _parseDateTime(data['createdAt']),
      updatedAt: _parseDateTime(data['updatedAt']),
    );
  }

  /// Tạo đối tượng Lesson từ Map.
  ///
  /// Có thể sử dụng khi dữ liệu không được lấy trực tiếp
  /// từ DocumentSnapshot của Firestore.
  factory Lesson.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    return Lesson(
      id: id,
      title: data['title'] as String? ?? '',
      topic: data['topic'] as String? ?? '',
      description: data['description'] as String? ?? '',
      icon: data['icon'] as String? ?? 'menu_book',
      color: _parseInteger(
        data['color'],
        defaultValue: 0xFF3B5BDB,
      ),
      order: _parseInteger(
        data['order'],
        defaultValue: 0,
      ),
      isActive: data['isActive'] as bool? ?? true,
      createdAt: _parseDateTime(data['createdAt']),
      updatedAt: _parseDateTime(data['updatedAt']),
    );
  }

  /// Chuyển Lesson thành Map để lưu lên Firestore.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'title': title.trim(),
      'topic': topic.trim(),
      'description': description.trim(),
      'icon': icon,
      'color': color,
      'order': order,
      'isActive': isActive,
      'createdAt': createdAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(createdAt!),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Tạo bản sao của bài học và thay đổi một số thuộc tính.
  Lesson copyWith({
    String? id,
    String? title,
    String? topic,
    String? description,
    String? icon,
    int? color,
    int? order,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Lesson(
      id: id ?? this.id,
      title: title ?? this.title,
      topic: topic ?? this.topic,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      order: order ?? this.order,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Chuyển dữ liệu số từ Firestore thành int an toàn.
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
    return 'Lesson('
        'id: $id, '
        'title: $title, '
        'topic: $topic, '
        'order: $order, '
        'isActive: $isActive'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is Lesson && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}