import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/ai_recommendation.dart';
import '../models/learning_progress.dart';
import '../models/lesson.dart';
import '../models/quiz_result.dart';

/// Phân tích dữ liệu học tập và tạo gợi ý cá nhân hóa.
///
/// Phương pháp sử dụng:
/// - Rule-based: áp dụng các luật dựa trên điểm kiểm tra
///   và phần trăm hoàn thành bài học.
/// - Content-based: đề xuất trực tiếp bài học tương ứng
///   với kết quả và tiến độ của người dùng.
///
/// Các collection được sử dụng:
/// - lessons
/// - learning_progress
/// - quiz_results
/// - ai_recommendations
class AiRecommendationService {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>>
      get _lessonsCollection {
    return _firestore.collection('lessons');
  }

  CollectionReference<Map<String, dynamic>>
      get _progressCollection {
    return _firestore.collection('learning_progress');
  }

  CollectionReference<Map<String, dynamic>>
      get _quizResultsCollection {
    return _firestore.collection('quiz_results');
  }

  CollectionReference<Map<String, dynamic>>
      get _recommendationsCollection {
    return _firestore.collection('ai_recommendations');
  }

  /// Lấy tài khoản hiện đang đăng nhập.
  User _requireCurrentUser() {
    final User? user = _auth.currentUser;

    if (user == null) {
      throw StateError(
        'Bạn cần đăng nhập để nhận gợi ý học tập.',
      );
    }

    return user;
  }

  /// Phân tích toàn bộ dữ liệu và tạo danh sách gợi ý.
  ///
  /// Kết quả được sắp xếp theo priorityScore giảm dần.
  Future<List<AiRecommendation>>
      generateRecommendations() async {
    final User user = _requireCurrentUser();

    try {
      final List<dynamic> queryResults =
          await Future.wait<dynamic>([
        _lessonsCollection.get(),
        _progressCollection
            .where(
              'userId',
              isEqualTo: user.uid,
            )
            .get(),
        _quizResultsCollection
            .where(
              'userId',
              isEqualTo: user.uid,
            )
            .get(),
      ]);

      final QuerySnapshot<Map<String, dynamic>>
          lessonSnapshot =
          queryResults[0]
              as QuerySnapshot<Map<String, dynamic>>;

      final QuerySnapshot<Map<String, dynamic>>
          progressSnapshot =
          queryResults[1]
              as QuerySnapshot<Map<String, dynamic>>;

      final QuerySnapshot<Map<String, dynamic>>
          resultSnapshot =
          queryResults[2]
              as QuerySnapshot<Map<String, dynamic>>;

      final List<Lesson> lessons = lessonSnapshot.docs
          .map(Lesson.fromFirestore)
          .where(
            (Lesson lesson) => lesson.isActive,
          )
          .toList();

      lessons.sort(
        (Lesson first, Lesson second) {
          return first.order.compareTo(second.order);
        },
      );

      final List<LearningProgress> progressList =
          progressSnapshot.docs
              .map(LearningProgress.fromFirestore)
              .toList();

      final List<QuizResult> quizResults =
          resultSnapshot.docs
              .map(QuizResult.fromFirestore)
              .toList();

      final Map<String, LearningProgress> progressByLesson =
          <String, LearningProgress>{};

      for (final LearningProgress progress
          in progressList) {
        progressByLesson[progress.lessonId] = progress;
      }

      final Map<String, List<QuizResult>>
          resultsByLesson =
          <String, List<QuizResult>>{};

      for (final QuizResult result in quizResults) {
        resultsByLesson
            .putIfAbsent(
              result.lessonId,
              () => <QuizResult>[],
            )
            .add(result);
      }

      final List<AiRecommendation> recommendations =
          <AiRecommendation>[];

      for (final Lesson lesson in lessons) {
        final LearningProgress? progress =
            progressByLesson[lesson.id];

        final List<QuizResult> lessonResults =
            resultsByLesson[lesson.id] ??
                <QuizResult>[];

        final AiRecommendation recommendation =
            _analyzeLesson(
          userId: user.uid,
          lesson: lesson,
          progress: progress,
          quizResults: lessonResults,
        );

        recommendations.add(recommendation);
      }

      recommendations.sort(
        (
          AiRecommendation first,
          AiRecommendation second,
        ) {
          final int priorityComparison =
              second.safePriorityScore.compareTo(
            first.safePriorityScore,
          );

          if (priorityComparison != 0) {
            return priorityComparison;
          }

          return first.lessonTitle.compareTo(
            second.lessonTitle,
          );
        },
      );

      await _saveRecommendations(
        userId: user.uid,
        recommendations: recommendations,
      );

      return recommendations;
    } on FirebaseException catch (error) {
      throw Exception(
        'Không thể phân tích dữ liệu học tập: '
        '${error.code}',
      );
    }
  }

