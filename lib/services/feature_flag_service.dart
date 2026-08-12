import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/feature_flag.dart';

/// Quản lý trạng thái bật/tắt tạm thời của từng tính năng trên
/// trang chủ (dùng cho việc Admin tạm khóa 1 tính năng đang sửa lỗi).
///
/// Collection sử dụng: feature_flags
class FeatureFlagService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>>
      get _flagsCollection {
    return _firestore.collection('feature_flags');
  }

  /// Theo dõi toàn bộ danh sách feature flag hiện có, trả về dạng
  /// Map theo [FeatureFlag.id] để tra cứu nhanh.
  ///
  /// LƯU Ý QUAN TRỌNG (fail-open): map này chỉ chứa những tính năng
  /// Admin đã từng đụng vào (tạo document). Với tính năng chưa có
  /// document, nơi gọi PHẢI coi là đang bật (`isEnabled: true`) —
  /// dùng [isFeatureEnabled] thay vì tự tra map để tránh quên xử lý
  /// trường hợp này, tránh việc 1 tính năng đang hoạt động bình
  /// thường bỗng dưng bị ẩn chỉ vì chưa có ai tạo flag cho nó.
  Stream<Map<String, FeatureFlag>> getAllFlags() {
    return _flagsCollection.snapshots().map(
      (QuerySnapshot<Map<String, dynamic>> snapshot) {
        final Map<String, FeatureFlag> flags = <String, FeatureFlag>{};

        for (final QueryDocumentSnapshot<Map<String, dynamic>>
            document in snapshot.docs) {
          flags[document.id] = FeatureFlag.fromFirestore(document);
        }

        return flags;
      },
    );
  }

  /// Kiểm tra 1 tính năng có đang bật hay không (fail-open: mặc
  /// định bật nếu chưa có flag tương ứng).
  bool isFeatureEnabled(
    Map<String, FeatureFlag> flags,
    String featureId,
  ) {
    return flags[featureId]?.isEnabled ?? true;
  }

  /// Lấy thông báo hiển thị khi 1 tính năng đang bị khóa (fail-open:
  /// trả về thông báo mặc định nếu chưa có flag tương ứng).
  String disabledMessageFor(
    Map<String, FeatureFlag> flags,
    String featureId,
  ) {
    return flags[featureId]?.disabledMessage ??
        FeatureFlag.defaultDisabledMessage;
  }

  /// Bật/tắt 1 tính năng. Tạo mới document nếu tính năng này chưa
  /// từng có flag (dùng `merge: true` để không mất dữ liệu cũ).
  Future<void> setFeatureEnabled(
    String featureId,
    bool isEnabled, {
    String? label,
    String? disabledMessage,
  }) async {
    final String cleanFeatureId = featureId.trim();

    if (cleanFeatureId.isEmpty) {
      throw ArgumentError(
        'ID tính năng không được để trống.',
      );
    }

    final Map<String, dynamic> data = <String, dynamic>{
      'isEnabled': isEnabled,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (label != null) {
      data['label'] = label.trim();
    }

    if (disabledMessage != null) {
      final String cleanMessage = disabledMessage.trim();

      data['disabledMessage'] = cleanMessage.isEmpty
          ? FeatureFlag.defaultDisabledMessage
          : cleanMessage;
    }

    try {
      await _flagsCollection.doc(cleanFeatureId).set(
        data,
        SetOptions(merge: true),
      );
    } on FirebaseException catch (error) {
      throw Exception(
        'Không thể cập nhật trạng thái tính năng: ${error.code}',
      );
    }
  }
}
