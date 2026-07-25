import 'package:flutter/material.dart';

import '../models/ai_recommendation.dart';
import '../models/lesson.dart';
import '../models/quiz_question.dart';
import '../services/ai_recommendation_service.dart';
import '../services/lesson_service.dart';
import '../services/quiz_service.dart';
import 'lesson_detail_screen.dart';
import 'quiz_screen.dart';

class AiRecommendationScreen extends StatefulWidget {
  const AiRecommendationScreen({super.key});

  @override
  State<AiRecommendationScreen> createState() =>
      _AiRecommendationScreenState();
}

class _AiRecommendationScreenState
    extends State<AiRecommendationScreen> {
  final AiRecommendationService
      _recommendationService =
      AiRecommendationService();

  final LessonService _lessonService =
      LessonService();

  final QuizService _quizService = QuizService();

  bool _isGenerating = true;
  String? _errorMessage;
  String? _processingLessonId;

  List<AiRecommendation> _recommendations =
      <AiRecommendation>[];

  @override
  void initState() {
    super.initState();
    _generateRecommendations();
  }

  Future<void> _generateRecommendations() async {
    if (mounted) {
      setState(() {
        _isGenerating = true;
        _errorMessage = null;
      });
    }

    try {
      final List<AiRecommendation> recommendations =
          await _recommendationService
              .generateRecommendations();

      if (!mounted) {
        return;
      }

      setState(() {
        _recommendations = recommendations;
        _isGenerating = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isGenerating = false;
        _errorMessage = error.toString();
      });
    }
  }

  IconData _getRecommendationIcon(
    RecommendationType type,
  ) {
    switch (type) {
      case RecommendationType.relearn:
        return Icons.restart_alt_rounded;

      case RecommendationType.review:
        return Icons.history_edu_rounded;

      case RecommendationType.practice:
        return Icons.fitness_center_rounded;

      case RecommendationType.completeLesson:
        return Icons.menu_book_rounded;

      case RecommendationType.takeQuiz:
        return Icons.quiz_rounded;

      case RecommendationType.continueLearning:
        return Icons.trending_up_rounded;
    }
  }

  Color _getRecommendationColor(
    AiRecommendation recommendation,
  ) {
    return Color(recommendation.colorValue);
  }

  String _getActionButtonLabel(
    RecommendationType type,
  ) {
    switch (type) {
      case RecommendationType.relearn:
        return 'Học lại';

      case RecommendationType.review:
        return 'Ôn bài';

      case RecommendationType.practice:
        return 'Làm kiểm tra';

      case RecommendationType.completeLesson:
        return 'Tiếp tục học';

      case RecommendationType.takeQuiz:
        return 'Làm kiểm tra';

      case RecommendationType.continueLearning:
        return 'Mở bài học';
    }
  }

  IconData _getActionButtonIcon(
    RecommendationType type,
  ) {
    switch (type) {
      case RecommendationType.practice:
      case RecommendationType.takeQuiz:
        return Icons.quiz_rounded;

      case RecommendationType.relearn:
        return Icons.replay_rounded;

      case RecommendationType.review:
        return Icons.auto_stories_rounded;

      case RecommendationType.completeLesson:
        return Icons.play_arrow_rounded;

      case RecommendationType.continueLearning:
        return Icons.menu_book_rounded;
    }
  }

  bool _shouldOpenQuiz(
    RecommendationType type,
  ) {
    return type == RecommendationType.practice ||
        type == RecommendationType.takeQuiz;
  }

  Future<void> _performRecommendationAction(
    AiRecommendation recommendation,
  ) async {
    if (_processingLessonId != null) {
      return;
    }

    setState(() {
      _processingLessonId = recommendation.lessonId;
    });

    try {
      final Lesson? lesson =
          await _lessonService.getLessonById(
        recommendation.lessonId,
      );

      if (!mounted) {
        return;
      }

      if (lesson == null) {
        setState(() {
          _processingLessonId = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Không tìm thấy bài học được đề xuất.',
            ),
            backgroundColor: Colors.red,
          ),
        );

        return;
      }

      if (_shouldOpenQuiz(recommendation.type)) {
        await _openQuiz(lesson);
      } else {
        await _openLesson(lesson);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _processingLessonId = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Không thể mở nội dung được đề xuất: $error',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _openLesson(Lesson lesson) async {
    if (mounted) {
      setState(() {
        _processingLessonId = null;
      });
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return LessonDetailScreen(
            lesson: lesson,
          );
        },
      ),
    );

    if (!mounted) {
      return;
    }

    await _generateRecommendations();
  }

  Future<void> _openQuiz(Lesson lesson) async {
    try {
      await _quizService.createSampleQuestions(
        lesson,
      );

      final List<QuizQuestion> questions =
          await _quizService.getQuestionsByLesson(
        lesson.id,
      );

      final List<QuizQuestion> activeQuestions =
          questions
              .where(
                (QuizQuestion question) =>
                    question.isActive &&
                    question.isValid,
              )
              .toList();

      activeQuestions.sort(
        (
          QuizQuestion firstQuestion,
          QuizQuestion secondQuestion,
        ) {
          return firstQuestion.order.compareTo(
            secondQuestion.order,
          );
        },
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _processingLessonId = null;
      });

      if (activeQuestions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Bài học này chưa có câu hỏi kiểm tra.',
            ),
            backgroundColor: Colors.red,
          ),
        );

        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (BuildContext context) {
            return QuizScreen(
              lesson: lesson,
              questions: activeQuestions,
            );
          },
        ),
      );

      if (!mounted) {
        return;
      }

      await _generateRecommendations();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _processingLessonId = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Không thể chuẩn bị bài kiểm tra: $error',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildAnalysisInformation() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF9C36B5),
            Color(0xFFCC5DE8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9C36B5)
                .withValues(alpha: 0.20),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.auto_awesome_rounded,
            color: Colors.white,
            size: 34,
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Phân tích học tập cá nhân',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 7),
                Text(
                  'Hệ thống sử dụng tiến độ học và kết quả '
                  'kiểm tra để xác định nội dung bạn nên '
                  'ưu tiên tiếp theo.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationCard({
    required AiRecommendation recommendation,
    required int position,
  }) {
    final Color recommendationColor =
        _getRecommendationColor(
      recommendation,
    );

    final bool isProcessing =
        _processingLessonId ==
            recommendation.lessonId;

    final bool anotherActionIsProcessing =
        _processingLessonId != null &&
            !isProcessing;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(
          color: Color(0xFFE8EAF2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(19),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: recommendationColor
                        .withValues(alpha: 0.12),
                    borderRadius:
                        BorderRadius.circular(15),
                  ),
                  child: Icon(
                    _getRecommendationIcon(
                      recommendation.type,
                    ),
                    color: recommendationColor,
                    size: 29,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding:
                                const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: recommendationColor
                                  .withValues(
                                alpha: 0.11,
                              ),
                              borderRadius:
                                  BorderRadius.circular(
                                20,
                              ),
                            ),
                            child: Text(
                              recommendation.typeLabel,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight:
                                    FontWeight.bold,
                                color:
                                    recommendationColor,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'Ưu tiên '
                            '${recommendation.safePriorityScore}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight:
                                  FontWeight.w600,
                              color:
                                  recommendationColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        recommendation.lessonTitle,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F8FC),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.psychology_alt_rounded,
                        color: Color(0xFF9C36B5),
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Lý do đề xuất',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  Text(
                    recommendation.reason,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: _buildStatisticItem(
                    label: 'Tiến độ',
                    value:
                        '${recommendation.safeLearningProgress.round()}%',
                    color: const Color(0xFF3B5BDB),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatisticItem(
                    label: 'Điểm gần nhất',
                    value: recommendation.hasQuizResult
                        ? '${recommendation.safeLatestQuizScore.round()}%'
                        : 'Chưa có',
                    color: const Color(0xFFF59F00),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatisticItem(
                    label: 'Số câu sai',
                    value: recommendation.hasQuizResult
                        ? recommendation.incorrectAnswers
                            .toString()
                        : '-',
                    color: Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.lightbulb_outline_rounded,
                  color: recommendationColor,
                  size: 21,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    recommendation.suggestedAction,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed:
                    isProcessing ||
                            anotherActionIsProcessing
                        ? null
                        : () {
                            _performRecommendationAction(
                              recommendation,
                            );
                          },
                icon: isProcessing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child:
                            CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Icon(
                        _getActionButtonIcon(
                          recommendation.type,
                        ),
                      ),
                label: Text(
                  isProcessing
                      ? 'Đang mở...'
                      : _getActionButtonLabel(
                          recommendation.type,
                        ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor:
                      recommendationColor,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticItem({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 11,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingView() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_awesome_rounded,
              color: Color(0xFF9C36B5),
              size: 58,
            ),
            SizedBox(height: 22),
            CircularProgressIndicator(
              color: Color(0xFF9C36B5),
            ),
            SizedBox(height: 18),
            Text(
              'AI đang phân tích kết quả học tập...',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView(String message) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.psychology_alt_outlined,
              color: Colors.red,
              size: 68,
            ),
            const SizedBox(height: 18),
            const Text(
              'Không thể tạo gợi ý',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                height: 1.5,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: _generateRecommendations,
              icon: const Icon(
                Icons.refresh_rounded,
              ),
              label: const Text('Phân tích lại'),
              style: FilledButton.styleFrom(
                backgroundColor:
                    const Color(0xFF9C36B5),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 94,
              height: 94,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF9C36B5)
                    .withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: Color(0xFF9C36B5),
                size: 50,
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'Chưa có gợi ý học tập',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Hãy học ít nhất một bài hoặc làm bài kiểm tra '
              'để hệ thống có dữ liệu phân tích.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: _generateRecommendations,
              icon: const Icon(
                Icons.auto_awesome_rounded,
              ),
              label: const Text('Phân tích lại'),
              style: FilledButton.styleFrom(
                backgroundColor:
                    const Color(0xFF9C36B5),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationList() {
    return RefreshIndicator(
      color: const Color(0xFF9C36B5),
      onRefresh: _generateRecommendations,
      child: ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          20,
          22,
          20,
          32,
        ),
        children: [
          _buildAnalysisInformation(),
          const SizedBox(height: 26),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Đề xuất dành cho bạn',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF9C36B5)
                      .withValues(alpha: 0.10),
                  borderRadius:
                      BorderRadius.circular(20),
                ),
                child: Text(
                  '${_recommendations.length} gợi ý',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF9C36B5),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          const Text(
            'Gợi ý có mức ưu tiên cao được hiển thị trước.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 18),
          for (
            int index = 0;
            index < _recommendations.length;
            index++
          )
            _buildRecommendationCard(
              recommendation:
                  _recommendations[index],
              position: index + 1,
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FF),
      appBar: AppBar(
        title: const Text(
          'Gợi ý từ AI',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF9C36B5),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Phân tích lại',
            onPressed: _isGenerating
                ? null
                : _generateRecommendations,
            icon: const Icon(
              Icons.refresh_rounded,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Builder(
          builder: (BuildContext context) {
            if (_isGenerating) {
              return _buildLoadingView();
            }

            if (_errorMessage != null) {
              return _buildErrorView(
                _errorMessage!,
              );
            }

            if (_recommendations.isEmpty) {
              return _buildEmptyView();
            }

            return _buildRecommendationList();
          },
        ),
      ),
    );
  }
}