  /// Phân tích một bài học và tạo một gợi ý phù hợp.
  AiRecommendation _analyzeLesson({
    required String userId,
    required Lesson lesson,
    required LearningProgress? progress,
    required List<QuizResult> quizResults,
  }) {
    final List<QuizResult> sortedResults =
        List<QuizResult>.from(quizResults);

    sortedResults.sort(
      (
        QuizResult first,
        QuizResult second,
      ) {
        final DateTime firstDate =
            first.completedAt ??
                first.createdAt ??
                DateTime.fromMillisecondsSinceEpoch(0);

        final DateTime secondDate =
            second.completedAt ??
                second.createdAt ??
                DateTime.fromMillisecondsSinceEpoch(0);

        return secondDate.compareTo(firstDate);
      },
    );

    final bool hasQuizResult =
        sortedResults.isNotEmpty;

    final QuizResult? latestResult =
        hasQuizResult ? sortedResults.first : null;

    double bestQuizScore = 0;

    for (final QuizResult result in sortedResults) {
      if (result.safeScorePercentage >
          bestQuizScore) {
        bestQuizScore =
            result.safeScorePercentage;
      }
    }

    final double latestQuizScore =
        latestResult?.safeScorePercentage ?? 0;

    final int incorrectAnswers =
        latestResult?.safeIncorrectAnswers ?? 0;

    final int quizAttempts = sortedResults.length;

    final double learningProgress =
        progress?.safeCompletionPercentage ?? 0;

    final bool isLessonCompleted =
        progress?.isCompleted ?? false;

    final _RecommendationDecision decision =
        _createDecision(
      hasProgress: progress != null,
      learningProgress: learningProgress,
      isLessonCompleted: isLessonCompleted,
      hasQuizResult: hasQuizResult,
      latestQuizScore: latestQuizScore,
      bestQuizScore: bestQuizScore,
      incorrectAnswers: incorrectAnswers,
      quizAttempts: quizAttempts,
    );

    return AiRecommendation(
      id: AiRecommendation.createDocumentId(
        userId: userId,
        lessonId: lesson.id,
      ),
      userId: userId,
      lessonId: lesson.id,
      lessonTitle: lesson.title,
      type: decision.type,
      reason: decision.reason,
      suggestedAction: decision.suggestedAction,
      priorityScore: decision.priorityScore,
      latestQuizScore: latestQuizScore,
      bestQuizScore: bestQuizScore,
      learningProgress: learningProgress,
      incorrectAnswers: incorrectAnswers,
      quizAttempts: quizAttempts,
      hasQuizResult: hasQuizResult,
      isLessonCompleted: isLessonCompleted,
      generatedAt: DateTime.now(),
    );
  }

