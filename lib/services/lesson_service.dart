import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/lesson.dart';

/// Quản lý dữ liệu bài học trên Firebase Firestore.
///
/// Collection sử dụng: lessons
class LessonService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _lessonsCollection {
    return _firestore.collection('lessons');
  }

  /// Theo dõi danh sách bài học đang hoạt động theo thời gian thực.
  ///
  /// Chỉ lọc isActive trên Firestore.
  /// Danh sách được sắp xếp theo order trong Flutter để không cần
  /// tạo composite index trên Firebase.
  Stream<List<Lesson>> getActiveLessons() {
    return _lessonsCollection
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snapshot) {
      final List<Lesson> lessons = snapshot.docs
          .map(Lesson.fromFirestore)
          .toList();

      lessons.sort(
        (Lesson firstLesson, Lesson secondLesson) {
          return firstLesson.order.compareTo(secondLesson.order);
        },
      );

      return lessons;
    });
  }

  /// Lấy toàn bộ bài học một lần.
  ///
  /// Danh sách được sắp xếp theo order trong Flutter.
  Future<List<Lesson>> getAllLessons() async {
    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot =
          await _lessonsCollection.get();

      final List<Lesson> lessons = snapshot.docs
          .map(Lesson.fromFirestore)
          .toList();

      lessons.sort(
        (Lesson firstLesson, Lesson secondLesson) {
          return firstLesson.order.compareTo(secondLesson.order);
        },
      );

      return lessons;
    } on FirebaseException catch (error) {
      throw Exception(
        'Không thể tải danh sách bài học: ${error.code}',
      );
    }
  }

  /// Lấy thông tin chi tiết của một bài học theo ID.
  ///
  /// Trả về null nếu bài học không tồn tại.
  Future<Lesson?> getLessonById(String lessonId) async {
    final String cleanLessonId = lessonId.trim();

    if (cleanLessonId.isEmpty) {
      throw ArgumentError(
        'ID bài học không được để trống.',
      );
    }

    try {
      final DocumentSnapshot<Map<String, dynamic>> document =
          await _lessonsCollection.doc(cleanLessonId).get();

      if (!document.exists) {
        return null;
      }

      return Lesson.fromFirestore(document);
    } on FirebaseException catch (error) {
      throw Exception(
        'Không thể tải thông tin bài học: ${error.code}',
      );
    }
  }

  /// Thêm một bài học mới vào Firestore.
  ///
  /// Trả về ID của bài học vừa được tạo.
  Future<String> addLesson(Lesson lesson) async {
    try {
      final DocumentReference<Map<String, dynamic>> document =
          await _lessonsCollection.add(lesson.toMap());

      return document.id;
    } on FirebaseException catch (error) {
      throw Exception(
        'Không thể thêm bài học: ${error.code}',
      );
    }
  }

  /// Cập nhật thông tin một bài học.
  Future<void> updateLesson(Lesson lesson) async {
    final String cleanLessonId = lesson.id.trim();

    if (cleanLessonId.isEmpty) {
      throw ArgumentError(
        'ID bài học không được để trống.',
      );
    }

    try {
      final Map<String, dynamic> data = lesson.toMap();

      // Không thay đổi thời gian tạo khi cập nhật.
      data.remove('createdAt');

      await _lessonsCollection.doc(cleanLessonId).update(data);
    } on FirebaseException catch (error) {
      throw Exception(
        'Không thể cập nhật bài học: ${error.code}',
      );
    }
  }

  /// Bật hoặc tắt trạng thái hoạt động của bài học.
  Future<void> updateLessonStatus({
    required String lessonId,
    required bool isActive,
  }) async {
    final String cleanLessonId = lessonId.trim();

    if (cleanLessonId.isEmpty) {
      throw ArgumentError(
        'ID bài học không được để trống.',
      );
    }

    try {
      await _lessonsCollection.doc(cleanLessonId).update({
        'isActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (error) {
      throw Exception(
        'Không thể cập nhật trạng thái bài học: ${error.code}',
      );
    }
  }

  /// Xóa một bài học khỏi Firestore.
  ///
  /// Chức năng này sẽ được sử dụng cho trang quản trị sau này.
  Future<void> deleteLesson(String lessonId) async {
    final String cleanLessonId = lessonId.trim();

    if (cleanLessonId.isEmpty) {
      throw ArgumentError(
        'ID bài học không được để trống.',
      );
    }

    try {
      await _lessonsCollection.doc(cleanLessonId).delete();
    } on FirebaseException catch (error) {
      throw Exception(
        'Không thể xóa bài học: ${error.code}',
      );
    }
  }

  /// Kiểm tra collection lessons đã có dữ liệu hay chưa.
  Future<bool> hasLessons() async {
    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot =
          await _lessonsCollection.limit(1).get();

      return snapshot.docs.isNotEmpty;
    } on FirebaseException catch (error) {
      throw Exception(
        'Không thể kiểm tra dữ liệu bài học: ${error.code}',
      );
    }
  }

  /// Tạo dữ liệu bài học mẫu để thử nghiệm.
  ///
  /// Hàm chỉ tạo dữ liệu khi collection lessons đang trống,
  /// giúp tránh tạo dữ liệu trùng lặp.
  Future<void> createSampleLessons() async {
    try {
      final bool alreadyHasLessons = await hasLessons();

      if (alreadyHasLessons) {
        return;
      }

      final WriteBatch batch = _firestore.batch();

      final List<Map<String, dynamic>> sampleLessons =
          <Map<String, dynamic>>[
        {
          'title': 'Chào hỏi cơ bản',
          'topic': 'Giao tiếp cơ bản',
          'description':
              'Học các từ và câu tiếng Anh dùng để chào hỏi, giới thiệu bản thân.',
          'icon': 'waving_hand',
          'color': 0xFF3B5BDB,
          'order': 1,
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        {
          'title': 'Gia đình',
          'topic': 'Từ vựng theo chủ đề',
          'description':
              'Học từ vựng tiếng Anh về các thành viên trong gia đình.',
          'icon': 'family',
          'color': 0xFF2F9E44,
          'order': 2,
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        {
          'title': 'Trường học',
          'topic': 'Từ vựng theo chủ đề',
          'description':
              'Học tên các đồ vật, môn học và hoạt động tại trường.',
          'icon': 'school',
          'color': 0xFFF59F00,
          'order': 3,
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        {
          'title': 'Đồ ăn và thức uống',
          'topic': 'Từ vựng theo chủ đề',
          'description':
              'Học từ vựng thông dụng về món ăn và thức uống.',
          'icon': 'restaurant',
          'color': 0xFFE64980,
          'order': 4,
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        {
          'title': 'Công việc hằng ngày',
          'topic': 'Giao tiếp hằng ngày',
          'description':
              'Học cách mô tả các hoạt động thường thực hiện trong ngày.',
          'icon': 'schedule',
          'color': 0xFF9C36B5,
          'order': 5,
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      ];

      for (final Map<String, dynamic> lessonData
          in sampleLessons) {
        final DocumentReference<Map<String, dynamic>> document =
            _lessonsCollection.doc();

        batch.set(document, lessonData);
      }

      await batch.commit();
    } on FirebaseException catch (error) {
      throw Exception(
        'Không thể tạo dữ liệu bài học mẫu: ${error.code}',
      );
    }
  }
}