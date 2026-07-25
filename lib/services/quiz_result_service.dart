import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/lesson.dart';
import '../models/quiz_question.dart';
import '../models/quiz_result.dart';

/// Quản lý kết quả bài kiểm tra trên Firebase Firestore.
///
/// Collection sử dụng: quiz_results
///
/// Mỗi lần người dùng nộp bài sẽ tạo một document kết quả mới,
/// giúp lưu được toàn bộ lịch sử làm bài.
class QuizResultService {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>>
      get _resultsCollection {
    return _firestore.collection('quiz_results');
  }

  /// Lấy người dùng đang đăng nhập.
  ///
  /// Nếu chưa đăng nhập, hàm sẽ phát sinh lỗi.
  User _requireCurrentUser() {
    final User? user = _auth.currentUser;

    if (user == null) {
      throw StateError(
        'Bạn cần đăng nhập để lưu kết quả kiểm tra.',
      );
    }

    return user;
  }

  /// Lưu kết quả một lần làm bài kiểm tra.
  ///
  /// selectedAnswers có cấu trúc:
  ///
  /// questionId -> chỉ số đáp án người dùng đã chọn
  ///
  /// Hàm sẽ tự:
  /// - Tính số câu đúng.
  /// - Tính số câu sai.
  /// - Tính phần trăm điểm.
  /// - Xác định đạt hoặc chưa đạt.
  /// - Tính số lần làm bài.
  /// - Lưu danh sách câu trả lời sai.
  ///
  /// Trả về QuizResult vừa được lưu.
  Future<QuizResult> saveQuizResult({
    required Lesson lesson,
    required List<QuizQuestion> questions,
    required Map<String, int> selectedAnswers,
    required DateTime startedAt,
  }) async {
    final User user = _requireCurrentUser();

    final String lessonId = lesson.id.trim();

    if (lessonId.isEmpty) {
      throw ArgumentError(
        'ID bài học không được để trống.',
      );
    }

    if (questions.isEmpty) {
      throw ArgumentError(
        'Bài kiểm tra phải có ít nhất một câu hỏi.',
      );
    }

    int correctAnswers = 0;

    final List<String> incorrectQuestionIds =
        <String>[];

    for (final QuizQuestion question in questions) {
      final int? selectedAnswerIndex =
          selectedAnswers[question.id];

      if (selectedAnswerIndex != null &&
          question.isCorrectAnswer(
            selectedAnswerIndex,
          )) {
        correctAnswers++;
      } else {
        incorrectQuestionIds.add(question.id);
      }
    }

    final int totalQuestions = questions.length;

    final int incorrectAnswers =
        totalQuestions - correctAnswers;

    final double scorePercentage =
        QuizResult.calculateScorePercentage(
      correctAnswers: correctAnswers,
      totalQuestions: totalQuestions,
    );

    final bool isPassed =
        QuizResult.calculateIsPassed(
      scorePercentage: scorePercentage,
    );

    try {
      final int attemptNumber =
          await _getNextAttemptNumber(
        userId: user.uid,
        lessonId: lessonId,
      );

      final DateTime completedAt = DateTime.now();

      final DocumentReference<Map<String, dynamic>>
          document = _resultsCollection.doc();

      final QuizResult result = QuizResult(
        id: document.id,
        userId: user.uid,
        lessonId: lessonId,
        lessonTitle: lesson.title.trim(),
        totalQuestions: totalQuestions,
        correctAnswers: correctAnswers,
        incorrectAnswers: incorrectAnswers,
        scorePercentage: scorePercentage,
        isPassed: isPassed,
        attemptNumber: attemptNumber,
        selectedAnswers:
            Map<String, int>.from(selectedAnswers),
        incorrectQuestionIds:
            List<String>.from(
          incorrectQuestionIds,
        ),
        startedAt: startedAt,
        completedAt: completedAt,
        createdAt: completedAt,
        updatedAt: completedAt,
      );

      await document.set(result.toMap());

      return result;
    } on FirebaseException catch (error) {
      throw Exception(
        'Không thể lưu kết quả kiểm tra: ${error.code}',
      );
    }
  }

  /// Tính số lần làm bài tiếp theo của người dùng
  /// đối với một bài học.
  ///
  /// Dữ liệu được lọc theo userId trên Firestore,
  /// sau đó lọc lessonId trong Flutter để không cần
  /// tạo composite index.
  Future<int> _getNextAttemptNumber({
    required String userId,
    required String lessonId,
  }) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot =
        await _resultsCollection
            .where(
              'userId',
              isEqualTo: userId,
            )
            .get();

    int highestAttemptNumber = 0;

    for (final QueryDocumentSnapshot<
        Map<String, dynamic>> document
        in snapshot.docs) {
      final Map<String, dynamic> data =
          document.data();

      final String resultLessonId =
          data['lessonId'] as String? ?? '';

      if (resultLessonId != lessonId) {
        continue;
      }

      final int attemptNumber = _parseInteger(
        data['attemptNumber'],
        defaultValue: 0,
      );

      if (attemptNumber > highestAttemptNumber) {
        highestAttemptNumber = attemptNumber;
      }
    }