  /// Áp dụng bộ luật để quyết định loại gợi ý.
  _RecommendationDecision _createDecision({
    required bool hasProgress,
    required double learningProgress,
    required bool isLessonCompleted,
    required bool hasQuizResult,
    required double latestQuizScore,
    required double bestQuizScore,
    required int incorrectAnswers,
    required int quizAttempts,
  }) {
    // Luật 1:
    // Điểm gần nhất dưới 50% là trường hợp ưu tiên cao nhất.
    if (hasQuizResult && latestQuizScore < 50) {
      final int priority =
          _clampPriority(
        95 + incorrectAnswers,
      );

      return _RecommendationDecision(
        type: RecommendationType.relearn,
        reason:
            'Điểm kiểm tra gần nhất của bạn là '
            '${latestQuizScore.round()}%, dưới mức đạt 50%. '
            'Bạn còn $incorrectAnswers câu chưa trả lời đúng.',
        suggestedAction:
            'Học lại từ vựng của bài này, xem kỹ các ví dụ '
            'và thực hiện lại bài kiểm tra.',
        priorityScore: priority,
      );
    }

    // Luật 2:
    // Đạt 50-69% nhưng kiến thức chưa vững.
    if (hasQuizResult &&
        latestQuizScore >= 50 &&
        latestQuizScore < 70) {
      final int priority = _clampPriority(
        85 + incorrectAnswers,
      );

      return _RecommendationDecision(
        type: RecommendationType.review,
        reason:
            'Điểm kiểm tra gần nhất là '
            '${latestQuizScore.round()}%. Bạn đã đạt nhưng '
            'vẫn còn $incorrectAnswers câu trả lời sai.',
        suggestedAction:
            'Ôn lại các từ vựng và câu ví dụ trước khi '
            'làm lại bài kiểm tra.',
        priorityScore: priority,
      );
    }

    // Luật 3:
    // Điểm 70-89% cần luyện thêm để củng cố.
    if (hasQuizResult &&
        latestQuizScore >= 70 &&
        latestQuizScore < 90) {
      final int priority = _clampPriority(
        70 + incorrectAnswers,
      );

      return _RecommendationDecision(
        type: RecommendationType.practice,
        reason:
            'Điểm gần nhất của bạn là '
            '${latestQuizScore.round()}%. Kết quả khá tốt '
            'nhưng vẫn có thể cải thiện thêm.',
        suggestedAction:
            'Luyện lại các câu đã sai và thử làm bài '
            'kiểm tra thêm một lần để đạt từ 90%.',
        priorityScore: priority,
      );
    }

    // Luật 4:
    // Đã học bài nhưng chưa hoàn thành.
    if (hasProgress &&
        !isLessonCompleted &&
        learningProgress < 100) {
      final int remainingPercentage =
          (100 - learningProgress).round();

      final int priority = _clampPriority(
        75 + (remainingPercentage / 5).round(),
      );

      return _RecommendationDecision(
        type: RecommendationType.completeLesson,
        reason:
            'Bạn mới hoàn thành '
            '${learningProgress.round()}% bài học này.',
        suggestedAction:
            'Tiếp tục học phần còn lại để hoàn thành '
            '100% nội dung trước khi kiểm tra.',
        priorityScore: priority,
      );
    }

    // Luật 5:
    // Đã hoàn thành bài học nhưng chưa kiểm tra.
    if (isLessonCompleted && !hasQuizResult) {
      return const _RecommendationDecision(
        type: RecommendationType.takeQuiz,
        reason:
            'Bạn đã hoàn thành bài học nhưng chưa có '
            'kết quả kiểm tra cho chủ đề này.',
        suggestedAction:
            'Làm bài kiểm tra để đánh giá mức độ ghi nhớ '
            'và giúp hệ thống phân tích chính xác hơn.',
        priorityScore: 78,
      );
    }

    // Luật 6:
    // Chưa học và chưa kiểm tra.
    if (!hasProgress && !hasQuizResult) {
      return const _RecommendationDecision(
        type: RecommendationType.continueLearning,
        reason:
            'Bạn chưa bắt đầu học chủ đề này.',
        suggestedAction:
            'Mở bài học, học các từ vựng theo thứ tự '
            'và hoàn thành bài kiểm tra sau đó.',
        priorityScore: 60,
      );
    }

    // Luật 7:
    // Có kết quả kiểm tra nhưng bài học chưa hoàn thành.
    if (hasQuizResult && !isLessonCompleted) {
      return _RecommendationDecision(
        type: RecommendationType.completeLesson,
        reason:
            'Bạn đã làm bài kiểm tra nhưng tiến độ bài học '
            'mới đạt ${learningProgress.round()}%.',
        suggestedAction:
            'Hoàn thành toàn bộ nội dung bài học để củng cố '
            'kiến thức còn thiếu.',
        priorityScore: 72,
      );
    }

    // Luật 8:
    // Điểm gần nhất từ 90% trở lên.
    if (hasQuizResult && latestQuizScore >= 90) {
      final String improvementMessage =
          bestQuizScore > latestQuizScore
              ? 'Điểm cao nhất trước đây của bạn là '
                  '${bestQuizScore.round()}%.'
              : 'Đây là kết quả rất tốt sau '
                  '$quizAttempts lần làm bài.';

      return _RecommendationDecision(
        type: RecommendationType.continueLearning,
        reason:
            'Điểm kiểm tra gần nhất là '
            '${latestQuizScore.round()}%. '
            '$improvementMessage',
        suggestedAction:
            'Bạn đã nắm khá vững chủ đề này. Hãy chuyển '
            'sang bài học khác hoặc ôn lại định kỳ.',
        priorityScore: 35,
      );
    }

    return const _RecommendationDecision(
      type: RecommendationType.continueLearning,
      reason:
          'Hệ thống chưa phát hiện điểm yếu nghiêm trọng '
          'trong chủ đề này.',
      suggestedAction:
          'Tiếp tục duy trì việc học và kiểm tra định kỳ.',
      priorityScore: 40,
    );
  }

