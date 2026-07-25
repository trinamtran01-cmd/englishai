import 'package:flutter/material.dart';

import '../models/lesson.dart';
import '../services/lesson_service.dart';
import 'lesson_detail_screen.dart';

class LessonListScreen extends StatefulWidget {
  const LessonListScreen({super.key});

  @override
  State<LessonListScreen> createState() =>
      _LessonListScreenState();
}

class _LessonListScreenState
    extends State<LessonListScreen> {
  final LessonService _lessonService = LessonService();

  bool _isCreatingSampleData = false;
  String? _sampleDataError;

  @override
  void initState() {
    super.initState();
    _prepareSampleLessons();
  }

  Future<void> _prepareSampleLessons() async {
    if (mounted) {
      setState(() {
        _isCreatingSampleData = true;
        _sampleDataError = null;
      });
    }

    try {
      await _lessonService.createSampleLessons();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _sampleDataError = error.toString();
      });
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isCreatingSampleData = false;
    });
  }

  /// Mở màn hình chi tiết của bài học được chọn.
  void _openLesson(Lesson lesson) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return LessonDetailScreen(
            lesson: lesson,
          );
        },
      ),
    );
  }

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

      case 'menu_book':
        return Icons.menu_book_rounded;

      default:
        return Icons.auto_stories_rounded;
    }
  }

  Color _getLessonColor(int colorValue) {
    try {
      return Color(colorValue);
    } catch (_) {
      return const Color(0xFF3B5BDB);
    }
  }

  Widget _buildLessonCard({
    required Lesson lesson,
    required int lessonNumber,
  }) {
    final Color lessonColor =
        _getLessonColor(lesson.color);

    final IconData lessonIcon =
        _getLessonIcon(lesson.icon);

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
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          _openLesson(lesson);
        },
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 60,
                height: 60,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: lessonColor.withValues(
                    alpha: 0.12,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  lessonIcon,
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
                      'Bài $lessonNumber • ${lesson.topic}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      lesson.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: lessonColor.withValues(
                    alpha: 0.1,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: lessonColor,
                ),
              ),
            ],
          ),
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
              'Đang tải danh sách bài học...',
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

  Widget _buildErrorView({
    required String message,
  }) {
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
            const Text(
              'Không thể tải bài học',
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
              onPressed: _isCreatingSampleData
                  ? null
                  : _prepareSampleLessons,
              icon: _isCreatingSampleData
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.refresh_rounded),
              label: Text(
                _isCreatingSampleData
                    ? 'Đang thử lại...'
                    : 'Thử lại',
              ),
              style: FilledButton.styleFrom(
                backgroundColor:
                    const Color(0xFF3B5BDB),
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
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.menu_book_outlined,
              color: Color(0xFF3B5BDB),
              size: 68,
            ),
            const SizedBox(height: 18),
            const Text(
              'Chưa có bài học',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Hãy tạo dữ liệu bài học mẫu để bắt đầu.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: _isCreatingSampleData
                  ? null
                  : _prepareSampleLessons,
              icon: _isCreatingSampleData
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.add_rounded),
              label: Text(
                _isCreatingSampleData
                    ? 'Đang tạo dữ liệu...'
                    : 'Tạo bài học mẫu',
              ),
              style: FilledButton.styleFrom(
                backgroundColor:
                    const Color(0xFF3B5BDB),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLessonList(
    List<Lesson> lessons,
  ) {
    return RefreshIndicator(
      color: const Color(0xFF3B5BDB),
      onRefresh: _prepareSampleLessons,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
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
      backgroundColor: const Color(0xFFF5F7FF),
      appBar: AppBar(
        title: const Text(
          'Bài học tiếng Anh',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF3B5BDB),
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
                color: Color(0xFF3B5BDB),
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
                    'Học theo từng chủ đề',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 7),
                  Text(
                    'Chọn một bài học để bắt đầu nâng cao vốn tiếng Anh.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Builder(
                builder: (BuildContext context) {
                  if (_isCreatingSampleData) {
                    return _buildLoadingView();
                  }

                  if (_sampleDataError != null) {
                    return _buildErrorView(
                      message: _sampleDataError!,
                    );
                  }

                  return StreamBuilder<List<Lesson>>(
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
                          message:
                              snapshot.error.toString(),
                        );
                      }

                      final List<Lesson> lessons =
                          snapshot.data ?? <Lesson>[];

                      if (lessons.isEmpty) {
                        return _buildEmptyView();
                      }

                      return _buildLessonList(lessons);
                    },
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