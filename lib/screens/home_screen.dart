import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/feature_flag.dart';
import '../services/auth_service.dart';
import '../services/feature_flag_service.dart';
import 'ai_camera_scan_screen.dart';
import 'ai_dictionary_screen.dart';
import 'ai_recommendation_screen.dart';
import 'lesson_list_screen.dart';
import 'listening_video_list_screen.dart';
import 'progress_screen.dart';
import 'quiz_list_screen.dart';
import 'shadowing_lesson_list_screen.dart';
import 'writing_task_list_screen.dart';

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
  static const String featureIdAiCamera = 'ai_camera';
  static const String featureIdAiDictionary = 'ai_dictionary';
  static const String featureIdListeningSpeaking =
      'listening_speaking';
  static const String featureIdShadowing = 'shadowing';
  static const String featureIdWriting = 'writing';

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

  /// Mở màn hình chụp ảnh nhận diện từ vựng bằng AI.
  void _openAiCameraScanScreen() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return const AiCameraScanScreen();
        },
      ),
    );
  }

  /// Mở màn hình Từ điển AI.
  void _openAiDictionaryScreen() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return const AiDictionaryScreen();
        },
      ),
    );
  }

  /// Mở màn hình danh sách bài luyện nghe & nói AI.
  void _openListeningVideoListScreen() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return const ListeningVideoListScreen();
        },
      ),
    );
  }

  /// Mở màn hình danh sách bài luyện Shadowing.
  void _openShadowingLessonListScreen() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return const ShadowingLessonListScreen();
        },
      ),
    );
  }

  /// Mở màn hình danh sách đề bài Luyện Viết AI.
  void _openWritingTaskListScreen() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return const WritingTaskListScreen();
        },
      ),
    );
  }

  Widget _buildDevelopingBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF59F00).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        'Đang phát triển',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Color(0xFFF59F00),
        ),
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required VoidCallback onTap,
    required bool isEnabled,
    required String disabledMessage,
  }) {
    return Opacity(
      opacity: isEnabled ? 1 : 0.5,
      child: Card(
        elevation: 0,
        color: Theme.of(context).colorScheme.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: InkWell(
          onTap: isEnabled
              ? onTap
              : () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(disabledMessage),
                      backgroundColor: const Color(0xFF495057),
                    ),
                  );
                },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 29,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                          if (!isEnabled) ...[
                            const SizedBox(width: 8),
                            _buildDevelopingBadge(),
                          ],
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 17,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
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
      return _buildFeatureCard(
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
      cardFor(
        featureId: featureIdAiCamera,
        icon: Icons.camera_alt_rounded,
        title: 'AI Camera từ vựng',
        description:
            'Chụp ảnh vật thể để AI tự tạo từ vựng mới cho bạn.',
        color: const Color(0xFFE64980),
        onTap: _openAiCameraScanScreen,
      ),
      const SizedBox(height: 12),
      cardFor(
        featureId: featureIdAiDictionary,
        icon: Icons.menu_book_outlined,
        title: 'Từ điển AI',
        description:
            'Gõ một từ hoặc cụm từ tiếng Anh để AI tra nghĩa ngay.',
        color: const Color(0xFF20C997),
        onTap: _openAiDictionaryScreen,
      ),
      const SizedBox(height: 12),
      cardFor(
        featureId: featureIdListeningSpeaking,
        icon: Icons.headphones_rounded,
        title: 'Luyện Nghe & Nói AI',
        description:
            'Nghe video, điền từ và luyện nói cùng AI phân tích.',
        color: const Color(0xFF0C8599),
        onTap: _openListeningVideoListScreen,
      ),
      const SizedBox(height: 12),
      cardFor(
        featureId: featureIdShadowing,
        icon: Icons.record_voice_over_rounded,
        title: 'Luyện Shadowing',
        description:
            'Nghe từng câu, ghi âm nhại lại và xem AI chấm '
            'điểm phát âm.',
        color: const Color(0xFF7048E8),
        onTap: _openShadowingLessonListScreen,
      ),
      const SizedBox(height: 12),
      cardFor(
        featureId: featureIdWriting,
        icon: Icons.edit_note_rounded,
        title: 'Luyện Viết AI',
        description:
            'Viết bài IELTS Task 1/2 và được AI chấm điểm chi tiết.',
        color: const Color(0xFFE8590C),
        onTap: _openWritingTaskListScreen,
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