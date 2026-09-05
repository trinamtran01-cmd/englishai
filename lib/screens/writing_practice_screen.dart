import 'dart:async';

import 'package:flutter/material.dart';

import '../models/writing_ai_feedback.dart';
import '../models/writing_attempt.dart';
import '../models/writing_task.dart';
import '../services/writing_ai_grading_service.dart';
import '../services/writing_practice_service.dart';
import 'writing_result_screen.dart';

/// Màn hình làm bài Luyện Viết AI: hiện đề bài, khung soạn thảo có
/// đếm từ, đếm giờ, rồi nộp bài để AI chấm điểm theo tiêu chí IELTS.
///
/// Bố cục 2 cột (đề bài | soạn thảo) trên màn hình rộng, xếp dọc
/// trên màn hình hẹp.
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
  static const Color _warnColor = Color(0xFFF57C00);
  static const double _wideLayoutBreakpoint = 900;

  final WritingPracticeService _practiceService =
      WritingPracticeService();

  final WritingAiGradingService _gradingService =
      WritingAiGradingService();

  final TextEditingController _textController = TextEditingController();

  Timer? _loadingStageTimer;
  Timer? _countdownTimer;

  int _wordCount = 0;
  int _loadingStageIndex = 0;
  bool _isSubmitting = false;
  bool _imageFailedToLoad = false;

  double _promptFontScale = 1.0;
  double _editorFontScale = 1.0;

  bool _isExamMode = false;
  bool _spellCheckEnabled = true;

  late int _remainingSeconds;
  bool _timeIsUp = false;

  DateTime? _lastSavedAt;
  String _lastSavedText = '';

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
    _remainingSeconds = widget.task.timeLimitMinutes * 60;
    _textController.addListener(_handleTextChanged);
    _startCountdownTimer();
  }

  @override
  void dispose() {
    _textController.removeListener(_handleTextChanged);
    _textController.dispose();
    _loadingStageTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _handleTextChanged() {
    final Iterable<RegExpMatch> matches =
        RegExp(r'\S+').allMatches(_textController.text.trim());

    setState(() {
      _wordCount = matches.length;
    });

    _maybeMarkAsSaved();
  }

  /// Tự động lưu nháp cục bộ (chỉ trong bộ nhớ của phiên làm bài
  /// hiện tại, không gửi lên server) - cập nhật mốc thời gian mỗi
  /// khi nội dung thay đổi so với lần "lưu" gần nhất, cách nhau ít
  /// nhất vài giây để không cập nhật UI liên tục theo từng ký tự gõ.
  void _maybeMarkAsSaved() {
    final String currentText = _textController.text;

    if (currentText == _lastSavedText) {
      return;
    }

    final DateTime now = DateTime.now();

    if (_lastSavedAt != null &&
        now.difference(_lastSavedAt!) < const Duration(seconds: 3)) {
      return;
    }

    _lastSavedText = currentText;

    setState(() {
      _lastSavedAt = now;
    });
  }

  void _startCountdownTimer() {
    _countdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (Timer timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        if (_remainingSeconds <= 0) {
          timer.cancel();

          if (!_timeIsUp) {
            _timeIsUp = true;
            _handleTimeUp();
          }
          return;
        }

        setState(() {
          _remainingSeconds--;
        });
      },
    );
  }

  void _handleTimeUp() {
    if (!_isExamMode) {
      setState(() {});
      return;
    }

    _submit(isAutoSubmit: true);
  }

  String _formatCountdown(int totalSeconds) {
    final int clamped = totalSeconds < 0 ? 0 : totalSeconds;
    final int minutes = clamped ~/ 60;
    final int seconds = clamped % 60;

    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
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

  Future<void> _handleExitRequest() async {
    if (_isSubmitting) {
      return;
    }

    if (_textController.text.trim().isEmpty) {
      Navigator.of(context).pop();
      return;
    }

    final bool? shouldExit = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Thoát khi đang làm bài?'),
          content: const Text(
            'Bài làm hiện tại chưa được nộp và sẽ mất nếu bạn thoát '
            'bây giờ. Bạn có chắc chắn muốn thoát không?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Tiếp tục làm bài'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Thoát'),
            ),
          ],
        );
      },
    );

    if (shouldExit == true && mounted) {
      Navigator.of(context).pop();
    }
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

    await _submit();
  }

  Future<void> _submit({bool isAutoSubmit = false}) async {
    if (_isSubmitting) {
      return;
    }

    if (_textController.text.trim().isEmpty) {
      return;
    }

    _countdownTimer?.cancel();

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

      if (isAutoSubmit) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Đã hết giờ, bài làm của bạn đã được tự động nộp.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }

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

  Widget _fontSizeButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: 32,
      height: 32,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          side: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Icon(
          icon,
          size: 15,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildFontSizeControls({
    required double scale,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _fontSizeButton(
          icon: Icons.text_decrease_rounded,
          onPressed: () {
            onChanged((scale - 0.1).clamp(0.8, 1.5));
          },
        ),
        const SizedBox(width: 6),
        _fontSizeButton(
          icon: Icons.text_increase_rounded,
          onPressed: () {
            onChanged((scale + 0.1).clamp(0.8, 1.5));
          },
        ),
      ],
    );
  }

  Widget _buildTopBar(bool isWide) {
    final Color countdownColor =
        _remainingSeconds <= 60 ? Colors.red : _accentColor;

    final Widget exitButton = TextButton.icon(
      onPressed: _handleExitRequest,
      icon: const Icon(Icons.arrow_back_rounded, size: 18),
      label: const Text('Thoát'),
      style: TextButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );

    final Widget countdownChip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: countdownColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: 16, color: countdownColor),
          const SizedBox(width: 6),
          Text(
            _formatCountdown(_remainingSeconds),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: countdownColor,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );

    final Widget modeToggle = Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _modeToggleOption(label: 'Luyện tập', selected: !_isExamMode),
          _modeToggleOption(label: 'Thi thật', selected: _isExamMode),
        ],
      ),
    );

    final Widget submitButton = FilledButton.icon(
      onPressed: _confirmAndSubmit,
      icon: const Icon(Icons.send_rounded, size: 17),
      label: const Text('Nộp bài & Chấm điểm'),
      style: FilledButton.styleFrom(
        backgroundColor: _accentColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );

    if (isWide) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            bottom: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
        child: Row(
          children: [
            exitButton,
            const SizedBox(width: 16),
            countdownChip,
            const SizedBox(width: 16),
            modeToggle,
            const Spacer(),
            submitButton,
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              exitButton,
              const Spacer(),
              countdownChip,
              const SizedBox(width: 10),
              modeToggle,
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: submitButton,
          ),
        ],
      ),
    );
  }

  Widget _modeToggleOption({required String label, required bool selected}) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isExamMode = label == 'Thi thật';
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? _accentColor : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: selected
                ? Colors.white
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _buildPromptPanel() {
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
              _buildFontSizeControls(
                scale: _promptFontScale,
                onChanged: (double value) {
                  setState(() {
                    _promptFontScale = value;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Tối thiểu ${widget.task.minWords} từ',
              style: TextStyle(
                fontSize: 11 * _promptFontScale,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.task.title,
            style: TextStyle(
              fontSize: 18 * _promptFontScale,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.task.promptText,
            style: TextStyle(
              fontSize: 14 * _promptFontScale,
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

  String _formatSavedTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildEditorPanel({required bool expandEditor}) {
    final bool isUnderMinWords = _wordCount < widget.task.minWords;

    final Widget textField = TextField(
      controller: _textController,
      enabled: !_isSubmitting,
      maxLines: expandEditor ? null : 14,
      minLines: expandEditor ? null : 10,
      expands: expandEditor,
      autocorrect: _spellCheckEnabled,
      enableSuggestions: _spellCheckEnabled,
      textAlignVertical: expandEditor ? TextAlignVertical.top : null,
      style: TextStyle(
        fontSize: 14 * _editorFontScale,
        height: 1.6,
        color: Theme.of(context).colorScheme.onSurface,
      ),
      decoration: const InputDecoration(
        hintText: 'Viết bài của bạn vào đây...',
        contentPadding: EdgeInsets.all(16),
        border: InputBorder.none,
      ),
    );

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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'Bài viết của bạn',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Tooltip(
                message: _spellCheckEnabled
                    ? 'Tắt kiểm tra chính tả'
                    : 'Bật kiểm tra chính tả',
                child: _fontSizeButton(
                  icon: _spellCheckEnabled
                      ? Icons.spellcheck_rounded
                      : Icons.spellcheck_outlined,
                  onPressed: () {
                    setState(() {
                      _spellCheckEnabled = !_spellCheckEnabled;
                    });
                  },
                ),
              ),
              const SizedBox(width: 6),
              _buildFontSizeControls(
                scale: _editorFontScale,
                onChanged: (double value) {
                  setState(() {
                    _editorFontScale = value;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            flex: expandEditor ? 1 : 0,
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: textField,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  '$_wordCount / ${widget.task.minWords} từ'
                  '${isUnderMinWords ? ' — cần viết thêm để đủ số từ tối thiểu' : ''}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isUnderMinWords
                        ? _warnColor
                        : const Color(0xFF2F9E44),
                  ),
                ),
              ),
              if (_lastSavedAt != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle_outline_rounded,
                      size: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Đã lưu nháp lúc ${_formatSavedTime(_lastSavedAt!)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
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

  Widget _buildBody(bool isWide) {
    if (isWide) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: _buildPromptPanel(),
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: _buildEditorPanel(expandEditor: true),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildPromptPanel(),
          const SizedBox(height: 18),
          _buildEditorPanel(expandEditor: false),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) {
          return;
        }
        _handleExitRequest();
      },
      child: Scaffold(
        body: SafeArea(
          child: _isSubmitting
              ? Center(child: _buildLoadingOverlay())
              : LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final bool isWide =
                        constraints.maxWidth >= _wideLayoutBreakpoint;

                    return Column(
                      children: [
                        _buildTopBar(isWide),
                        Expanded(child: _buildBody(isWide)),
                      ],
                    );
                  },
                ),
        ),
      ),
    );
  }
}