    return highestAttemptNumber + 1;
  }

  /// Theo dõi toàn bộ lịch sử kiểm tra
  /// của người dùng hiện tại.
  ///
  /// Kết quả được sắp xếp theo thời gian hoàn thành mới nhất
  /// ngay trong Flutter để không cần composite index.
  Stream<List<QuizResult>> getCurrentUserResults() {
    final User? user = _auth.currentUser;

    if (user == null) {
      return Stream<List<QuizResult>>.value(
        <QuizResult>[],
      );
    }

    return _resultsCollection
        .where(
          'userId',
          isEqualTo: user.uid,
        )
        .snapshots()
        .map(
      (
        QuerySnapshot<Map<String, dynamic>> snapshot,
      ) {
        final List<QuizResult> results = snapshot.docs
            .map(QuizResult.fromFirestore)
            .toList();

        results.sort(
          (
            QuizResult firstResult,
            QuizResult secondResult,
          ) {
            final DateTime firstDate =
                firstResult.completedAt ??
                    firstResult.createdAt ??
                    DateTime.fromMillisecondsSinceEpoch(
                      0,
                    );

            final DateTime secondDate =
                secondResult.completedAt ??
                    secondResult.createdAt ??
                    DateTime.fromMillisecondsSinceEpoch(
                      0,
                    );

            return secondDate.compareTo(firstDate);
          },
        );

        return results;
      },
    );
  }

  /// Theo dõi lịch sử kiểm tra của một bài học.
  ///
  /// Firestore chỉ lọc theo userId.
  /// lessonId được lọc trong Flutter để tránh composite index.
  Stream<List<QuizResult>> getResultsByLesson(
    String lessonId,
  ) {
    final User? user = _auth.currentUser;
    final String cleanLessonId = lessonId.trim();

    if (user == null || cleanLessonId.isEmpty) {
      return Stream<List<QuizResult>>.value(
        <QuizResult>[],
      );
    }

    return _resultsCollection
        .where(
          'userId',
          isEqualTo: user.uid,
        )
        .snapshots()
        .map(
      (
        QuerySnapshot<Map<String, dynamic>> snapshot,
      ) {
        final List<QuizResult> results = snapshot.docs
            .map(QuizResult.fromFirestore)
            .where(
              (QuizResult result) =>
                  result.lessonId == cleanLessonId,
            )
            .toList();

        results.sort(
          (
            QuizResult firstResult,
            QuizResult secondResult,
          ) {
            return secondResult.attemptNumber.compareTo(
              firstResult.attemptNumber,
            );
          },
        );

        return results;
      },
    );
  }

  /// Lấy lịch sử kết quả của người dùng một lần.
  Future<List<QuizResult>>
      getCurrentUserResultsOnce() async {
    final User user = _requireCurrentUser();

    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot =
          await _resultsCollection
              .where(
                'userId',
                isEqualTo: user.uid,
              )
              .get();

      final List<QuizResult> results = snapshot.docs
          .map(QuizResult.fromFirestore)
          .toList();

      results.sort(
        (
          QuizResult firstResult,
          QuizResult secondResult,
        ) {
          final DateTime firstDate =
              firstResult.completedAt ??
                  firstResult.createdAt ??
                  DateTime.fromMillisecondsSinceEpoch(0);

          final DateTime secondDate =
              secondResult.completedAt ??
                  secondResult.createdAt ??
                  DateTime.fromMillisecondsSinceEpoch(0);

          return secondDate.compareTo(firstDate);
        },
      );

      return results;
    } on FirebaseException catch (error) {
      throw Exception(
        'Không thể tải lịch sử kiểm tra: ${error.code}',
      );
    }
  }

  /// Lấy kết quả gần nhất của một bài học.
  ///
  /// Trả về null nếu người dùng chưa từng làm bài.
  Future<QuizResult?> getLatestResultByLesson(
    String lessonId,
  ) async {
    final String cleanLessonId = lessonId.trim();

    if (cleanLessonId.isEmpty) {
      throw ArgumentError(
        'ID bài học không được để trống.',
      );
    }

    final List<QuizResult> results =
        await getCurrentUserResultsOnce();

    final List<QuizResult> lessonResults = results
        .where(
          (QuizResult result) =>
              result.lessonId == cleanLessonId,
        )
        .toList();

    if (lessonResults.isEmpty) {
      return null;
    }

    lessonResults.sort(
      (
        QuizResult firstResult,
        QuizResult secondResult,
      ) {
        return secondResult.attemptNumber.compareTo(
          firstResult.attemptNumber,
        );
      },
    );

    return lessonResults.first;
  }

  /// Lấy kết quả có điểm cao nhất của một bài học.
  ///
  /// Trả về null nếu chưa có kết quả.
  Future<QuizResult?> getBestResultByLesson(
    String lessonId,
  ) async {
    final String cleanLessonId = lessonId.trim();

    if (cleanLessonId.isEmpty) {
      throw ArgumentError(
        'ID bài học không được để trống.',
      );
    }

    final List<QuizResult> results =
        await getCurrentUserResultsOnce();

    final List<QuizResult> lessonResults = results
        .where(
          (QuizResult result) =>
              result.lessonId == cleanLessonId,
        )
        .toList();

    if (lessonResults.isEmpty) {
      return null;
    }

    lessonResults.sort(
      (
        QuizResult firstResult,
        QuizResult secondResult,
      ) {
        final int scoreComparison =
            secondResult.safeScorePercentage.compareTo(
          firstResult.safeScorePercentage,
        );

        if (scoreComparison != 0) {
          return scoreComparison;
        }

        return secondResult.attemptNumber.compareTo(
          firstResult.attemptNumber,
        );
      },
    );

    return lessonResults.first;
  }

  /// Tính tổng quan kết quả kiểm tra của người dùng.
  ///
  /// Kết quả gồm:
  /// - totalAttempts: tổng số lần làm bài.
  /// - passedAttempts: số lượt đạt.
  /// - failedAttempts: số lượt chưa đạt.
  /// - averageScore: điểm trung bình.
  /// - bestScore: điểm cao nhất.
  /// - totalCorrectAnswers: tổng số câu đúng.
  /// - totalIncorrectAnswers: tổng số câu sai.
  Future<Map<String, dynamic>>
      getQuizResultSummary() async {
    final List<QuizResult> results =
        await getCurrentUserResultsOnce();

    final int totalAttempts = results.length;

    final int passedAttempts = results
        .where(
          (QuizResult result) => result.isPassed,
        )
        .length;

    final int failedAttempts =
        totalAttempts - passedAttempts;

    final int totalCorrectAnswers =
        results.fold<int>(
      0,
      (
        int total,
        QuizResult result,
      ) {
        return total + result.safeCorrectAnswers;
      },
    );

    final int totalIncorrectAnswers =
        results.fold<int>(
      0,
      (
        int total,
        QuizResult result,
      ) {
        return total + result.safeIncorrectAnswers;
      },
    );

    final double totalScore =
        results.fold<double>(
      0,
      (
        double total,
        QuizResult result,
      ) {
        return total + result.safeScorePercentage;
      },
    );

    final double averageScore = totalAttempts == 0
        ? 0
        : totalScore / totalAttempts;

    double bestScore = 0;

    for (final QuizResult result in results) {
      if (result.safeScorePercentage > bestScore) {
        bestScore = result.safeScorePercentage;
      }
    }

    return <String, dynamic>{
      'totalAttempts': totalAttempts,
      'passedAttempts': passedAttempts,
      'failedAttempts': failedAttempts,
      'averageScore': averageScore,
      'bestScore': bestScore,
      'totalCorrectAnswers': totalCorrectAnswers,
      'totalIncorrectAnswers': totalIncorrectAnswers,
    };
  }

  /// Xóa một kết quả kiểm tra theo ID.
  Future<void> deleteQuizResult(
    String resultId,
  ) async {
    _requireCurrentUser();

    final String cleanResultId = resultId.trim();

    if (cleanResultId.isEmpty) {
      throw ArgumentError(
        'ID kết quả không được để trống.',
      );
    }

    try {
      final DocumentSnapshot<Map<String, dynamic>>
          document =
          await _resultsCollection
              .doc(cleanResultId)
              .get();

      if (!document.exists) {
        return;
      }

      final Map<String, dynamic> data =
          document.data() ?? <String, dynamic>{};

      final String resultUserId =
          data['userId'] as String? ?? '';

      if (resultUserId != _auth.currentUser?.uid) {
        throw StateError(
          'Bạn không có quyền xóa kết quả này.',
        );
      }

      await _resultsCollection
          .doc(cleanResultId)
          .delete();
    } on FirebaseException catch (error) {
      throw Exception(
        'Không thể xóa kết quả kiểm tra: ${error.code}',
      );
    }
  }

  /// Xóa toàn bộ lịch sử kiểm tra của người dùng hiện tại.
  Future<void> deleteAllCurrentUserResults() async {
    final User user = _requireCurrentUser();

    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot =
          await _resultsCollection
              .where(
                'userId',
                isEqualTo: user.uid,
              )
              .get();

      if (snapshot.docs.isEmpty) {
        return;
      }

      // Firestore batch hỗ trợ tối đa 500 thao tác.
      // Với quy mô đồ án, số kết quả thường nhỏ hơn giới hạn này.
      const int batchLimit = 450;

      for (
        int startIndex = 0;
        startIndex < snapshot.docs.length;
        startIndex += batchLimit
      ) {
        final int endIndex =
            startIndex + batchLimit >
                    snapshot.docs.length
                ? snapshot.docs.length
                : startIndex + batchLimit;

        final WriteBatch batch = _firestore.batch();

        for (
          int index = startIndex;
          index < endIndex;
          index++
        ) {
          batch.delete(
            snapshot.docs[index].reference,
          );
        }

        await batch.commit();
      }
    } on FirebaseException catch (error) {
      throw Exception(
        'Không thể xóa lịch sử kiểm tra: ${error.code}',
      );
    }
  }

  /// Chuyển dữ liệu Firestore thành int an toàn.
  int _parseInteger(
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
}