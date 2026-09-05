import 'package:flutter/material.dart';

import '../models/shadowing_lesson.dart';
import '../services/shadowing_lesson_service.dart';
import '../widgets/responsive_card_grid.dart';
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

  /// Icon theo từng chủ đề Shadowing (khóa `iconName` do Firestore
  /// lưu). Trả về icon mặc định nếu bài chưa gán hoặc gán key lạ -
  /// giữ tương thích ngược với các bài Shadowing mẫu cũ chưa có
  /// trường này.
  IconData _iconForName(String iconName) {
    switch (iconName.trim().toLowerCase()) {
      case 'workplace':
        return Icons.work_outline_rounded;
      case 'restaurant':
        return Icons.restaurant_rounded;
      case 'flight':
        return Icons.flight_takeoff_rounded;
      case 'badge':
        return Icons.badge_rounded;
      case 'shopping_bag':
        return Icons.shopping_bag_rounded;
      case 'map':
        return Icons.signpost_rounded;
      case 'call':
        return Icons.call_rounded;
      case 'person':
        return Icons.person_rounded;
      case 'weather':
        return Icons.wb_cloudy_rounded;
      case 'health':
        return Icons.medical_services_rounded;
      case 'bank':
        return Icons.account_balance_rounded;
      case 'travel':
        return Icons.luggage_rounded;
      case 'technology':
        return Icons.devices_rounded;
      case 'family':
        return Icons.family_restroom_rounded;
      case 'hobbies':
        return Icons.palette_rounded;
      case 'sports':
        return Icons.sports_soccer_rounded;
      case 'study':
        return Icons.school_rounded;
      case 'cafe':
        return Icons.local_cafe_rounded;
      case 'apology':
        return Icons.volunteer_activism_rounded;
      case 'negotiation':
        return Icons.handshake_rounded;
      default:
        return Icons.record_voice_over_rounded;
    }
  }

  /// Chuyển mã hex ("#4A6FA5" hoặc "4A6FA5") thành [Color]. Trả về
  /// null nếu chuỗi rỗng hoặc không hợp lệ, để màn hình dùng màu mặc
  /// định thay vì crash.
  Color? _parseThemeColor(String themeColor) {
    final String hex = themeColor.trim().replaceFirst('#', '');

    if (hex.length != 6) {
      return null;
    }

    final int? value = int.tryParse('FF$hex', radix: 16);

    if (value == null) {
      return null;
    }

    return Color(value);
  }

  Widget _buildLessonCard(ShadowingLesson lesson) {
    final Color levelColor = _levelColor(lesson.level);
    final Color themeColor = _parseThemeColor(lesson.themeColor) ?? _accentColor;
    final IconData themeIcon = _iconForName(lesson.iconName);

    return Card(
      margin: EdgeInsets.zero,
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 108,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    themeColor.withValues(alpha: 0.85),
                    themeColor.withValues(alpha: 0.5),
                  ],
                ),
              ),
              child: Icon(
                themeIcon,
                color: Colors.white,
                size: 42,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(13),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lesson.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        height: 1.25,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (lesson.description.trim().isNotEmpty)
                      Expanded(
                        child: Text(
                          lesson.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.35,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                      )
                    else
                      const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: levelColor.withValues(alpha: 0.14),
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
                  ],
                ),
              ),
            ),
          ],
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

                  return ResponsiveCardGrid(
                    cardHeight: 236,
                    itemCount: lessons.length,
                    itemBuilder: (BuildContext context, int index) {
                      return _buildLessonCard(lessons[index]);
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
