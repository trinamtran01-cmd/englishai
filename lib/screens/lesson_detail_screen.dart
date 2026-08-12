import 'package:flutter/material.dart';

import '../models/lesson.dart';
import '../models/vocabulary.dart';
import '../services/progress_service.dart';
import '../services/vocabulary_service.dart';

class LessonDetailScreen extends StatefulWidget {
  final Lesson lesson;

  const LessonDetailScreen({
    super.key,
    required this.lesson,
  });

  @override
  State<LessonDetailScreen> createState() =>
      _LessonDetailScreenState();
}

class _LessonDetailScreenState
    extends State<LessonDetailScreen> {
  final VocabularyService _vocabularyService =
      VocabularyService();

  final ProgressService _progressService =
      ProgressService();

  final PageController _pageController =
      PageController();

  bool _isPreparingData = true;
  bool _isSavingProgress = false;

  String? _preparationError;

  int _currentIndex = 0;
  int _highestViewedWords = 0;
  int _totalWords = 0;

  @override
  void initState() {
    super.initState();
    _prepareLesson();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Chuẩn bị dữ liệu từ vựng và khởi tạo tiến độ học.
  Future<void> _prepareLesson() async {
    if (mounted) {
      setState(() {
        _isPreparingData = true;
        _preparationError = null;
      });
    }

    try {
      // Tạo từ vựng mẫu nếu bài học chưa có dữ liệu.


      // Lấy danh sách từ vựng hiện tại để biết tổng số từ.
      final List<Vocabulary> vocabularies =
          await _vocabularyService
              .getVocabulariesByLesson(
        widget.lesson.id,
      );

      final List<Vocabulary> activeVocabularies =
          vocabularies
              .where(
                (Vocabulary vocabulary) =>
                    vocabulary.isActive,
              )
              .toList();

      _totalWords = activeVocabularies.length;

      // Tạo hoặc cập nhật document tiến độ.
      await _progressService.startLesson(
        lesson: widget.lesson,
        totalWords: _totalWords,
      );

      // Khi mở bài học, người dùng đã xem từ đầu tiên.
      if (_totalWords > 0) {
        await _progressService.updateViewedWords(
          lesson: widget.lesson,
          viewedWords: 1,
          totalWords: _totalWords,
        );

        _highestViewedWords = 1;
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _preparationError = error.toString();
      });
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isPreparingData = false;
    });
  }

  /// Lưu số từ nhiều nhất người dùng đã xem.
  ///
  /// Khi người dùng quay lại từ cũ, tiến độ không bị giảm.
  Future<void> _saveViewedWords({
    required int viewedWords,
    required int totalWords,
  }) async {
    if (viewedWords <= _highestViewedWords) {
      return;
    }

    _highestViewedWords = viewedWords;

    try {
      await _progressService.updateViewedWords(
        lesson: widget.lesson,
        viewedWords: viewedWords,
        totalWords: totalWords,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Không thể lưu tiến độ: $error',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _goToPreviousWord() {
    if (_currentIndex <= 0) {
      return;
    }

    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _goToNextWord(int totalWords) {
    if (_currentIndex >= totalWords - 1) {
      _completeLesson(totalWords);
      return;
    }

    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  /// Lưu tiến độ 100% trước khi hiển thị thông báo hoàn thành.
  Future<void> _completeLesson(
    int totalWords,
  ) async {
    if (_isSavingProgress) {
      return;
    }

    setState(() {
      _isSavingProgress = true;
    });

    try {
      await _progressService.completeLesson(
        lesson: widget.lesson,
        totalWords: totalWords,
      );

      _highestViewedWords = totalWords;

      if (!mounted) {
        return;
      }

      setState(() {
        _isSavingProgress = false;
      });

      await _showCompletionDialog(totalWords);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSavingProgress = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Không thể lưu trạng thái hoàn thành: $error',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showCompletionDialog(
    int totalWords,
  ) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          icon: const Icon(
            Icons.emoji_events_rounded,
            color: Color(0xFFF59F00),
            size: 52,
          ),
          title: const Text(
            'Hoàn thành bài học!',
            textAlign: TextAlign.center,
          ),
          content: Text(
            'Bạn đã xem hết $totalWords từ vựng trong bài '
            '"${widget.lesson.title}".\n\n'
            'Tiến độ học tập đã được lưu.',
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();

                await _restartLesson();
              },
              child: const Text('Học lại'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                Navigator.of(context).pop();
              },
              child: const Text('Hoàn thành'),
            ),
          ],
        );
      },
    );
  }

  /// Tăng số lần học và chuyển về từ đầu tiên.
  Future<void> _restartLesson() async {
  try {
    await _progressService.incrementStudyCount(
      widget.lesson.id,
    );

    if (!mounted) {
      return;
    }

    await _pageController.animateToPage(
      0,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
    );

    // Kiểm tra lại vì animateToPage là một thao tác bất đồng bộ.
    if (!mounted) {
      return;
    }

    setState(() {
      _currentIndex = 0;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Bắt đầu học lại từ từ đầu tiên.',
        ),
      ),
    );
  } catch (error) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Không thể bắt đầu học lại: $error',
        ),
        backgroundColor: Colors.red,
      ),
    );
  }
}

  Color _getLessonColor() {
    return Color(widget.lesson.color);
  }

  Widget _buildLoadingView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              color: Color(0xFF3B5BDB),
            ),
            const SizedBox(height: 18),
            Text(
              'Đang chuẩn bị nội dung bài học...',
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
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 18),
            Text(
              'Không thể tải nội dung bài học',
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
              onPressed: _prepareLesson,
              icon: const Icon(
                Icons.refresh_rounded,
              ),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.translate_rounded,
              size: 68,
              color: Color(0xFF3B5BDB),
            ),
            const SizedBox(height: 18),
            Text(
              'Chưa có từ vựng',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Bài học này hiện chưa có dữ liệu từ vựng.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: _prepareLesson,
              icon: const Icon(
                Icons.add_rounded,
              ),
              label: const Text(
                'Tạo dữ liệu mẫu',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVocabularyCard({
    required Vocabulary vocabulary,
    required Color lessonColor,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        20,
        12,
        20,
        20,
      ),
      child: Card(
        elevation: 0,
        color: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
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
                      color: lessonColor.withValues(
                        alpha: 0.12,
                      ),
                      borderRadius:
                          BorderRadius.circular(20),
                    ),
                    child: Text(
                      vocabulary.displayPartOfSpeech,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: lessonColor,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.bookmark_border_rounded,
                    color: lessonColor,
                  ),
                ],
              ),
              const SizedBox(height: 30),
              Text(
                vocabulary.word,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              if (vocabulary.pronunciation
                  .trim()
                  .isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  vocabulary.pronunciation,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    fontStyle: FontStyle.italic,
                    color: lessonColor,
                  ),
                ),
              ],
              const SizedBox(height: 28),
              const Divider(),
              const SizedBox(height: 20),
              Text(
                'Nghĩa tiếng Việt',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                vocabulary.meaning,
                style: TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              if (vocabulary.example.trim().isNotEmpty) ...[
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: lessonColor.withValues(
                      alpha: 0.07,
                    ),
                    borderRadius:
                        BorderRadius.circular(16),
                    border: Border.all(
                      color: lessonColor.withValues(
                        alpha: 0.16,
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.format_quote_rounded,
                            color: lessonColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Ví dụ',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        vocabulary.example,
                        style: TextStyle(
                          fontSize: 17,
                          height: 1.5,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      if (vocabulary.exampleMeaning
                          .trim()
                          .isNotEmpty) ...[
                        const SizedBox(height: 9),
                        Text(
                          vocabulary.exampleMeaning,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLessonContent(
    List<Vocabulary> vocabularies,
  ) {
    final Color lessonColor = _getLessonColor();
    final int totalWords = vocabularies.length;

    if (_currentIndex >= totalWords) {
      _currentIndex = totalWords - 1;
    }

    final double progress =
        totalWords == 0
            ? 0
            : (_currentIndex + 1) / totalWords;

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
            color: lessonColor,
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
                widget.lesson.topic,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                widget.lesson.title,
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius:
                          BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 9,
                        backgroundColor:
                            Colors.white24,
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
                    '${_currentIndex + 1}/$totalWords từ',
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
            itemCount: totalWords,
            onPageChanged: (int index) {
              setState(() {
                _currentIndex = index;
              });

              _saveViewedWords(
                viewedWords: index + 1,
                totalWords: totalWords,
              );
            },
            itemBuilder: (
              BuildContext context,
              int index,
            ) {
              return _buildVocabularyCard(
                vocabulary: vocabularies[index],
                lessonColor: lessonColor,
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
                    onPressed: _currentIndex > 0 &&
                            !_isSavingProgress
                        ? _goToPreviousWord
                        : null,
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                    ),
                    label: const Text('Trước'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: lessonColor,
                      padding:
                          const EdgeInsets.symmetric(
                        vertical: 15,
                      ),
                      side: BorderSide(
                        color: _currentIndex > 0
                            ? lessonColor
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
                    onPressed: _isSavingProgress
                        ? null
                        : () {
                            _goToNextWord(totalWords);
                          },
                    icon: _isSavingProgress
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
                            _currentIndex ==
                                    totalWords - 1
                                ? Icons.check_rounded
                                : Icons
                                    .arrow_forward_rounded,
                          ),
                    label: Text(
                      _isSavingProgress
                          ? 'Đang lưu...'
                          : _currentIndex ==
                                  totalWords - 1
                              ? 'Hoàn thành'
                              : 'Tiếp theo',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: lessonColor,
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
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Chi tiết bài học',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: _getLessonColor(),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Builder(
          builder: (BuildContext context) {
            if (_isPreparingData) {
              return _buildLoadingView();
            }

            if (_preparationError != null) {
              return _buildErrorView(
                _preparationError!,
              );
            }

            return StreamBuilder<List<Vocabulary>>(
              stream: _vocabularyService
                  .getActiveVocabularies(
                widget.lesson.id,
              ),
              builder: (
                BuildContext context,
                AsyncSnapshot<List<Vocabulary>> snapshot,
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

                final List<Vocabulary> vocabularies =
                    snapshot.data ?? <Vocabulary>[];

                if (vocabularies.isEmpty) {
                  return _buildEmptyView();
                }

                return _buildLessonContent(
                  vocabularies,
                );
              },
            );
          },
        ),
      ),
    );
  }
}