  /// Lưu danh sách gợi ý mới vào Firestore.
  ///
  /// Mỗi người dùng chỉ có một gợi ý hiện tại
  /// cho mỗi bài học.
  Future<void> _saveRecommendations({
    required String userId,
    required List<AiRecommendation> recommendations,
  }) async {
    if (recommendations.isEmpty) {
      return;
    }

    const int batchLimit = 450;

    for (
      int startIndex = 0;
      startIndex < recommendations.length;
      startIndex += batchLimit
    ) {
      final int endIndex =
          startIndex + batchLimit >
                  recommendations.length
              ? recommendations.length
              : startIndex + batchLimit;

      final WriteBatch batch = _firestore.batch();

      for (
        int index = startIndex;
        index < endIndex;
        index++
      ) {
        final AiRecommendation recommendation =
            recommendations[index];

        final DocumentReference<Map<String, dynamic>>
            document = _recommendationsCollection.doc(
          recommendation.id,
        );

        batch.set(
          document,
          recommendation.toMap(),
          SetOptions(merge: true),
        );
      }

      await batch.commit();
    }

    await _removeObsoleteRecommendations(
      userId: userId,
      currentRecommendations: recommendations,
    );
  }

  /// Xóa các gợi ý cũ không còn tương ứng với bài học hiện tại.
  Future<void> _removeObsoleteRecommendations({
    required String userId,
    required List<AiRecommendation>
        currentRecommendations,
  }) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot =
        await _recommendationsCollection
            .where(
              'userId',
              isEqualTo: userId,
            )
            .get();

    final Set<String> currentIds = currentRecommendations
        .map(
          (AiRecommendation recommendation) =>
              recommendation.id,
        )
        .toSet();

    final List<DocumentReference<Map<String, dynamic>>>
        obsoleteDocuments =
        <DocumentReference<Map<String, dynamic>>>[];

    for (final QueryDocumentSnapshot<
        Map<String, dynamic>> document
        in snapshot.docs) {
      if (!currentIds.contains(document.id)) {
        obsoleteDocuments.add(document.reference);
      }
    }

    if (obsoleteDocuments.isEmpty) {
      return;
    }

    const int batchLimit = 450;

