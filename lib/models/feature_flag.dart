import 'package:cloud_firestore/cloud_firestore.dart';

/// Model đại diện cho trạng thái bật/tắt tạm thời của 1 tính năng
/// trên trang chủ (dùng để Admin khóa tạm 1 tính năng đang sửa lỗi).
///
/// Mỗi đối tượng FeatureFlag tương ứng với một document trong
/// collection "feature_flags" trên Firestore, document id chính là
/// [id] (key của tính năng, ví dụ 'shadowing').
class FeatureFlag {
  final String id;
  final String label;
  final bool isEnabled;
  final String disabledMessage;
  final DateTime? updatedAt;

  static const String defaultDisabledMessage =
      'Tính năng đang trong giai đoạn phát triển, '
      'vui lòng quay lại sau.';

  const FeatureFlag({
    required this.id,
    required this.label,
    this.isEnabled = true,
    this.disabledMessage = defaultDisabledMessage,
    this.updatedAt,
  });

  /// Tạo đối tượng FeatureFlag từ document Firestore.
  factory FeatureFlag.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final Map<String, dynamic> data =
        document.data() ?? <String, dynamic>{};

    return FeatureFlag(
      id: document.id,
      label: data['label'] as String? ?? document.id,
      isEnabled: data['isEnabled'] as bool? ?? true,
      disabledMessage: _nonEmptyOrDefault(
        data['disabledMessage'] as String?,
      ),
      updatedAt: _parseDateTime(data['updatedAt']),
    );
  }

  /// Chuyển FeatureFlag thành Map để lưu lên Firestore.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'label': label.trim(),
      'isEnabled': isEnabled,
      'disabledMessage': disabledMessage.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Tạo bản sao và thay đổi một số thuộc tính.
  FeatureFlag copyWith({
    String? id,
    String? label,
    bool? isEnabled,
    String? disabledMessage,
    DateTime? updatedAt,
  }) {
    return FeatureFlag(
      id: id ?? this.id,
      label: label ?? this.label,
      isEnabled: isEnabled ?? this.isEnabled,
      disabledMessage: disabledMessage ?? this.disabledMessage,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static String _nonEmptyOrDefault(String? value) {
    final String cleanValue = value?.trim() ?? '';

    if (cleanValue.isEmpty) {
      return defaultDisabledMessage;
    }

    return cleanValue;
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
    return 'FeatureFlag('
        'id: $id, '
        'label: $label, '
        'isEnabled: $isEnabled'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is FeatureFlag && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
