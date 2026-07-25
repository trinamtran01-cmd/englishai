import 'package:flutter/material.dart';

import '../models/learning_progress.dart';
import '../services/progress_service.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() =>
      _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  final ProgressService _progressService =
      ProgressService();

  String _formatDate(DateTime? dateTime) {
    if (dateTime == null) {
      return 'Chưa có dữ liệu';
    }

    final String day =
        dateTime.day.toString().padLeft(2, '0');
    final String month =
        dateTime.month.toString().padLeft(2, '0');
    final String year = dateTime.year.toString();

    final String hour =
        dateTime.hour.toString().padLeft(2, '0');
    final String minute =
        dateTime.minute.toString().padLeft(2, '0');

    return '$day/$month/$year • $hour:$minute';
  }

  Map<String, dynamic> _calculateSummary(
    List<LearningProgress> progressList,
  ) {
    final int totalLessons = progressList.length;

    final int completedLessons = progressList
        .where(
          (LearningProgress progress) =>
              progress.isCompleted,
        )
        .length;

    final int totalViewedWords =
        progressList.fold<int>(
      0,
      (
        int total,
        LearningProgress progress,
      ) {
        return total + progress.safeViewedWords;
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
  }

  Future<void> _confirmDeleteProgress(
    LearningProgress progress,
  ) async {
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text(
            'Xóa tiến độ',
          ),
          content: Text(
            'Bạn có chắc chắn muốn xóa tiến độ của bài '
            '"${progress.lessonTitle}" không?',
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
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Xóa'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true || !mounted) {
      return;
    }

    try {
      await _progressService.deleteLessonProgress(
        progress.lessonId,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Đã xóa tiến độ bài "${progress.lessonTitle}".',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Không thể xóa tiến độ: $error',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildSummaryCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE8EAF2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color,
              size: 23,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: const TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              height: 1.3,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummarySection(
    List<LearningProgress> progressList,
  ) {
    final Map<String, dynamic> summary =
        _calculateSummary(progressList);

    final int totalLessons =
        summary['totalLessons'] as int;

    final int completedLessons =
        summary['completedLessons'] as int;

    final int totalViewedWords =
        summary['totalViewedWords'] as int;

    final double averagePercentage =
        summary['averagePercentage'] as double;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tổng quan học tập',
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.35,
          children: [
            _buildSummaryCard(
              icon: Icons.menu_book_rounded,
              value: totalLessons.toString(),
              label: 'Bài đã bắt đầu',
              color: const Color(0xFF3B5BDB),
            ),
            _buildSummaryCard(
              icon: Icons.task_alt_rounded,
              value: completedLessons.toString(),
              label: 'Bài đã hoàn thành',
              color: const Color(0xFF2F9E44),
            ),
            _buildSummaryCard(
              icon: Icons.translate_rounded,
              value: totalViewedWords.toString(),
              label: 'Từ đã xem',
              color: const Color(0xFFF59F00),
            ),
            _buildSummaryCard(
              icon: Icons.trending_up_rounded,
              value:
                  '${averagePercentage.round()}%',
              label: 'Tiến độ trung bình',
              color: const Color(0xFF9C36B5),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProgressCard(
    LearningProgress progress,
  ) {
    final Color statusColor = progress.isCompleted
        ? const Color(0xFF2F9E44)
        : const Color(0xFF3B5BDB);

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(
          color: Color(0xFFE8EAF2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(
                      alpha: 0.12,
                    ),
                    borderRadius:
                        BorderRadius.circular(13),
                  ),
                  child: Icon(
                    progress.isCompleted
                        ? Icons.check_circle_rounded
                        : Icons.auto_stories_rounded,
                    color: statusColor,
                    size: 27,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        progress.lessonTitle.isEmpty
                            ? 'Bài học'
                            : progress.lessonTitle,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        progress.isCompleted
                            ? 'Đã hoàn thành'
                            : 'Đang học',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Tùy chọn',
                  onSelected: (String value) {
                    if (value == 'delete') {
                      _confirmDeleteProgress(progress);
                    }
                  },
                  itemBuilder:
                      (BuildContext context) {
                    return const [
                      PopupMenuItem<String>(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_outline_rounded,
                              color: Colors.red,
                            ),
                            SizedBox(width: 10),
                            Text('Xóa tiến độ'),
                          ],
                        ),
                      ),
                    ];
                  },
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Text(
                  '${progress.safeViewedWords}/${progress.totalWords} từ',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
                const Spacer(),
                Text(
                  '${progress.roundedPercentage}%',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress.progressValue,
                minHeight: 9,
                backgroundColor:
                    statusColor.withValues(alpha: 0.12),
                valueColor:
                    AlwaysStoppedAnimation<Color>(
                  statusColor,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(
                  Icons.repeat_rounded,
                  size: 17,
                  color: Colors.grey,
                ),
                const SizedBox(width: 6),
                Text(
                  '${progress.studyCount} lần học',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                const Spacer(),
                const Icon(
                  Icons.schedule_rounded,
                  size: 17,
                  color: Colors.grey,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    _formatDate(
                      progress.lastStudiedAt,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
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
            CircularProgressIndicator(
              color: Color(0xFF3B5BDB),
            ),
            SizedBox(height: 18),
            Text(
              'Đang tải tiến độ học tập...',
              style: TextStyle(
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
              Icons.cloud_off_rounded,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 18),
            const Text(
              'Không thể tải tiến độ',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
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
              onPressed: () {
                setState(() {});
              },
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
                color: const Color(0xFF3B5BDB)
                    .withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.bar_chart_rounded,
                size: 50,
                color: Color(0xFF3B5BDB),
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'Chưa có tiến độ học tập',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Hãy mở một bài học và bắt đầu học từ vựng. '
              'Tiến độ của bạn sẽ được hiển thị tại đây.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
              },
              icon: const Icon(
                Icons.menu_book_rounded,
              ),
              label: const Text(
                'Quay về học bài',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
    List<LearningProgress> progressList,
  ) {
    return RefreshIndicator(
      color: const Color(0xFF3B5BDB),
      onRefresh: () async {
        setState(() {});
        await Future<void>.delayed(
          const Duration(milliseconds: 400),
        );
      },
      child: ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          20,
          24,
          20,
          32,
        ),
        children: [
          _buildSummarySection(progressList),
          const SizedBox(height: 30),
          const Text(
            'Tiến độ từng bài',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            'Theo dõi quá trình học của từng bài học.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 18),
          ...progressList.map(
            (LearningProgress progress) {
              return _buildProgressCard(progress);
            },
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
          'Tiến độ học tập',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF2F9E44),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: StreamBuilder<List<LearningProgress>>(
          stream:
              _progressService.getCurrentUserProgress(),
          builder: (
            BuildContext context,
            AsyncSnapshot<List<LearningProgress>>
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

            final List<LearningProgress> progressList =
                snapshot.data ??
                    <LearningProgress>[];

            if (progressList.isEmpty) {
              return _buildEmptyView();
            }

            return _buildContent(progressList);
          },
        ),
      ),
    );
  }
}