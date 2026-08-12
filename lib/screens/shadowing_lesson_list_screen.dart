import 'package:flutter/material.dart';

import '../models/shadowing_lesson.dart';
import '../services/shadowing_lesson_service.dart';
import 'shadowing_practice_screen.dart';

/// Danh sách các bài luyện Shadowing (nghe & nhại lại câu) dành cho
/// học viên.
class ShadowingLessonListScreen extends StatefulWidget {
  const ShadowingLessonListScreen({super.key});

  @override
  State<ShadowingLessonListScreen> createState() =>
      _ShadowingLessonListScreenState();
}

class _ShadowingLessonListScreenState
    extends State<ShadowingLessonListScreen> {
  static const Color _accentColor = Color(0xFF7048E8);

  final ShadowingLessonService _lessonService =
      ShadowingLessonService();

  /// Mở màn hình luyện tập cho bài Shadowing được chọn.
  void _openPractice(ShadowingLesson lesson) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return ShadowingPracticeScreen(lesson: lesson);
        },
      ),
    );
  }

  Color _levelColor(String level) {
    switch (level.trim().toLowerCase()) {
      case 'intermediate':
        return const Color(0xFFF59F00);

      case 'advanced':
        return const Color(0xFFE03131);

      case 'beginner':
      default:
        return const Color(0xFF2F9E44);
    }
  }

  Widget _buildLessonCard(ShadowingLesson lesson) {
    final Color levelColor = _levelColor(lesson.level);

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          _openPractice(lesson);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.record_voice_over_rounded,
                  color: _accentColor,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: levelColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        lesson.levelLabel,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: levelColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      lesson.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    if (lesson.description.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        lesson.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
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
            const CircularProgressIndicator(color: _accentColor),
            const SizedBox(height: 18),
            Text(
              'Đang tải danh sách bài luyện Shadowing...',
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
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              color: Colors.red,
              size: 62,
            ),
            const SizedBox(height: 18),
            Text(
              'Không thể tải danh sách',
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
              Icons.record_voice_over_outlined,
              color: _accentColor,
              size: 68,
            ),
            const SizedBox(height: 18),
            Text(
              'Chưa có bài luyện Shadowing',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Quản trị viên chưa thêm bài luyện Shadowing nào. '
              'Vui lòng quay lại sau.',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Luyện Shadowing',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: _accentColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
              decoration: const BoxDecoration(
                color: _accentColor,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(26),
                  bottomRight: Radius.circular(26),
                ),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nghe và nhại lại từng câu',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 7),
                  Text(
                    'Chọn một bài để bắt đầu: nghe câu mẫu, ghi âm '
                    'nhại lại, rồi xem AI chấm từng từ và nhận xét '
                    'phát âm.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<List<ShadowingLesson>>(
                stream: _lessonService.getAllLessons(),
                builder: (
                  BuildContext context,
                  AsyncSnapshot<List<ShadowingLesson>> snapshot,
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

                  final List<ShadowingLesson> lessons =
                      snapshot.data ?? <ShadowingLesson>[];

                  if (lessons.isEmpty) {
                    return _buildEmptyView();
                  }

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(
                      20,
                      20,
                      20,
                      32,
                    ),
                    children: lessons.map(_buildLessonCard).toList(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
