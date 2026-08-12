import 'package:flutter/material.dart';

import '../models/lesson.dart';
import '../models/quiz_question.dart';
import '../models/quiz_result.dart';
import '../services/quiz_result_service.dart';

class QuizScreen extends StatefulWidget {
  final Lesson lesson;
  final List<QuizQuestion> questions;

  const QuizScreen({
    super.key,
    required this.lesson,
    required this.questions,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final PageController _pageController = PageController();

  final QuizResultService _quizResultService =
      QuizResultService();

  final Map<String, int> _selectedAnswers =
      <String, int>{};

  late DateTime _startedAt;

  int _currentQuestionIndex = 0;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Color get _lessonColor {
    return Color(widget.lesson.color);
  }

  QuizQuestion get _currentQuestion {
    return widget.questions[_currentQuestionIndex];
  }

  bool get _hasSelectedCurrentAnswer {
    return _selectedAnswers.containsKey(
      _currentQuestion.id,
    );
  }

  void _selectAnswer({
    required QuizQuestion question,
    required int answerIndex,
  }) {
    if (_isSubmitting) {
      return;
    }

    setState(() {
      _selectedAnswers[question.id] = answerIndex;
    });
  }

  Future<void> _goToPreviousQuestion() async {
    if (_currentQuestionIndex <= 0 ||
        _isSubmitting) {
      return;
    }

    await _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Future<void> _goToNextQuestion() async {
    if (_isSubmitting) {
      return;
    }

    if (!_hasSelectedCurrentAnswer) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Vui lòng chọn một đáp án trước khi tiếp tục.',
          ),
          backgroundColor: Colors.orange,
        ),
      );

      return;
    }

    if (_currentQuestionIndex >=
        widget.questions.length - 1) {
      await _confirmSubmitQuiz();
      return;
    }

