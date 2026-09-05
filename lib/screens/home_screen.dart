import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/feature_flag.dart';
import '../models/learning_progress.dart';
import '../models/lesson.dart';
import '../services/auth_service.dart';
import '../services/feature_flag_service.dart';
import '../services/lesson_service.dart';
import '../services/progress_service.dart';
import '../widgets/feature_card.dart';
import 'ai_recommendation_screen.dart';
import 'english_ai_features_screen.dart';
import 'lesson_detail_screen.dart';
import 'lesson_list_screen.dart';
import 'progress_screen.dart';
import 'quiz_list_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const Color _accentColor = Color(0xFF3B5BDB);

  /// Ngưỡng chiều rộng chuyển từ layout mobile (1 cột) sang layout
  /// web (2 cột), cùng ngưỡng đã dùng ở Admin Dashboard/Writing task
  /// list.
  static const double _wideLayoutBreakpoint = 900;

  final AuthService _authService = AuthService();
  final FeatureFlagService _featureFlagService = FeatureFlagService();
  final ProgressService _progressService = ProgressService();
  final LessonService _lessonService = LessonService();

  bool _isLoggingOut = false;
  bool _isOpeningContinueLesson = false;

  // ID của từng tính năng, phải khớp với id dùng trong
  // AdminFeatureFlagsScreen để Admin bật/tắt đúng mục.
  static const String featureIdLessons = 'lessons';
  static const String featureIdQuiz = 'quiz';
  static const String featureIdAiRecommendation = 'ai_recommendation';
  static const String featureIdProgress = 'progress';

  Future<void> _handleLogout() async {
    final bool? shouldLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Đăng xuất'),
          content: const Text(
            'Bạn có chắc chắn muốn đăng xuất khỏi tài khoản không?',
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
              child: const Text('Đăng xuất'),
            ),
          ],
        );
      },
    );

    if (shouldLogout != true || !mounted) {
      return;
    }

    setState(() {
      _isLoggingOut = true;
    });

    try {
      await _authService.logout();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoggingOut = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Không thể đăng xuất. Vui lòng thử lại.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Mở màn hình danh sách bài học.
  void _openLessonList() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return const LessonListScreen();
        },
      ),
    );
  }

  /// Mở màn hình chọn bài kiểm tra.
  void _openQuizList() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return const QuizListScreen();
        },
      ),
    );
  }

  /// Mở màn hình gợi ý học tập từ AI.
  void _openAiRecommendationScreen() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return const AiRecommendationScreen();
        },
      ),
    );
  }

  /// Mở màn hình tiến độ học tập.
  void _openProgressScreen() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return const ProgressScreen();
        },
      ),
    );
  }

  /// Mở màn hình gom nhóm 5 tính năng English AI.
  void _openEnglishAiFeaturesScreen() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return const EnglishAiFeaturesScreen();
        },
      ),
    );
  }

  /// Mở tiếp bài học dở dang từ thẻ "Tiếp tục học". Tải lại đầy đủ
  /// [Lesson] theo `lessonId` (dữ liệu tiến độ chỉ lưu id + tiêu đề,
  /// không đủ để mở thẳng `LessonDetailScreen`). Nếu bài học không
  /// còn tồn tại (đã bị xóa) hoặc tải lỗi, mở danh sách bài học thay
  /// vì báo lỗi khô khan.
  Future<void> _continueLesson(LearningProgress progress) async {
    if (_isOpeningContinueLesson) {
      return;
    }

    setState(() {
      _isOpeningContinueLesson = true;
    });

    Lesson? lesson;

    try {
      lesson = await _lessonService.getLessonById(progress.lessonId);
    } catch (_) {
      lesson = null;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isOpeningContinueLesson = false;
    });

    if (lesson == null) {
      _openLessonList();
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return LessonDetailScreen(lesson: lesson!);
        },
      ),
    );
  }

  /// Xây danh sách card tính năng, áp dụng trạng thái bật/tắt từ
  /// [flags] (fail-open: tính năng chưa có flag coi như đang bật).
  List<Widget> _buildFeatureCards(Map<String, FeatureFlag> flags) {
    Widget cardFor({
      required String featureId,
      required IconData icon,
      required String title,
      required String description,
      required Color color,
      required VoidCallback onTap,
    }) {
      return FeatureCard(
        icon: icon,
        title: title,
        description: description,
        color: color,
        onTap: onTap,
        isEnabled: _featureFlagService.isFeatureEnabled(
          flags,
          featureId,
        ),
        disabledMessage: _featureFlagService.disabledMessageFor(
          flags,
          featureId,
        ),
      );
    }

    return [
      cardFor(
        featureId: featureIdLessons,
        icon: Icons.menu_book_rounded,
        title: 'Bài học tiếng Anh',
        description:
            'Học từ vựng và kiến thức tiếng Anh theo từng chủ đề.',
        color: const Color(0xFF3B5BDB),
        onTap: _openLessonList,
      ),
      cardFor(
        featureId: featureIdQuiz,
        icon: Icons.quiz_rounded,
        title: 'Kiểm tra kiến thức',
        description:
            'Làm bài trắc nghiệm và đánh giá kết quả học tập.',
        color: const Color(0xFFF59F00),
        onTap: _openQuizList,
      ),
      cardFor(
        featureId: featureIdAiRecommendation,
        icon: Icons.auto_awesome_rounded,
        title: 'Gợi ý từ AI',
        description:
            'Phân tích điểm yếu và đề xuất bài học phù hợp.',
        color: const Color(0xFF9C36B5),
        onTap: _openAiRecommendationScreen,
      ),
      cardFor(
        featureId: featureIdProgress,
        icon: Icons.bar_chart_rounded,
        title: 'Tiến độ học tập',
        description: 'Theo dõi điểm số và quá trình học của bạn.',
        color: const Color(0xFF2F9E44),
        onTap: _openProgressScreen,
      ),
      FeatureCard(
        icon: Icons.smart_toy_rounded,
        title: 'English AI',
        description:
            '5 công cụ luyện tập tiếng Anh bằng AI: Camera từ vựng, '
            'Từ điển, Nghe & Nói, Shadowing, Viết.',
        color: const Color(0xFF5F3DC4),
        onTap: _openEnglishAiFeaturesScreen,
      ),
    ];
  }

  /// Banner chào mừng - gọn hơn bản trước, có thêm 1 dòng số liệu
  /// thực tế lấy từ tiến độ học tập (không phải khối trang trí thuần
  /// túy).
  Widget _buildBanner({
    required String displayName,
    required String email,
    required String avatarLetter,
    required int completedCount,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3B5BDB), Color(0xFF748FFC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _accentColor.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Text(
              avatarLetter,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: _accentColor,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Xin chào, $displayName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  completedCount > 0
                      ? 'Đã hoàn thành $completedCount bài học · $email'
                      : email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionSideCard({
    required Widget child,
  }) {
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
      child: child,
    );
  }

  /// Thẻ "Tiếp tục học" - chỉ hiện khi có ít nhất 1 bài học đang dở
  /// dang (`isCompleted == false`), lấy thẳng từ dữ liệu tiến độ đã
  /// có sẵn (`ProgressService`), không cần cơ chế theo dõi mới.
  Widget _buildContinueLearningCard(LearningProgress progress) {
    return _buildSectionSideCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.play_circle_fill_rounded,
                color: _accentColor,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                'Tiếp tục học',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            progress.lessonTitle.trim().isEmpty
                ? 'Bài học'
                : progress.lessonTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: progress.progressValue,
              minHeight: 7,
              backgroundColor:
                  Theme.of(context).colorScheme.surfaceContainerHighest,
              color: _accentColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${progress.roundedPercentage}% hoàn thành',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isOpeningContinueLesson
                  ? null
                  : () {
                      _continueLesson(progress);
                    },
              icon: _isOpeningContinueLesson
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.arrow_forward_rounded, size: 18),
              label: const Text('Tiếp tục'),
              style: FilledButton.styleFrom(
                backgroundColor: _accentColor,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatRow({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  /// Thống kê nhanh - chỉ dùng số liệu đã có sẵn từ
  /// `ProgressService.getCurrentUserProgress()` (không có cơ chế
  /// streak/đăng nhập liên tục trong dữ liệu hiện có nên bỏ qua chỉ
  /// số đó thay vì tự bịa thêm).
  Widget _buildQuickStatsCard({
    required int completedCount,
    required int inProgressCount,
  }) {
    return _buildSectionSideCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Thống kê nhanh',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          _buildQuickStatRow(
            icon: Icons.check_circle_rounded,
            color: const Color(0xFF2F9E44),
            label: 'Bài đã hoàn thành',
            value: '$completedCount',
          ),
          _buildQuickStatRow(
            icon: Icons.hourglass_top_rounded,
            color: const Color(0xFFF59F00),
            label: 'Bài đang học dở',
            value: '$inProgressCount',
          ),
        ],
      ),
    );
  }

  /// Lưới 2 cột cố định cho các thẻ tính năng trên web - không dùng
  /// chung `ResponsiveCardGrid` vì widget đó tự chuyển 2↔3 cột theo
  /// chiều rộng, còn ở đây trong cột trái của layout 2 cột luôn cần
  /// đúng 2 cột bất kể chiều rộng cụ thể là bao nhiêu.
  Widget _buildFeatureGrid(Map<String, FeatureFlag> flags) {
    final List<Widget> cards = _buildFeatureCards(flags);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        const double spacing = 14;
        const double cardHeight = 120;

        final double columnWidth = (constraints.maxWidth - spacing) / 2;
        final double childAspectRatio = columnWidth / cardHeight;

        return GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: spacing,
          crossAxisSpacing: spacing,
          childAspectRatio: childAspectRatio,
          children: cards,
        );
      },
    );
  }

  Widget _buildFeatureList(Map<String, FeatureFlag> flags) {
    final List<Widget> cards = _buildFeatureCards(flags);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          cards[i],
        ],
      ],
    );
  }

  Widget _buildNarrowLayout({
    required String displayName,
    required String email,
    required String avatarLetter,
    required int completedCount,
    required Map<String, FeatureFlag> flags,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildBanner(
            displayName: displayName,
            email: email,
            avatarLetter: avatarLetter,
            completedCount: completedCount,
          ),
          const SizedBox(height: 24),
          Text(
            'Bạn muốn học gì hôm nay?',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            'Chọn một nội dung bên dưới để bắt đầu học tập.',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          _buildFeatureList(flags),
        ],
      ),
    );
  }

  Widget _buildWideLayout({
    required String displayName,
    required String email,
    required String avatarLetter,
    required int completedCount,
    required int inProgressCount,
    required LearningProgress? continueProgress,
    required Map<String, FeatureFlag> flags,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1300),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildBanner(
                displayName: displayName,
                email: email,
                avatarLetter: avatarLetter,
                completedCount: completedCount,
              ),
              const SizedBox(height: 26),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 65,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bạn muốn học gì hôm nay?',
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          'Chọn một nội dung bên dưới để bắt đầu học tập.',
                          style: TextStyle(
                            fontSize: 14,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 18),
                        _buildFeatureGrid(flags),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 35,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (continueProgress != null) ...[
                          _buildContinueLearningCard(continueProgress),
                          const SizedBox(height: 16),
                        ],
                        _buildQuickStatsCard(
                          completedCount: completedCount,
                          inProgressCount: inProgressCount,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final User? user = _authService.currentUser;

    final String rawDisplayName = user?.displayName?.trim() ?? '';

    final String displayName = rawDisplayName.isNotEmpty ? rawDisplayName : 'Bạn';

    final String email = user?.email ?? 'Chưa có email';

    final String avatarLetter =
        displayName.isNotEmpty ? displayName.substring(0, 1).toUpperCase() : 'B';

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'English AI',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: _accentColor,
        foregroundColor: Colors.white,
        actions: [
          if (_isLoggingOut)
            const Padding(
              padding: EdgeInsets.only(right: 18),
              child: Center(
                child: SizedBox(
                  width: 21,
                  height: 21,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
              ),
            )
          else
            IconButton(
              tooltip: 'Đăng xuất',
              onPressed: _handleLogout,
              icon: const Icon(
                Icons.logout_rounded,
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<List<LearningProgress>>(
          stream: _progressService.getCurrentUserProgress(),
          builder: (
            BuildContext context,
            AsyncSnapshot<List<LearningProgress>> progressSnapshot,
          ) {
            final List<LearningProgress> progressList =
                progressSnapshot.data ?? <LearningProgress>[];

            final int completedCount =
                progressList.where((LearningProgress p) => p.isCompleted).length;

            final int inProgressCount = progressList.length - completedCount;

            LearningProgress? continueProgress;

            for (final LearningProgress progress in progressList) {
              if (!progress.isCompleted) {
                continueProgress = progress;
                break;
              }
            }

            return StreamBuilder<Map<String, FeatureFlag>>(
              stream: _featureFlagService.getAllFlags(),
              builder: (
                BuildContext context,
                AsyncSnapshot<Map<String, FeatureFlag>> flagSnapshot,
              ) {
                final Map<String, FeatureFlag> flags =
                    flagSnapshot.data ?? <String, FeatureFlag>{};

                return LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final bool isWide =
                        constraints.maxWidth >= _wideLayoutBreakpoint;

                    if (isWide) {
                      return _buildWideLayout(
                        displayName: displayName,
                        email: email,
                        avatarLetter: avatarLetter,
                        completedCount: completedCount,
                        inProgressCount: inProgressCount,
                        continueProgress: continueProgress,
                        flags: flags,
                      );
                    }

                    return _buildNarrowLayout(
                      displayName: displayName,
                      email: email,
                      avatarLetter: avatarLetter,
                      completedCount: completedCount,
                      flags: flags,
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
