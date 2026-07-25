import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/learning_progress.dart';
import '../models/lesson.dart';

/// Quản lý tiến độ học tập của người dùng trên Firestore.
///
/// Collection sử dụng: learning_progress
///
/// Mỗi người dùng có một document tiến độ cho mỗi bài học.
/// ID document có dạng: userId_lessonId
class ProgressService {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>>
      get _progressCollection {
    return _firestore.collection('learning_progress');
  }

  /// Lấy tài khoản hiện đang đăng nhập.
  User _requireCurrentUser() {
    final User? user = _auth.currentUser;

    if (user == null) {
      throw StateError(
        'Bạn cần đăng nhập để lưu tiến độ học tập.',
      );
    }

    return user;
  }

  /// Tạo ID cố định cho tiến độ của người dùng và bài học.
  String _createProgressDocumentId({
    required String userId,
    required String lessonId,
  }) {
    return '${userId}_$lessonId';
  }

  /// Theo dõi toàn bộ tiến độ của người dùng hiện tại.
  Stream<List<LearningProgress>>
      getCurrentUserProgress() {
    final User? user = _auth.currentUser;

    if (user == null) {
      return Stream<List<LearningProgress>>.value(
        <LearningProgress>[],
      );
    }

    return _progressCollection
        .where(
          'userId',
          isEqualTo: user.uid,
        )
        .snapshots()
        .map(
      (
        QuerySnapshot<Map<String, dynamic>> snapshot,
      ) {
        final List<LearningProgress> progressList =
            snapshot.docs
                .map(LearningProgress.fromFirestore)
                .toList();

        progressList.sort(
          (
            LearningProgress firstProgress,
            LearningProgress secondProgress,
          ) {
            final DateTime firstDate =
                firstProgress.lastStudiedAt ??
                    firstProgress.updatedAt ??
                    DateTime.fromMillisecondsSinceEpoch(0);

            final DateTime secondDate =
                secondProgress.lastStudiedAt ??
                    secondProgress.updatedAt ??
                    DateTime.fromMillisecondsSinceEpoch(0);

            return secondDate.compareTo(firstDate);
          },
        );

        return progressList;
      },
    );
  }

  /// Theo dõi tiến độ của một bài học cụ thể.
  Stream<LearningProgress?> getLessonProgress(
    String lessonId,
  ) {
    final User? user = _auth.currentUser;
    final String cleanLessonId = lessonId.trim();

    if (user == null || cleanLessonId.isEmpty) {
      return Stream<LearningProgress?>.value(null);
    }

    final String documentId =
        _createProgressDocumentId(
      userId: user.uid,
      lessonId: cleanLessonId,
    );

    return _progressCollection
        .doc(documentId)
        .snapshots()
        .map(
      (
        DocumentSnapshot<Map<String, dynamic>> document,
      ) {
        if (!document.exists) {
          return null;
        }

        return LearningProgress.fromFirestore(document);
      },
    );
  }

  /// Lấy tiến độ của một bài học một lần.
  Future<LearningProgress?> getLessonProgressOnce(
    String lessonId,
  ) async {
    final User user = _requireCurrentUser();
    final String cleanLessonId = lessonId.trim();

    if (cleanLessonId.isEmpty) {
      throw ArgumentError(
        'ID bài học không được để trống.',
      );
    }

    final String documentId =
        _createProgressDocumentId(
      userId: user.uid,
      lessonId: cleanLessonId,
    );

    try {
      final DocumentSnapshot<Map<String, dynamic>>
          document =
          await _progressCollection
              .doc(documentId)
              .get();

      if (!document.exists) {
        return null;
      }

      return LearningProgress.fromFirestore(document);
    } on FirebaseException catch (error) {
      throw Exception(
        'Không thể tải tiến độ bài học: ${error.code}',
      );
    }
  }