    for (
      int startIndex = 0;
      startIndex < obsoleteDocuments.length;
      startIndex += batchLimit
    ) {
      final int endIndex =
          startIndex + batchLimit >
                  obsoleteDocuments.length
              ? obsoleteDocuments.length
              : startIndex + batchLimit;

      final WriteBatch batch = _firestore.batch();

      for (
        int index = startIndex;
        index < endIndex;
        index++
      ) {
        batch.delete(obsoleteDocuments[index]);
      }

      await batch.commit();
    }
  }

  /// Theo dõi các gợi ý đã được lưu của người dùng hiện tại.
  ///
  /// Danh sách được sắp xếp trong Flutter để không cần
  /// composite index.
  Stream<List<AiRecommendation>>
      getCurrentUserRecommendations() {
    final User? user = _auth.currentUser;

    if (user == null) {
      return Stream<List<AiRecommendation>>.value(
        <AiRecommendation>[],
      );
    }

    return _recommendationsCollection
        .where(
          'userId',
          isEqualTo: user.uid,
        )
        .snapshots()
        .map(
      (
        QuerySnapshot<Map<String, dynamic>> snapshot,
      ) {
        final List<AiRecommendation> recommendations =
            snapshot.docs
                .map(
                  AiRecommendation.fromFirestore,
                )
                .where(
                  (AiRecommendation recommendation) =>
                      recommendation.isValid,
                )
                .toList();

        recommendations.sort(
          (
            AiRecommendation first,
            AiRecommendation second,
          ) {
            return second.safePriorityScore.compareTo(
              first.safePriorityScore,
            );
          },
        );

        return recommendations;
      },
    );
  }

  /// Lấy danh sách gợi ý một lần.
  Future<List<AiRecommendation>>
      getCurrentUserRecommendationsOnce() async {
    final User user = _requireCurrentUser();

    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot =
          await _recommendationsCollection
              .where(
                'userId',
                isEqualTo: user.uid,
              )
              .get();

      final List<AiRecommendation> recommendations =
          snapshot.docs
              .map(
                AiRecommendation.fromFirestore,
              )
              .where(
                (AiRecommendation recommendation) =>
                    recommendation.isValid,
              )
              .toList();

      recommendations.sort(
        (
          AiRecommendation first,
          AiRecommendation second,
        ) {
          return second.safePriorityScore.compareTo(
            first.safePriorityScore,
          );
        },
      );

      return recommendations;
    } on FirebaseException catch (error) {
      throw Exception(
        'Không thể tải gợi ý học tập: ${error.code}',
      );
    }
  }

  /// Lấy gợi ý có mức ưu tiên cao nhất.
  ///
  /// Trả về null nếu chưa có gợi ý.
  Future<AiRecommendation?>
      getTopRecommendation() async {
    List<AiRecommendation> recommendations =
        await getCurrentUserRecommendationsOnce();

    if (recommendations.isEmpty) {
      recommendations =
          await generateRecommendations();
    }

    if (recommendations.isEmpty) {
      return null;
    }

    return recommendations.first;
  }

  /// Xóa toàn bộ gợi ý của người dùng hiện tại.
  Future<void> deleteCurrentUserRecommendations() async {
    final User user = _requireCurrentUser();

    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot =
          await _recommendationsCollection
              .where(
                'userId',
                isEqualTo: user.uid,
              )
              .get();

      if (snapshot.docs.isEmpty) {
        return;
      }

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
        'Không thể xóa gợi ý học tập: ${error.code}',
      );
    }
  }

  int _clampPriority(int priority) {
    if (priority < 0) {
      return 0;
    }

    if (priority > 100) {
      return 100;
    }

    return priority;
  }
}

/// Kết quả nội bộ của quá trình áp dụng luật.
///
/// Class này chỉ được sử dụng bên trong service,
/// không được lưu trực tiếp vào Firestore.
class _RecommendationDecision {
  final RecommendationType type;
  final String reason;
  final String suggestedAction;
  final int priorityScore;

  const _RecommendationDecision({
    required this.type,
    required this.reason,
    required this.suggestedAction,
    required this.priorityScore,
  });
}