import 'package:flutter/material.dart';

import '../models/feature_flag.dart';
import '../services/feature_flag_service.dart';
import '../widgets/feature_card.dart';
import 'ai_camera_scan_screen.dart';
import 'ai_dictionary_screen.dart';
import 'listening_video_list_screen.dart';
import 'shadowing_lesson_list_screen.dart';
import 'writing_task_list_screen.dart';

/// Màn hình gom nhóm 5 tính năng AI luyện tập tiếng Anh, tách ra khỏi
/// trang chủ (`home_screen.dart`) để danh sách trang chủ gọn hơn.
///
/// Giữ nguyên toàn bộ logic của từng thẻ con: badge "Đang phát triển"
/// + khóa tạm theo `FeatureFlagService`, và đường dẫn điều hướng tới
/// đúng màn hình như khi còn nằm trên trang chủ.
class EnglishAiFeaturesScreen extends StatefulWidget {
  const EnglishAiFeaturesScreen({super.key});

  @override
  State<EnglishAiFeaturesScreen> createState() =>
      _EnglishAiFeaturesScreenState();
}

class _EnglishAiFeaturesScreenState
    extends State<EnglishAiFeaturesScreen> {
  static const Color _accentColor = Color(0xFF5F3DC4);

  final FeatureFlagService _featureFlagService = FeatureFlagService();

  // ID của từng tính năng, phải khớp với id dùng trong
  // AdminFeatureFlagsScreen để Admin bật/tắt đúng mục.
  static const String featureIdAiCamera = 'ai_camera';
  static const String featureIdAiDictionary = 'ai_dictionary';
  static const String featureIdListeningSpeaking = 'listening_speaking';
  static const String featureIdShadowing = 'shadowing';
  static const String featureIdWriting = 'writing';

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
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'English AI',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: _accentColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: StreamBuilder<Map<String, FeatureFlag>>(
          stream: _featureFlagService.getAllFlags(),
          builder: (
            BuildContext context,
            AsyncSnapshot<Map<String, FeatureFlag>> snapshot,
          ) {
            final Map<String, FeatureFlag> flags =
                snapshot.data ?? <String, FeatureFlag>{};

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: _buildFeatureCards(flags),
            );
          },
        ),
      ),
    );
  }
}