  /// Bắt đầu hoặc tiếp tục một bài học.
  ///
  /// Phiên bản này không đọc document trước khi ghi.
  /// Điều này tránh lỗi permission-denied khi document
  /// tiến độ chưa tồn tại.
  ///
  /// SetOptions(merge: true) giúp:
  /// - Tạo document nếu chưa tồn tại.
  /// - Không xóa tiến độ cũ nếu document đã tồn tại.
  Future<void> startLesson({
    required Lesson lesson,
    required int totalWords,
  }) async {
    final User user = _requireCurrentUser();
    final String lessonId = lesson.id.trim();

    if (lessonId.isEmpty) {
      throw ArgumentError(
        'ID bài học không được để trống.',
      );
    }

    final int safeTotalWords =
        totalWords < 0 ? 0 : totalWords;

    final String documentId =
        _createProgressDocumentId(
      userId: user.uid,
      lessonId: lessonId,
    );

    try {
      await _progressCollection.doc(documentId).set(
        <String, dynamic>{
          'userId': user.uid,
          'lessonId': lessonId,
          'lessonTitle': lesson.title.trim(),
          'totalWords': safeTotalWords,
          'lastStudiedAt':
              FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } on FirebaseException catch (error) {
      throw Exception(
        'Không thể bắt đầu bài học: ${error.code}',
      );
    }
  }

  /// Ghi nhận số từ nhiều nhất người dùng đã xem.
  ///
  /// Tiến độ không bị giảm nếu người dùng quay lại từ cũ.
  Future<void> updateViewedWords({
    required Lesson lesson,
    required int viewedWords,
    required int totalWords,
  }) async {
    final User user = _requireCurrentUser();
    final String lessonId = lesson.id.trim();

    if (lessonId.isEmpty) {
      throw ArgumentError(
        'ID bài học không được để trống.',
      );
    }

    final int safeTotalWords =
        totalWords < 0 ? 0 : totalWords;

    int requestedViewedWords =
        viewedWords < 0 ? 0 : viewedWords;

    if (safeTotalWords > 0 &&
        requestedViewedWords > safeTotalWords) {
      requestedViewedWords = safeTotalWords;
    }

    final String documentId =
        _createProgressDocumentId(
      userId: user.uid,
      lessonId: lessonId,
    );

    final DocumentReference<Map<String, dynamic>>
        documentReference =
        _progressCollection.doc(documentId);

    try {
      await _firestore.runTransaction<void>(
        (Transaction transaction) async {
          final DocumentSnapshot<Map<String, dynamic>>
              document =
              await transaction.get(documentReference);

          int finalViewedWords =
              requestedViewedWords;

          int studyCount = 1;

          dynamic firstStudiedAt =
              FieldValue.serverTimestamp();

          dynamic createdAt =
              FieldValue.serverTimestamp();

          if (document.exists) {
            final Map<String, dynamic> currentData =
                document.data() ??
                    <String, dynamic>{};

            final int currentViewedWords =
                _parseInteger(
              currentData['viewedWords'],
            );

            if (currentViewedWords >
                finalViewedWords) {
              finalViewedWords =
                  currentViewedWords;
            }

            studyCount = _parseInteger(
              currentData['studyCount'],
              defaultValue: 1,
            );

            firstStudiedAt =
                currentData['firstStudiedAt'] ??
                    FieldValue.serverTimestamp();

            createdAt = currentData['createdAt'] ??
                FieldValue.serverTimestamp();
          }

          if (safeTotalWords > 0 &&
              finalViewedWords > safeTotalWords) {
            finalViewedWords = safeTotalWords;
          }

          final double percentage =
              LearningProgress
                  .calculateCompletionPercentage(
            viewedWords: finalViewedWords,
            totalWords: safeTotalWords,
          );

          final bool isCompleted =
              LearningProgress.calculateIsCompleted(
            viewedWords: finalViewedWords,
            totalWords: safeTotalWords,
          );

          final Map<String, dynamic> progressData =
              <String, dynamic>{
            'userId': user.uid,
            'lessonId': lessonId,
            'lessonTitle': lesson.title.trim(),
            'totalWords': safeTotalWords,
            'viewedWords': finalViewedWords,
            'completionPercentage': percentage,
            'isCompleted': isCompleted,
            'studyCount': studyCount,
            'firstStudiedAt': firstStudiedAt,
            'lastStudiedAt':
                FieldValue.serverTimestamp(),
            'createdAt': createdAt,
            'updatedAt':
                FieldValue.serverTimestamp(),
          };

          if (isCompleted) {
            progressData['completedAt'] =
                FieldValue.serverTimestamp();
          }

          transaction.set(
            documentReference,
            progressData,
            SetOptions(merge: true),
          );
        },
      );
    } on FirebaseException catch (error) {
      throw Exception(
        'Không thể cập nhật tiến độ: ${error.code}',
      );
    }
  }

  /// Đánh dấu bài học đã hoàn thành.
  Future<void> completeLesson({
    required Lesson lesson,
    required int totalWords,
  }) async {
    final User user = _requireCurrentUser();
    final String lessonId = lesson.id.trim();

    if (lessonId.isEmpty) {
      throw ArgumentError(
        'ID bài học không được để trống.',
      );
    }

    final int safeTotalWords =
        totalWords < 0 ? 0 : totalWords;

    final String documentId =
        _createProgressDocumentId(
      userId: user.uid,
      lessonId: lessonId,
    );

    final DocumentReference<Map<String, dynamic>>
        documentReference =
        _progressCollection.doc(documentId);

    try {
      await _firestore.runTransaction<void>(
        (Transaction transaction) async {
          final DocumentSnapshot<Map<String, dynamic>>
              document =
              await transaction.get(documentReference);

          int studyCount = 1;

          dynamic firstStudiedAt =
              FieldValue.serverTimestamp();

          dynamic createdAt =
              FieldValue.serverTimestamp();

          if (document.exists) {
            final Map<String, dynamic> currentData =
                document.data() ??
                    <String, dynamic>{};

            studyCount = _parseInteger(
              currentData['studyCount'],
              defaultValue: 1,
            );

            firstStudiedAt =
                currentData['firstStudiedAt'] ??
                    FieldValue.serverTimestamp();

            createdAt = currentData['createdAt'] ??
                FieldValue.serverTimestamp();
          }

          final bool completed =
              safeTotalWords > 0;

          final Map<String, dynamic> progressData =
              <String, dynamic>{
            'userId': user.uid,
            'lessonId': lessonId,
            'lessonTitle': lesson.title.trim(),
            'totalWords': safeTotalWords,
            'viewedWords': safeTotalWords,
            'completionPercentage':
                completed ? 100.0 : 0.0,
            'isCompleted': completed,
            'studyCount': studyCount,
            'firstStudiedAt': firstStudiedAt,
            'lastStudiedAt':
                FieldValue.serverTimestamp(),
            'completedAt': completed
                ? FieldValue.serverTimestamp()
                : null,
            'createdAt': createdAt,
            'updatedAt':
                FieldValue.serverTimestamp(),
          };

          transaction.set(
            documentReference,
            progressData,
            SetOptions(merge: true),
          );
        },
      );
    } on FirebaseException catch (error) {
      throw Exception(
        'Không thể hoàn thành bài học: ${error.code}',
      );
    }
  }

  /// Tăng số lần học khi người dùng chọn học lại.
  Future<void> incrementStudyCount(
    String lessonId,
  ) async {
    final User user = _requireCurrentUser();
    final String cleanLessonId = lessonId.trim();

    if (cleanLessonId.isEmpty) {
      throw ArgumentError(
        'ID bài học không được để trống.',
      );
    }

    final String documentId =
        _createProgressDocumentId(
      userId: user.uid,
      lessonId: cleanLessonId,
    );

    try {
      await _progressCollection.doc(documentId).set(
        <String, dynamic>{
          'userId': user.uid,
          'lessonId': cleanLessonId,
          'studyCount': FieldValue.increment(1),
          'lastStudiedAt':
              FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } on FirebaseException catch (error) {
      throw Exception(
        'Không thể cập nhật số lần học: ${error.code}',
      );
    }
  }

  /// Tính tổng quan tiến độ học tập.
  Future<Map<String, dynamic>>
      getProgressSummary() async {
    final User user = _requireCurrentUser();

    try {
      final QuerySnapshot<Map<String, dynamic>>
          snapshot =
          await _progressCollection
              .where(
                'userId',
                isEqualTo: user.uid,
              )
              .get();

      final List<LearningProgress> progressList =
          snapshot.docs
              .map(LearningProgress.fromFirestore)
              .toList();

      final int totalLessons =
          progressList.length;

      final int completedLessons =
          progressList.where(
        (LearningProgress progress) {
          return progress.isCompleted;
        },
      ).length;

      final int totalViewedWords =
          progressList.fold<int>(
        0,
        (
          int total,
          LearningProgress progress,
        ) {
          return total +
              progress.safeViewedWords;
        },
      );

      final double totalPercentage =
          progressList.fold<double>(
        0,
        (
          double total,
          LearningProgress progress,
        ) {
          return total +
              progress.safeCompletionPercentage;
        },
      );

      final double averagePercentage =
          totalLessons == 0
              ? 0
              : totalPercentage / totalLessons;

      return <String, dynamic>{
        'totalLessons': totalLessons,
        'completedLessons': completedLessons,
        'totalViewedWords': totalViewedWords,
        'averagePercentage': averagePercentage,
      };
    } on FirebaseException catch (error) {
      throw Exception(
        'Không thể tải tổng quan tiến độ: '
        '${error.code}',
      );
    }
  }

  /// Xóa tiến độ của một bài học.
  Future<void> deleteLessonProgress(
    String lessonId,
  ) async {
    final User user = _requireCurrentUser();
    final String cleanLessonId = lessonId.trim();

    if (cleanLessonId.isEmpty) {
      throw ArgumentError(
        'ID bài học không được để trống.',
      );
    }

    final String documentId =
        _createProgressDocumentId(
      userId: user.uid,
      lessonId: cleanLessonId,
    );

    try {
      await _progressCollection
          .doc(documentId)
          .delete();
    } on FirebaseException catch (error) {
      throw Exception(
        'Không thể xóa tiến độ bài học: '
        '${error.code}',
      );
    }
  }

  /// Chuyển dữ liệu Firestore thành số nguyên an toàn.
  int _parseInteger(
    dynamic value, {
    int defaultValue = 0,
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
}