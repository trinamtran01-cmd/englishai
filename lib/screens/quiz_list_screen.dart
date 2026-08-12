import 'package:flutter/material.dart';

import '../models/lesson.dart';
import '../models/quiz_question.dart';
import '../services/lesson_service.dart';
import '../services/quiz_service.dart';
import 'quiz_screen.dart';

class QuizListScreen extends StatefulWidget {
  const QuizListScreen({super.key});

  @override
  State<QuizListScreen> createState() =>
      _QuizListScreenState();
}

class _QuizListScreenState extends State<QuizListScreen> {
  final LessonService _lessonService = LessonService();
  final QuizService _quizService = QuizService();

  String? _loadingLessonId;

  IconData _getLessonIcon(String iconName) {
    switch (iconName) {
      case 'waving_hand':
        return Icons.waving_hand_rounded;

      case 'family':
        return Icons.family_restroom_rounded;

      case 'school':
        return Icons.school_rounded;

      case 'restaurant':
        return Icons.restaurant_rounded;

      case 'schedule':
        return Icons.schedule_rounded;

      case 'travel':
        return Icons.flight_takeoff_rounded;

      case 'work':
        return Icons.work_outline_rounded;

      case 'shopping':
        return Icons.shopping_cart_outlined;

      case 'health':
        return Icons.health_and_safety_outlined;

      case 'menu_book':
        return Icons.menu_book_rounded;

      default:
        return Icons.quiz_rounded;
    }
  }

  Color _getLessonColor(int colorValue) {
    return Color(colorValue);
  }

  /// Đọc các câu hỏi hiện có từ Firestore.
  ///
  /// Tài khoản Student không tạo câu hỏi mẫu.
  /// Việc tạo và quản lý câu hỏi thuộc quyền Admin.
  Future<void> _prepareQuiz(Lesson lesson) async {
    if (_loadingLessonId != null) {
      return;
    }

    setState(() {
      _loadingLessonId = lesson.id;
    });

    try {
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
        _loadingLessonId = null;
      });

      if (activeQuestions.isEmpty) {
        await _showNoQuestionsDialog(lesson);
        return;
      }

