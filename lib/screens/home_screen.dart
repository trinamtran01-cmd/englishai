import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/feature_flag.dart';
import '../services/auth_service.dart';
import '../services/feature_flag_service.dart';
import '../widgets/feature_card.dart';
import 'ai_recommendation_screen.dart';
import 'english_ai_features_screen.dart';
import 'lesson_list_screen.dart';
import 'progress_screen.dart';
import 'quiz_list_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  final FeatureFlagService _featureFlagService = FeatureFlagService();

  bool _isLoggingOut = false;

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
      const SizedBox(height: 12),
      cardFor(
        featureId: featureIdQuiz,
        icon: Icons.quiz_rounded,
        title: 'Kiểm tra kiến thức',
        description:
            'Làm bài trắc nghiệm và đánh giá kết quả học tập.',
        color: const Color(0xFFF59F00),
        onTap: _openQuizList,
      ),
      const SizedBox(height: 12),
      cardFor(
        featureId: featureIdAiRecommendation,
        icon: Icons.auto_awesome_rounded,
        title: 'Gợi ý từ AI',
        description:
            'Phân tích điểm yếu và đề xuất bài học phù hợp.',
        color: const Color(0xFF9C36B5),
        onTap: _openAiRecommendationScreen,
      ),
      const SizedBox(height: 12),
      cardFor(
        featureId: featureIdProgress,
        icon: Icons.bar_chart_rounded,
        title: 'Tiến độ học tập',
        description: 'Theo dõi điểm số và quá trình học của bạn.',
        color: const Color(0xFF2F9E44),
        onTap: _openProgressScreen,
      ),
      const SizedBox(height: 12),
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

  @override
  Widget build(BuildContext context) {
    final User? user = _authService.currentUser;

    final String rawDisplayName =
        user?.displayName?.trim() ?? '';

    final String displayName =
        rawDisplayName.isNotEmpty
            ? rawDisplayName
            : 'Bạn';

    final String email =
        user?.email ?? 'Chưa có email';

    final String avatarLetter =
        displayName.isNotEmpty
            ? displayName.substring(0, 1).toUpperCase()
            : 'B';

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'English AI',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF3B5BDB),
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            20,
            24,
            20,
            32,
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF3B5BDB),
                      Color(0xFF748FFC),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius:
                      BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF3B5BDB)
                          .withValues(alpha: 0.22),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        avatarLetter,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF3B5BDB),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Xin chào,',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            displayName,
                            maxLines: 1,
                            overflow:
                                TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 21,
                              fontWeight:
                                  FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            email,
                            maxLines: 1,
                            overflow:
                                TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

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

              StreamBuilder<Map<String, FeatureFlag>>(
                stream: _featureFlagService.getAllFlags(),
                builder: (
                  BuildContext context,
                  AsyncSnapshot<Map<String, FeatureFlag>> snapshot,
                ) {
                  final Map<String, FeatureFlag> flags =
                      snapshot.data ?? <String, FeatureFlag>{};

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _buildFeatureCards(flags),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}