    await _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Future<void> _confirmSubmitQuiz() async {
    if (_isSubmitting) {
      return;
    }

    final int answeredQuestions =
        _selectedAnswers.length;

    final int totalQuestions =
        widget.questions.length;

    final int unansweredQuestions =
        totalQuestions - answeredQuestions;

    final bool? shouldSubmit =
        await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          icon: Icon(
            Icons.assignment_turned_in_rounded,
            color: _lessonColor,
            size: 48,
          ),
          title: const Text(
            'Nộp bài kiểm tra?',
            textAlign: TextAlign.center,
          ),
          content: Text(
            unansweredQuestions > 0
                ? 'Bạn đã trả lời $answeredQuestions/'
                    '$totalQuestions câu.\n\n'
                    'Còn $unansweredQuestions câu chưa '
                    'trả lời. Bạn vẫn muốn nộp bài?'
                : 'Bạn đã trả lời đầy đủ '
                    '$totalQuestions câu hỏi.\n\n'
                    'Bạn có chắc chắn muốn nộp bài?',
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Kiểm tra lại'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              style: FilledButton.styleFrom(
                backgroundColor: _lessonColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Nộp bài'),
            ),
          ],
        );
      },
    );

    if (shouldSubmit != true || !mounted) {
      return;
    }

    await _submitQuiz();
  }

  Future<void> _submitQuiz() async {
    if (_isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final QuizResult result =
          await _quizResultService.saveQuizResult(
        lesson: widget.lesson,
        questions: widget.questions,
        selectedAnswers: _selectedAnswers,
        startedAt: _startedAt,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isSubmitting = false;
      });

      await _showResultDialog(result);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSubmitting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Không thể lưu kết quả: $error',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showResultDialog(
    QuizResult result,
  ) async {
    final Color resultColor = result.isPassed
        ? const Color(0xFF2F9E44)
        : Colors.red;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          icon: Container(
            width: 76,
            height: 76,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: resultColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              result.isPassed
                  ? Icons.emoji_events_rounded
                  : Icons.refresh_rounded,
              color: resultColor,
              size: 44,
            ),
          ),
          title: Text(
            result.resultLabel,
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${result.roundedScore} điểm',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: resultColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                result.isPassed
                    ? 'Bạn đã vượt qua bài kiểm tra.'
                    : 'Bạn chưa vượt qua bài kiểm tra.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 20),
              _ResultRow(
                label: 'Số câu đúng',
                value:
                    '${result.safeCorrectAnswers}/'
                    '${result.totalQuestions}',
                color: const Color(0xFF2F9E44),
              ),
              const SizedBox(height: 10),
              _ResultRow(
                label: 'Số câu sai',
                value:
                    '${result.safeIncorrectAnswers}/'
                    '${result.totalQuestions}',
                color: Colors.red,
              ),
              const SizedBox(height: 10),
              _ResultRow(
                label: 'Lần làm bài',
                value: '${result.attemptNumber}',
                color: const Color(0xFF3B5BDB),
              ),
              const SizedBox(height: 14),
              Text(
                'Kết quả đã được lưu vào Firestore.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _restartQuiz();
              },
              child: const Text('Làm lại'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                Navigator.of(context).pop();
              },
              style: FilledButton.styleFrom(
                backgroundColor: resultColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Hoàn thành'),
            ),
          ],
        );
      },
    );
  }

  void _restartQuiz() {
    _selectedAnswers.clear();
    _startedAt = DateTime.now();

    setState(() {
      _currentQuestionIndex = 0;
      _isSubmitting = false;
    });

    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Bắt đầu lại bài kiểm tra.',
        ),
      ),
    );
  }

  Future<bool> _handleExitRequest() async {
    if (_isSubmitting) {
      return false;
    }

    if (_selectedAnswers.isEmpty) {
      return true;
    }

    final bool? shouldExit =
        await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text(
            'Thoát bài kiểm tra?',
          ),
          content: const Text(
            'Các đáp án chưa nộp sẽ không được lưu. '
            'Bạn có chắc chắn muốn thoát không?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Tiếp tục làm'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Thoát'),
            ),
          ],
        );
      },
    );

    return shouldExit == true;
  }

  Widget _buildAnswerOption({
    required QuizQuestion question,
    required int answerIndex,
  }) {
    final bool isSelected =
        _selectedAnswers[question.id] ==
            answerIndex;

    final String optionLetter = String.fromCharCode(
      65 + answerIndex,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Material(
        color: isSelected
            ? _lessonColor.withValues(alpha: 0.10)
            : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: _isSubmitting
              ? null
              : () {
                  _selectAnswer(
                    question: question,
                    answerIndex: answerIndex,
                  );
                },
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(
              milliseconds: 180,
            ),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? _lessonColor
                    : const Color(0xFFE1E5F2),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(
                    milliseconds: 180,
                  ),
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? _lessonColor
                        : const Color(0xFFF1F3F9),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    optionLetter,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? Colors.white
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    question.options[answerIndex],
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.4,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  isSelected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: isSelected
                      ? _lessonColor
                      : Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionPage(
    QuizQuestion question,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        20,
        22,
        20,
        28,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: _lessonColor.withValues(
                    alpha: 0.12,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  question.difficultyLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _lessonColor,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                'Đã trả lời '
                '${_selectedAnswers.length}/'
                '${widget.questions.length}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            question.question,
            style: TextStyle(
              fontSize: 22,
              height: 1.4,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Chọn một đáp án đúng:',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 22),
          for (
            int index = 0;
            index < question.options.length;
            index++
          )
            _buildAnswerOption(
              question: question,
              answerIndex: index,
            ),
        ],
      ),
    );
  }

  Widget _buildQuizContent() {
    final int totalQuestions =
        widget.questions.length;

    final double progress =
        (_currentQuestionIndex + 1) /
            totalQuestions;

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(
            20,
            18,
            20,
            20,
          ),
          decoration: BoxDecoration(
            color: _lessonColor,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(26),
              bottomRight: Radius.circular(26),
            ),
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                widget.lesson.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius:
                          BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 9,
                        backgroundColor: Colors.white24,
                        valueColor:
                            const AlwaysStoppedAnimation<
                                Color>(
                          Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    'Câu ${_currentQuestionIndex + 1}'
                    '/$totalQuestions',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            physics:
                const NeverScrollableScrollPhysics(),
            itemCount: totalQuestions,
            onPageChanged: (int index) {
              setState(() {
                _currentQuestionIndex = index;
              });
            },
            itemBuilder: (
              BuildContext context,
              int index,
            ) {
              return _buildQuestionPage(
                widget.questions[index],
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(
            20,
            14,
            20,
            20,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              top: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        _currentQuestionIndex > 0 &&
                                !_isSubmitting
                            ? _goToPreviousQuestion
                            : null,
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                    ),
                    label: const Text('Câu trước'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _lessonColor,
                      padding:
                          const EdgeInsets.symmetric(
                        vertical: 15,
                      ),
                      side: BorderSide(
                        color:
                            _currentQuestionIndex > 0
                                ? _lessonColor
                                : Colors.grey.shade300,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _isSubmitting
                        ? null
                        : _goToNextQuestion,
                    icon: _isSubmitting
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
                            _currentQuestionIndex ==
                                    totalQuestions - 1
                                ? Icons
                                    .assignment_turned_in_rounded
                                : Icons
                                    .arrow_forward_rounded,
                          ),
                    label: Text(
                      _isSubmitting
                          ? 'Đang lưu...'
                          : _currentQuestionIndex ==
                                  totalQuestions - 1
                              ? 'Nộp bài'
                              : 'Câu tiếp',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: _lessonColor,
                      foregroundColor: Colors.white,
                      padding:
                          const EdgeInsets.symmetric(
                        vertical: 15,
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
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Làm bài kiểm tra'),
        ),
        body: const Center(
          child: Text(
            'Bài kiểm tra chưa có câu hỏi.',
          ),
        ),
      );
    }

    return PopScope<bool>(
      canPop: _selectedAnswers.isEmpty,
      onPopInvokedWithResult: (
  bool didPop,
  bool? result,
) async {
  if (didPop) {
    return;
  }

  final bool shouldExit =
      await _handleExitRequest();

  if (!context.mounted || !shouldExit) {
    return;
  }

  Navigator.of(context).pop();
},
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Làm bài kiểm tra',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: _lessonColor,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: SafeArea(
          child: _buildQuizContent(),
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _ResultRow({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 11,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}