      await _showQuizInformation(
        lesson: lesson,
        questions: activeQuestions,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loadingLessonId = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Không thể tải bài kiểm tra: $error',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Hiển thị thông báo khi bài học chưa có câu hỏi.
  Future<void> _showNoQuestionsDialog(
    Lesson lesson,
  ) async {
    final Color lessonColor =
        _getLessonColor(lesson.color);

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          icon: Container(
            width: 68,
            height: 68,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: lessonColor.withValues(
                alpha: 0.12,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.quiz_outlined,
              color: lessonColor,
              size: 38,
            ),
          ),
          title: const Text(
            'Chưa có câu hỏi',
            textAlign: TextAlign.center,
          ),
          content: Text(
            'Bài kiểm tra "${lesson.title}" hiện chưa có '
            'dữ liệu câu hỏi.\n\n'
            'Vui lòng liên hệ quản trị viên để bổ sung '
            'câu hỏi cho bài học này.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
            ),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              style: FilledButton.styleFrom(
                backgroundColor: lessonColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Đã hiểu'),
            ),
          ],
        );
      },
    );
  }

  /// Hiển thị thông tin và quy định trước khi làm bài.
  Future<void> _showQuizInformation({
    required Lesson lesson,
    required List<QuizQuestion> questions,
  }) async {
    final Color lessonColor =
        _getLessonColor(lesson.color);

    final bool? shouldStart =
        await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          icon: Container(
            width: 68,
            height: 68,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: lessonColor.withValues(
                alpha: 0.12,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.quiz_rounded,
              color: lessonColor,
              size: 37,
            ),
          ),
          title: Text(
            lesson.title,
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Bài kiểm tra gồm '
                '${questions.length} câu hỏi.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 18),
              const _QuizRuleRow(
                icon:
                    Icons.check_circle_outline_rounded,
                text:
                    'Mỗi câu hỏi chỉ được chọn một đáp án.',
              ),
              const SizedBox(height: 11),
              const _QuizRuleRow(
                icon: Icons.arrow_back_rounded,
                text:
                    'Bạn có thể quay lại câu trước để đổi đáp án.',
              ),
              const SizedBox(height: 11),
              const _QuizRuleRow(
                icon: Icons.percent_rounded,
                text:
                    'Cần đạt từ 50% trở lên để vượt qua bài kiểm tra.',
              ),
              const SizedBox(height: 11),
              const _QuizRuleRow(
                icon: Icons.cloud_done_outlined,
                text:
                    'Kết quả sẽ được lưu vào tài khoản của bạn.',
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Đóng'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              icon: const Icon(
                Icons.play_arrow_rounded,
              ),
              label: const Text('Bắt đầu'),
              style: FilledButton.styleFrom(
                backgroundColor: lessonColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );

    if (shouldStart != true || !mounted) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return QuizScreen(
            lesson: lesson,
            questions: questions,
          );
        },
      ),
    );
  }

  Widget _buildLessonCard({
    required Lesson lesson,
    required int lessonNumber,
  }) {
    final Color lessonColor =
        _getLessonColor(lesson.color);

    final bool isLoading =
        _loadingLessonId == lesson.id;

    final bool anotherQuizIsLoading =
        _loadingLessonId != null &&
            _loadingLessonId != lesson.id;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: InkWell(
        onTap: isLoading || anotherQuizIsLoading
            ? null
            : () {
                _prepareQuiz(lesson);
              },
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: lessonColor.withValues(
                    alpha: 0.12,
                  ),
                  borderRadius:
                      BorderRadius.circular(16),
                ),
                child: Icon(
                  _getLessonIcon(lesson.icon),
                  color: lessonColor,
                  size: 31,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bài kiểm tra $lessonNumber',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: lessonColor,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      lesson.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      lesson.topic,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (isLoading)
                SizedBox(
                  width: 25,
                  height: 25,
                  child: CircularProgressIndicator(
                    color: lessonColor,
                    strokeWidth: 2.5,
                  ),
                )
              else
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: lessonColor.withValues(
                      alpha: 0.10,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    color: lessonColor,
                    size: 23,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              color: Color(0xFFF59F00),
            ),
            const SizedBox(height: 18),
            Text(
              'Đang tải danh sách bài kiểm tra...',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
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
              Icons.cloud_off_rounded,
              color: Colors.red,
              size: 64,
            ),
            const SizedBox(height: 18),
            Text(
              'Không thể tải bài kiểm tra',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: () {
                setState(() {});
              },
              icon: const Icon(
                Icons.refresh_rounded,
              ),
              label: const Text('Thử lại'),
              style: FilledButton.styleFrom(
                backgroundColor:
                    const Color(0xFFF59F00),
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
              width: 92,
              height: 92,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFF59F00)
                    .withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.quiz_outlined,
                size: 50,
                color: Color(0xFFF59F00),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'Chưa có bài kiểm tra',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Hiện chưa có bài học nào để làm bài '
              'kiểm tra.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuizList(
    List<Lesson> lessons,
  ) {
    return RefreshIndicator(
      color: const Color(0xFFF59F00),
      onRefresh: () async {
        setState(() {});

        await Future<void>.delayed(
          const Duration(milliseconds: 400),
        );
      },
      child: ListView.builder(
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          20,
          22,
          20,
          32,
        ),
        itemCount: lessons.length,
        itemBuilder: (
          BuildContext context,
          int index,
        ) {
          return _buildLessonCard(
            lesson: lessons[index],
            lessonNumber: index + 1,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Kiểm tra kiến thức',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor:
            const Color(0xFFF59F00),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(
                20,
                20,
                20,
                22,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFFF59F00),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(26),
                  bottomRight: Radius.circular(26),
                ),
              ),
              child: const Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    'Chọn chủ đề kiểm tra',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 7),
                  Text(
                    'Kiểm tra kiến thức sau khi học và '
                    'lưu kết quả để theo dõi tiến bộ.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<List<Lesson>>(
                stream:
                    _lessonService.getActiveLessons(),
                builder: (
                  BuildContext context,
                  AsyncSnapshot<List<Lesson>>
                      snapshot,
                ) {
                  if (snapshot.connectionState ==
                          ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return _buildLoadingView();
                  }

                  if (snapshot.hasError) {
                    return _buildErrorView(
                      snapshot.error.toString(),
                    );
                  }

                  final List<Lesson> lessons =
                      snapshot.data ?? <Lesson>[];

                  if (lessons.isEmpty) {
                    return _buildEmptyView();
                  }

                  return _buildQuizList(lessons);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuizRuleRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _QuizRuleRow({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: const Color(0xFFF59F00),
          size: 20,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}