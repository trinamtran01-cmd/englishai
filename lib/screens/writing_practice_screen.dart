import 'dart:async';

import 'package:flutter/material.dart';

import '../models/writing_ai_feedback.dart';
import '../models/writing_attempt.dart';
import '../models/writing_task.dart';
import '../services/writing_ai_grading_service.dart';
import '../services/writing_practice_service.dart';
import 'writing_result_screen.dart';

/// Màn hình làm bài Luyện Viết AI: hiện đề bài, khung soạn thảo có
/// đếm từ, nộp bài rồi nhờ AI chấm điểm theo tiêu chí IELTS.
class WritingPracticeScreen extends StatefulWidget {
  const WritingPracticeScreen({
    super.key,
    required this.task,
  });

  final WritingTask task;

  @override
  State<WritingPracticeScreen> createState() =>
      _WritingPracticeScreenState();
}

class _WritingPracticeScreenState extends State<WritingPracticeScreen> {
  static const Color _accentColor = Color(0xFFE8590C);

  final WritingPracticeService _practiceService =
      WritingPracticeService();

  final WritingAiGradingService _gradingService =
      WritingAiGradingService();

  final TextEditingController _textController = TextEditingController();

  Timer? _loadingStageTimer;

  int _wordCount = 0;
  int _loadingStageIndex = 0;
  bool _isSubmitting = false;
  bool _imageFailedToLoad = false;

  List<String> get _loadingStages {
    if (widget.task.taskType.trim().toLowerCase() == 'task1') {
      return const [
        'Đang kiểm tra dữ liệu biểu đồ...',
        'Đang phân tích từ vựng và ngữ pháp...',
        'Đang đánh giá bố cục và liên kết...',
        'Đang tổng hợp nhận xét từ giám khảo AI...',
      ];
    }

    return const [
      'Đang đọc và phân tích lập luận...',
      'Đang phân tích từ vựng và ngữ pháp...',
      'Đang đánh giá bố cục và liên kết...',
      'Đang tổng hợp nhận xét từ giám khảo AI...',
    ];
  }

  @override
  void initState() {
    super.initState();
    _textController.addListener(_handleTextChanged);
  }

  @override
  void dispose() {
    _textController.removeListener(_handleTextChanged);
    _textController.dispose();
    _loadingStageTimer?.cancel();
    super.dispose();
  }

  void _handleTextChanged() {
    final Iterable<RegExpMatch> matches =
        RegExp(r'\S+').allMatches(_textController.text.trim());

    setState(() {
      _wordCount = matches.length;
    });
  }

  void _startLoadingStageTimer() {
    _loadingStageIndex = 0;

    _loadingStageTimer = Timer.periodic(
      const Duration(seconds: 3),
      (Timer timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        setState(() {
          _loadingStageIndex =
              (_loadingStageIndex + 1) % _loadingStages.length;
        });
      },
    );
  }

  /// Loại bỏ tiền tố "Exception: " để hiển thị gọn hơn cho người dùng.
  String _cleanErrorMessage(Object error) {
    final String message = error.toString();

    if (message.startsWith('Exception: ')) {
      return message.substring('Exception: '.length);
    }

    return message;
  }

  Future<void> _confirmAndSubmit() async {
    if (_isSubmitting) {
      return;
    }

    if (_textController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng viết bài trước khi nộp.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final bool? shouldSubmit = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Nộp bài?'),
          content: const Text(
            'Sau khi nộp, bạn không thể chỉnh sửa lại bài làm này. '
            'AI sẽ chấm điểm dựa trên nội dung hiện tại. Bạn có '
            'chắc chắn muốn nộp bài không?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              style: FilledButton.styleFrom(
                backgroundColor: _accentColor,
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

    setState(() {
      _isSubmitting = true;
    });

    _startLoadingStageTimer();

    try {
      final WritingAttempt attempt = await _practiceService.submitAttempt(
        widget.task.id,
        _textController.text,
      );

      final WritingAiFeedback feedback = await _gradingService.gradeAttempt(
        attemptId: attempt.id,
        task: widget.task,
        userText: _textController.text,
      );

      _loadingStageTimer?.cancel();

      if (!mounted) {
        return;
      }

      setState(() {
        _isSubmitting = false;
      });

      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (BuildContext context) {
            return WritingResultScreen(
              task: widget.task,
              attempt: attempt,
              feedback: feedback,
            );
          },
        ),
      );
    } catch (error) {
      _loadingStageTimer?.cancel();

      if (!mounted) {
        return;
      }

      setState(() {
        _isSubmitting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_cleanErrorMessage(error)),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildPromptCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  widget.task.taskTypeLabel,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _accentColor,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                'Tối thiểu ${widget.task.minWords} từ',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            widget.task.title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.task.promptText,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          if (widget.task.imageUrl.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            _buildTaskImage(),
          ],
        ],
      ),
    );
  }

  /// Ảnh biểu đồ IELTS thường có nền trắng — bọc trong khung nền
  /// trắng bo góc để không bị chìm mất chi tiết trên nền tối.
  Widget _buildTaskImage() {
    if (_imageFailedToLoad) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              Icons.broken_image_outlined,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Không tải được ảnh biểu đồ.',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          widget.task.imageUrl.trim(),
          fit: BoxFit.contain,
          errorBuilder: (
            BuildContext context,
            Object error,
            StackTrace? stackTrace,
          ) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && !_imageFailedToLoad) {
                setState(() {
                  _imageFailedToLoad = true;
                });
              }
            });

            return const SizedBox(height: 120);
          },
          loadingBuilder: (
            BuildContext context,
            Widget child,
            ImageChunkEvent? loadingProgress,
          ) {
            if (loadingProgress == null) {
              return child;
            }

            return const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: CircularProgressIndicator(
                  color: _accentColor,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEditor() {
    final bool isUnderMinWords = _wordCount < widget.task.minWords;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: TextField(
            controller: _textController,
            enabled: !_isSubmitting,
            maxLines: 14,
            minLines: 10,
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            decoration: const InputDecoration(
              hintText: 'Viết bài của bạn vào đây...',
              contentPadding: EdgeInsets.all(16),
              border: InputBorder.none,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '$_wordCount / ${widget.task.minWords} từ'
          '${isUnderMinWords ? ' — cần viết thêm để đủ số từ tối thiểu' : ''}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isUnderMinWords
                ? Colors.orange.shade700
                : const Color(0xFF2F9E44),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: _accentColor),
          const SizedBox(height: 20),
          Text(
            _loadingStages[_loadingStageIndex],
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Luyện Viết AI',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: _accentColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: _isSubmitting
            ? Center(child: _buildLoadingOverlay())
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                children: [
                  _buildPromptCard(),
                  const SizedBox(height: 20),
                  _buildEditor(),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _confirmAndSubmit,
                    icon: const Icon(Icons.send_rounded),
                    label: const Text('Nộp bài & Chấm điểm'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _accentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
