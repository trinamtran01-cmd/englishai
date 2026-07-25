import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Quản lý quyền quản trị viên và dữ liệu tổng quan.
///
/// Quyền quản trị được đọc từ:
///
/// users/{userId}/role
///
/// Giá trị hợp lệ:
/// - student: người học
/// - admin: quản trị viên
class AdminService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>>
      get _usersCollection {
    return _firestore.collection('users');
  }

  CollectionReference<Map<String, dynamic>>
      get _lessonsCollection {
    return _firestore.collection('lessons');
  }

  CollectionReference<Map<String, dynamic>>
      get _vocabulariesCollection {
    return _firestore.collection('vocabularies');
  }

  CollectionReference<Map<String, dynamic>>
      get _questionsCollection {
    return _firestore.collection('quiz_questions');
  }

  CollectionReference<Map<String, dynamic>>
      get _quizResultsCollection {
    return _firestore.collection('quiz_results');
  }

  /// Lấy người dùng hiện đang đăng nhập.
  ///
  /// Phát sinh lỗi nếu chưa đăng nhập.
  User _requireCurrentUser() {
    final User? user = _auth.currentUser;

    if (user == null) {
      throw StateError(
        'Bạn cần đăng nhập để sử dụng chức năng quản trị.',
      );
    }

    return user;
  }

  /// Theo dõi thông tin tài khoản hiện tại từ Firestore.
  ///
  /// Stream trả về null nếu:
  /// - Người dùng chưa đăng nhập.
  /// - Document tài khoản không tồn tại.
  Stream<Map<String, dynamic>?> getCurrentUserProfile() {
    final User? user = _auth.currentUser;

    if (user == null) {
      return Stream<Map<String, dynamic>?>.value(null);
    }

    return _usersCollection
        .doc(user.uid)
        .snapshots()
        .map(
      (
        DocumentSnapshot<Map<String, dynamic>> document,
      ) {
        if (!document.exists) {
          return null;
        }

        return document.data();
      },
    );
  }

  /// Theo dõi quyền quản trị viên theo thời gian thực.
  ///
  /// Trả về true khi trường role có giá trị "admin".
  Stream<bool> get isCurrentUserAdminStream {
    final User? user = _auth.currentUser;

    if (user == null) {
      return Stream<bool>.value(false);
    }

    return _usersCollection
        .doc(user.uid)
        .snapshots()
        .map(
      (
        DocumentSnapshot<Map<String, dynamic>> document,
      ) {
        if (!document.exists) {
          return false;
        }

        final Map<String, dynamic> data =
            document.data() ?? <String, dynamic>{};

        final String role = data['role']
                ?.toString()
                .trim()
                .toLowerCase() ??
            'student';

        return role == 'admin';
      },
    );
  }

  /// Kiểm tra tài khoản hiện tại có phải admin hay không.
  ///
  /// Đây là kiểm tra một lần, phù hợp trước khi thực hiện
  /// thao tác thêm, sửa hoặc xóa dữ liệu.
  Future<bool> isCurrentUserAdmin() async {
    final User? user = _auth.currentUser;

    if (user == null) {
      return false;
    }

    try {
      final DocumentSnapshot<Map<String, dynamic>> document =
          await _usersCollection.doc(user.uid).get();

      if (!document.exists) {
        return false;
      }

      final Map<String, dynamic> data =
          document.data() ?? <String, dynamic>{};

      final String role = data['role']
              ?.toString()
              .trim()
              .toLowerCase() ??
          'student';

      return role == 'admin';
    } on FirebaseException catch (error) {
      throw Exception(
        'Không thể kiểm tra quyền quản trị: ${error.code}',
      );
    }
  }

  /// Yêu cầu người dùng hiện tại phải có quyền admin.
  ///
  /// Hàm này được gọi trước những thao tác quản trị quan trọng.
  Future<User> requireAdmin() async {
    final User user = _requireCurrentUser();

    final bool isAdmin = await isCurrentUserAdmin();

    if (!isAdmin) {
      throw StateError(
        'Bạn không có quyền thực hiện chức năng quản trị.',
      );
    }

    return user;
  }

  /// Lấy thông tin tài khoản hiện tại một lần.
  Future<Map<String, dynamic>?> getCurrentUserProfileOnce() async {
    final User? user = _auth.currentUser;

    if (user == null) {
      return null;
    }

    try {
      final DocumentSnapshot<Map<String, dynamic>> document =
          await _usersCollection.doc(user.uid).get();

      if (!document.exists) {
        return null;
      }

      return document.data();
    } on FirebaseException catch (error) {
      throw Exception(
        'Không thể tải thông tin tài khoản: ${error.code}',
      );
    }
  }

  /// Lấy vai trò của người dùng hiện tại.
  ///
  /// Trả về "student" nếu chưa có thông tin vai trò.
  Future<String> getCurrentUserRole() async {
    final Map<String, dynamic>? profile =
        await getCurrentUserProfileOnce();

    return profile?['role']
            ?.toString()
            .trim()
            .toLowerCase() ??
        'student';
  }

  /// Theo dõi danh sách người dùng.
  ///
  /// Chức năng này chỉ dành cho admin.
  Stream<List<Map<String, dynamic>>> getUsersStream() {
    final User? currentUser = _auth.currentUser;

    if (currentUser == null) {
      return Stream<List<Map<String, dynamic>>>.value(
        <Map<String, dynamic>>[],
      );
    }

    return _usersCollection.snapshots().map(
      (
        QuerySnapshot<Map<String, dynamic>> snapshot,
      ) {
        final List<Map<String, dynamic>> users =
            snapshot.docs.map(
          (
            QueryDocumentSnapshot<Map<String, dynamic>>
                document,
          ) {
            final Map<String, dynamic> data =
                document.data();

            return <String, dynamic>{
              'id': document.id,
              ...data,
            };
          },
        ).toList();

        users.sort(
          (
            Map<String, dynamic> first,
            Map<String, dynamic> second,
          ) {
            final String firstName =
                first['name']?.toString() ?? '';

            final String secondName =
                second['name']?.toString() ?? '';

            return firstName.toLowerCase().compareTo(
                  secondName.toLowerCase(),
                );
          },
        );

        return users;
      },
    );
  }

  /// Lấy số liệu tổng quan cho trang quản trị.
  ///
  /// Kết quả gồm:
  /// - totalUsers
  /// - totalStudents
  /// - totalAdmins
  /// - totalLessons
  /// - activeLessons
  /// - totalVocabularies
  /// - totalQuestions
  /// - totalQuizResults
  Future<Map<String, int>> getDashboardStatistics() async {
    await requireAdmin();

    try {
      final List<dynamic> results =
          await Future.wait<dynamic>([
        _usersCollection.get(),
        _lessonsCollection.get(),
        _vocabulariesCollection.get(),
        _questionsCollection.get(),
        _quizResultsCollection.get(),
      ]);

      final QuerySnapshot<Map<String, dynamic>>
          usersSnapshot =
          results[0]
              as QuerySnapshot<Map<String, dynamic>>;

      final QuerySnapshot<Map<String, dynamic>>
          lessonsSnapshot =
          results[1]
              as QuerySnapshot<Map<String, dynamic>>;

      final QuerySnapshot<Map<String, dynamic>>
          vocabulariesSnapshot =
          results[2]
              as QuerySnapshot<Map<String, dynamic>>;

      final QuerySnapshot<Map<String, dynamic>>
          questionsSnapshot =
          results[3]
              as QuerySnapshot<Map<String, dynamic>>;

      final QuerySnapshot<Map<String, dynamic>>
          quizResultsSnapshot =
          results[4]
              as QuerySnapshot<Map<String, dynamic>>;

      int totalStudents = 0;
      int totalAdmins = 0;

      for (final QueryDocumentSnapshot<
          Map<String, dynamic>> document
          in usersSnapshot.docs) {
        final Map<String, dynamic> data =
            document.data();

        final String role = data['role']
                ?.toString()
                .trim()
                .toLowerCase() ??
            'student';

        if (role == 'admin') {
          totalAdmins++;
        } else {
          totalStudents++;
        }
      }

      final int activeLessons =
          lessonsSnapshot.docs.where(
        (
          QueryDocumentSnapshot<Map<String, dynamic>>
              document,
        ) {
          final Map<String, dynamic> data =
              document.data();

          return data['isActive'] as bool? ?? true;
        },
      ).length;

      return <String, int>{
        'totalUsers': usersSnapshot.docs.length,
        'totalStudents': totalStudents,
        'totalAdmins': totalAdmins,
        'totalLessons': lessonsSnapshot.docs.length,
        'activeLessons': activeLessons,
        'totalVocabularies':
            vocabulariesSnapshot.docs.length,
        'totalQuestions':
            questionsSnapshot.docs.length,
        'totalQuizResults':
            quizResultsSnapshot.docs.length,
      };
    } on FirebaseException catch (error) {
      throw Exception(
        'Không thể tải số liệu quản trị: ${error.code}',
      );
    }
  }

  /// Cập nhật trạng thái hoạt động của một bài học.
  Future<void> updateLessonStatus({
    required String lessonId,
    required bool isActive,
  }) async {
    await requireAdmin();

    final String cleanLessonId = lessonId.trim();

    if (cleanLessonId.isEmpty) {
      throw ArgumentError(
        'ID bài học không được để trống.',
      );
    }

    try {
      await _lessonsCollection
          .doc(cleanLessonId)
          .update(
        <String, dynamic>{
          'isActive': isActive,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );
    } on FirebaseException catch (error) {
      throw Exception(
        'Không thể cập nhật trạng thái bài học: '
        '${error.code}',
      );
    }
  }

  /// Cập nhật trạng thái hoạt động của một từ vựng.
  Future<void> updateVocabularyStatus({
    required String vocabularyId,
    required bool isActive,
  }) async {
    await requireAdmin();

    final String cleanVocabularyId =
        vocabularyId.trim();

    if (cleanVocabularyId.isEmpty) {
      throw ArgumentError(
        'ID từ vựng không được để trống.',
      );
    }

    try {
      await _vocabulariesCollection
          .doc(cleanVocabularyId)
          .update(
        <String, dynamic>{
          'isActive': isActive,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );
    } on FirebaseException catch (error) {
      throw Exception(
        'Không thể cập nhật trạng thái từ vựng: '
        '${error.code}',
      );
    }
  }

  /// Cập nhật trạng thái hoạt động của một câu hỏi.
  Future<void> updateQuestionStatus({
    required String questionId,
    required bool isActive,
  }) async {
    await requireAdmin();

    final String cleanQuestionId =
        questionId.trim();

    if (cleanQuestionId.isEmpty) {
      throw ArgumentError(
        'ID câu hỏi không được để trống.',
      );
    }

    try {
      await _questionsCollection
          .doc(cleanQuestionId)
          .update(
        <String, dynamic>{
          'isActive': isActive,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );
    } on FirebaseException catch (error) {
      throw Exception(
        'Không thể cập nhật trạng thái câu hỏi: '
        '${error.code}',
      );
    }
  }

  /// Đếm số từ vựng thuộc một bài học.
  Future<int> countVocabulariesByLesson(
    String lessonId,
  ) async {
    await requireAdmin();

    final String cleanLessonId = lessonId.trim();

    if (cleanLessonId.isEmpty) {
      return 0;
    }

    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot =
          await _vocabulariesCollection
              .where(
                'lessonId',
                isEqualTo: cleanLessonId,
              )
              .get();

      return snapshot.docs.length;
    } on FirebaseException catch (error) {
      throw Exception(
        'Không thể đếm từ vựng: ${error.code}',
      );
    }
  }

  /// Đếm số câu hỏi thuộc một bài học.
  Future<int> countQuestionsByLesson(
    String lessonId,
  ) async {
    await requireAdmin();

    final String cleanLessonId = lessonId.trim();

    if (cleanLessonId.isEmpty) {
      return 0;
    }

    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot =
          await _questionsCollection
              .where(
                'lessonId',
                isEqualTo: cleanLessonId,
              )
              .get();

      return snapshot.docs.length;
    } on FirebaseException catch (error) {
      throw Exception(
        'Không thể đếm câu hỏi: ${error.code}',
      );
    }
  }

  /// Đổi vai trò của một tài khoản.
  ///
  /// Chỉ admin mới có thể thực hiện.
  ///
  /// Người dùng không được tự thay đổi vai trò của chính mình,
  /// tránh trường hợp tự hạ quyền hoặc tự nâng quyền.
  Future<void> updateUserRole({
    required String userId,
    required String role,
  }) async {
    final User currentAdmin = await requireAdmin();

    final String cleanUserId = userId.trim();
    final String cleanRole =
        role.trim().toLowerCase();

    if (cleanUserId.isEmpty) {
      throw ArgumentError(
        'ID người dùng không được để trống.',
      );
    }

    if (cleanRole != 'student' &&
        cleanRole != 'admin') {
      throw ArgumentError(
        'Vai trò chỉ có thể là student hoặc admin.',
      );
    }

    if (cleanUserId == currentAdmin.uid) {
      throw StateError(
        'Bạn không thể tự thay đổi quyền của chính mình.',
      );
    }

    try {
      final DocumentReference<Map<String, dynamic>>
          userDocument =
          _usersCollection.doc(cleanUserId);

      final DocumentSnapshot<Map<String, dynamic>>
          snapshot = await userDocument.get();

      if (!snapshot.exists) {
        throw StateError(
          'Không tìm thấy tài khoản cần cập nhật.',
        );
      }

      await userDocument.update(
        <String, dynamic>{
          'role': cleanRole,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );
    } on FirebaseException catch (error) {
      throw Exception(
        'Không thể cập nhật quyền tài khoản: '
        '${error.code}',
      );
    }
  }
}