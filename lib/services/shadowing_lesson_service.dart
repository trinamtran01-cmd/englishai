import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/shadowing_lesson.dart';
import '../models/shadowing_segment.dart';

/// Quản lý dữ liệu bài luyện Shadowing (bài + từng câu) trên
/// Firebase Firestore.
///
/// Collections sử dụng: shadowing_lessons, shadowing_segments
class ShadowingLessonService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>>
      get _lessonsCollection {
    return _firestore.collection('shadowing_lessons');
  }

  CollectionReference<Map<String, dynamic>>
      get _segmentsCollection {
    return _firestore.collection('shadowing_segments');
  }

  /// Theo dõi danh sách bài luyện Shadowing.
  ///
  /// Sắp xếp mới nhất trước, thực hiện trong Flutter để không
  /// yêu cầu composite index trên Firebase.
  Stream<List<ShadowingLesson>> getAllLessons() {
    return _lessonsCollection.snapshots().map(
      (QuerySnapshot<Map<String, dynamic>> snapshot) {
        final List<ShadowingLesson> lessons = snapshot.docs
            .map(ShadowingLesson.fromFirestore)
            .toList();

        lessons.sort(
          (ShadowingLesson first, ShadowingLesson second) {
            final DateTime firstDate = first.createdAt ??
                DateTime.fromMillisecondsSinceEpoch(0);

            final DateTime secondDate = second.createdAt ??
                DateTime.fromMillisecondsSinceEpoch(0);

            return secondDate.compareTo(firstDate);
          },
        );

        return lessons;
      },
    );
  }

  /// Lấy toàn bộ danh sách bài luyện Shadowing một lần.
  ///
  /// Dùng cho màn hình quản trị (tải lại thủ công sau khi
  /// thêm/sửa/xóa) thay vì lắng nghe stream liên tục, để tránh màn
  /// hình phía sau tự rebuild trong lúc dialog thêm/sửa đang đóng.
  Future<List<ShadowingLesson>> getAllLessonsOnce() async {
    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot =
          await _lessonsCollection.get();

      final List<ShadowingLesson> lessons = snapshot.docs
          .map(ShadowingLesson.fromFirestore)
          .toList();

      lessons.sort(
        (ShadowingLesson first, ShadowingLesson second) {
          final DateTime firstDate = first.createdAt ??
              DateTime.fromMillisecondsSinceEpoch(0);

          final DateTime secondDate = second.createdAt ??
              DateTime.fromMillisecondsSinceEpoch(0);

          return secondDate.compareTo(firstDate);
        },
      );

      return lessons;
    } on FirebaseException catch (error) {
      throw Exception(
        'Không thể tải danh sách bài luyện Shadowing: '
        '${error.code}',
      );
    }
  }

  /// Theo dõi danh sách câu (segment) thuộc một bài luyện Shadowing.
  ///
  /// Firestore chỉ lọc theo lessonId, sắp xếp theo order được
  /// thực hiện trong Flutter để không yêu cầu composite index.
  Stream<List<ShadowingSegment>> getSegmentsByLesson(
    String lessonId,
  ) {
    final String cleanLessonId = lessonId.trim();

    if (cleanLessonId.isEmpty) {
      return Stream<List<ShadowingSegment>>.value(
        <ShadowingSegment>[],
      );
    }

    return _segmentsCollection
        .where('lessonId', isEqualTo: cleanLessonId)
        .snapshots()
        .map(
      (QuerySnapshot<Map<String, dynamic>> snapshot) {
        final List<ShadowingSegment> segments = snapshot.docs
            .map(ShadowingSegment.fromFirestore)
            .toList();

        segments.sort(
          (ShadowingSegment first, ShadowingSegment second) {
            return first.order.compareTo(second.order);
          },
        );

        return segments;
      },
    );
  }

  /// Lấy toàn bộ danh sách câu thuộc một bài luyện Shadowing một lần.
  ///
  /// Dùng cho màn hình quản trị.
  Future<List<ShadowingSegment>> getSegmentsByLessonOnce(
    String lessonId,
  ) async {
    final String cleanLessonId = lessonId.trim();

    if (cleanLessonId.isEmpty) {
      return <ShadowingSegment>[];
    }

    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot =
          await _segmentsCollection
              .where('lessonId', isEqualTo: cleanLessonId)
              .get();

      final List<ShadowingSegment> segments = snapshot.docs
          .map(ShadowingSegment.fromFirestore)
          .toList();

      segments.sort(
        (ShadowingSegment first, ShadowingSegment second) {
          return first.order.compareTo(second.order);
        },
      );

      return segments;
    } on FirebaseException catch (error) {
      throw Exception(
        'Không thể tải danh sách câu: ${error.code}',
      );
    }
  }

  /// Thêm một bài luyện Shadowing mới.
  ///
  /// Trả về ID của bài luyện vừa được tạo.
  Future<String> addLesson(ShadowingLesson lesson) async {
    if (!lesson.isValid) {
      throw ArgumentError(
        'Bài luyện Shadowing phải có tiêu đề.',
      );
    }

    try {
      final DocumentReference<Map<String, dynamic>> document =
          await _lessonsCollection.add(lesson.toMap());

      return document.id;
    } on FirebaseException catch (error) {
      throw Exception(
        'Không thể thêm bài luyện Shadowing: ${error.code}',
      );
    }
  }

  /// Cập nhật thông tin một bài luyện Shadowing.
  Future<void> updateLesson(ShadowingLesson lesson) async {
    final String cleanId = lesson.id.trim();

    if (cleanId.isEmpty) {
      throw ArgumentError(
        'ID bài luyện Shadowing không được để trống.',
      );
    }

    if (!lesson.isValid) {
      throw ArgumentError(
        'Bài luyện Shadowing phải có tiêu đề.',
      );
    }

    try {
      final Map<String, dynamic> data = lesson.toMap();

      // Không thay đổi thời gian tạo khi cập nhật.
      data.remove('createdAt');

      await _lessonsCollection.doc(cleanId).update(data);
    } on FirebaseException catch (error) {
      throw Exception(
        'Không thể cập nhật bài luyện Shadowing: ${error.code}',
      );
    }
  }

  /// Xóa một bài luyện Shadowing khỏi Firestore.
  ///
  /// Xóa cascade toàn bộ các câu (segment) con thuộc bài luyện này,
  /// tránh để lại dữ liệu segment mồ côi không còn lessonId hợp lệ.
  Future<void> deleteLesson(String lessonId) async {
    final String cleanId = lessonId.trim();

    if (cleanId.isEmpty) {
      throw ArgumentError(
        'ID bài luyện Shadowing không được để trống.',
      );
    }

    try {
      final QuerySnapshot<Map<String, dynamic>> segmentsSnapshot =
          await _segmentsCollection
              .where('lessonId', isEqualTo: cleanId)
              .get();

      final WriteBatch batch = _firestore.batch();

      for (final QueryDocumentSnapshot<Map<String, dynamic>>
          segmentDocument in segmentsSnapshot.docs) {
        batch.delete(segmentDocument.reference);
      }

      batch.delete(_lessonsCollection.doc(cleanId));

      await batch.commit();
    } on FirebaseException catch (error) {
      throw Exception(
        'Không thể xóa bài luyện Shadowing: ${error.code}',
      );
    }
  }

  /// Thêm một câu (segment) mới vào bài luyện Shadowing.
  ///
  /// Trả về ID của câu vừa được tạo.
  Future<String> addSegment(ShadowingSegment segment) async {
    if (!segment.isValid) {
      throw ArgumentError(
        'Câu shadowing phải có lessonId và text.',
      );
    }

    try {
      final DocumentReference<Map<String, dynamic>> document =
          await _segmentsCollection.add(segment.toMap());

      return document.id;
    } on FirebaseException catch (error) {
      throw Exception('Không thể thêm câu mới: ${error.code}');
    }
  }

  /// Cập nhật thông tin một câu (segment).
  Future<void> updateSegment(ShadowingSegment segment) async {
    final String cleanId = segment.id.trim();

    if (cleanId.isEmpty) {
      throw ArgumentError('ID câu không được để trống.');
    }

    if (!segment.isValid) {
      throw ArgumentError(
        'Câu shadowing phải có lessonId và text.',
      );
    }

    try {
      await _segmentsCollection.doc(cleanId).update(
            segment.toMap(),
          );
    } on FirebaseException catch (error) {
      throw Exception('Không thể cập nhật câu: ${error.code}');
    }
  }

  /// Xóa một câu (segment) khỏi Firestore.
  Future<void> deleteSegment(String segmentId) async {
    final String cleanId = segmentId.trim();

    if (cleanId.isEmpty) {
      throw ArgumentError('ID câu không được để trống.');
    }

    try {
      await _segmentsCollection.doc(cleanId).delete();
    } on FirebaseException catch (error) {
      throw Exception('Không thể xóa câu: ${error.code}');
    }
  }

  /// Kiểm tra collection đã có bài luyện Shadowing nào chưa.
  Future<bool> hasLessons() async {
    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot =
          await _lessonsCollection.limit(1).get();

      return snapshot.docs.isNotEmpty;
    } on FirebaseException catch (error) {
      throw Exception(
        'Không thể kiểm tra dữ liệu bài luyện Shadowing: '
        '${error.code}',
      );
    }
  }
}
