import 'package:flutter/material.dart';

import '../../models/feature_flag.dart';
import '../../services/admin_service.dart';
import '../../services/feature_flag_service.dart';

/// Định nghĩa tĩnh của 1 tính năng có thể bật/tắt.
///
/// [id] PHẢI khớp với các hằng `featureId...` khai báo trong
/// `home_screen.dart` (4 tính năng đầu) và `english_ai_features_screen.dart`
/// (5 tính năng còn lại, gom trong nhóm "English AI") — đây là danh
/// sách tính năng học viên nhìn thấy.
class _FeatureDefinition {
  final String id;
  final String defaultLabel;
  final IconData icon;
  final Color color;

  const _FeatureDefinition({
    required this.id,
    required this.defaultLabel,
    required this.icon,
    required this.color,
  });
}

const List<_FeatureDefinition> _featureDefinitions = [
  _FeatureDefinition(
    id: 'lessons',
    defaultLabel: 'Bài học tiếng Anh',
    icon: Icons.menu_book_rounded,
    color: Color(0xFF3B5BDB),
  ),
  _FeatureDefinition(
    id: 'quiz',
    defaultLabel: 'Kiểm tra kiến thức',
    icon: Icons.quiz_rounded,
    color: Color(0xFFF59F00),
  ),
  _FeatureDefinition(
    id: 'ai_recommendation',
    defaultLabel: 'Gợi ý từ AI',
    icon: Icons.auto_awesome_rounded,
    color: Color(0xFF9C36B5),
  ),
  _FeatureDefinition(
    id: 'progress',
    defaultLabel: 'Tiến độ học tập',
    icon: Icons.bar_chart_rounded,
    color: Color(0xFF2F9E44),
  ),
  _FeatureDefinition(
    id: 'ai_camera',
    defaultLabel: 'AI Camera từ vựng',
    icon: Icons.camera_alt_rounded,
    color: Color(0xFFE64980),
  ),
  _FeatureDefinition(
    id: 'ai_dictionary',
    defaultLabel: 'Từ điển AI',
    icon: Icons.menu_book_outlined,
    color: Color(0xFF20C997),
  ),
  _FeatureDefinition(
    id: 'listening_speaking',
    defaultLabel: 'Luyện Nghe & Nói AI',
    icon: Icons.headphones_rounded,
    color: Color(0xFF0C8599),
  ),
  _FeatureDefinition(
    id: 'shadowing',
    defaultLabel: 'Luyện Shadowing',
    icon: Icons.record_voice_over_rounded,
    color: Color(0xFF7048E8),
  ),
  _FeatureDefinition(
    id: 'writing',
    defaultLabel: 'Luyện Viết AI',
    icon: Icons.edit_note_rounded,
    color: Color(0xFFE8590C),
  ),
];

/// Trang quản trị bật/tắt tạm thời từng tính năng trên trang chủ.
///
/// Dùng khi cần tạm khóa 1 tính năng đang sửa lỗi/chưa ổn định,
/// thay vì để học viên vào dùng và gặp lỗi.
class AdminFeatureFlagsScreen extends StatefulWidget {
  const AdminFeatureFlagsScreen({super.key});

  @override
  State<AdminFeatureFlagsScreen> createState() =>
      _AdminFeatureFlagsScreenState();
}

class _AdminFeatureFlagsScreenState extends State<AdminFeatureFlagsScreen> {
  static const Color _accentColor = Color(0xFF364FC7);

  final AdminService _adminService = AdminService();

  final FeatureFlagService _featureFlagService = FeatureFlagService();

  String? _processingFeatureId;

  Future<void> _toggleFeature({
    required _FeatureDefinition feature,
    required bool isEnabled,
  }) async {
    setState(() {
      _processingFeatureId = feature.id;
    });

    try {
      await _adminService.requireAdmin();

      await _featureFlagService.setFeatureEnabled(
        feature.id,
        isEnabled,
        label: feature.defaultLabel,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể cập nhật trạng thái tính năng: $error'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _processingFeatureId = null;
        });
      }
    }
  }

  Future<void> _editDisabledMessage({
    required _FeatureDefinition feature,
    required FeatureFlag? currentFlag,
  }) async {
    final TextEditingController messageController = TextEditingController(
      text: currentFlag?.disabledMessage ?? FeatureFlag.defaultDisabledMessage,
    );

    bool isSaving = false;

    final bool? wasSaved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder:
              (
                BuildContext context,
                void Function(void Function()) setDialogState,
              ) {
                Future<void> save() async {
                  if (isSaving) {
                    return;
                  }

                  setDialogState(() {
                    isSaving = true;
                  });

                  try {
                    await _adminService.requireAdmin();

                    await _featureFlagService.setFeatureEnabled(
                      feature.id,
                      currentFlag?.isEnabled ?? true,
                      label: feature.defaultLabel,
                      disabledMessage: messageController.text,
                    );

                    if (!dialogContext.mounted) {
                      return;
                    }

                    Navigator.of(dialogContext).pop(true);
                  } catch (error) {
                    if (!dialogContext.mounted) {
                      return;
                    }

                    setDialogState(() {
                      isSaving = false;
                    });

                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(
                        content: Text('Không thể lưu thông báo: $error'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }

                return AlertDialog(
                  title: Text('Thông báo khi khóa "${feature.defaultLabel}"'),
                  content: TextField(
                    controller: messageController,
                    enabled: !isSaving,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Nội dung thông báo',
                      alignLabelWithHint: true,
                      hintText: 'Hiện cho học viên khi tính năng đang bị khóa',
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: isSaving
                          ? null
                          : () {
                              Navigator.of(dialogContext).pop(false);
                            },
                      child: const Text('Hủy'),
                    ),
                    FilledButton.icon(
                      onPressed: isSaving ? null : save,
                      style: FilledButton.styleFrom(
                        backgroundColor: _accentColor,
                        foregroundColor: Colors.white,
                      ),
                      icon: isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.save_rounded),
                      label: Text(isSaving ? 'Đang lưu...' : 'Lưu'),
                    ),
                  ],
                );
              },
        );
      },
    );

    messageController.dispose();

    if (wasSaved != true || !mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã cập nhật thông báo.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Widget _buildFeatureRow({
    required _FeatureDefinition feature,
    required FeatureFlag? flag,
  }) {
    final bool isEnabled = flag?.isEnabled ?? true;
    final bool isProcessing = _processingFeatureId == feature.id;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: feature.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(feature.icon, color: feature.color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    flag?.label ?? feature.defaultLabel,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    isEnabled ? 'Đang hoạt động' : 'Đang bị khóa',
                    style: TextStyle(
                      fontSize: 12,
                      color: isEnabled
                          ? const Color(0xFF2F9E44)
                          : const Color(0xFFE8590C),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Sửa thông báo khi khóa',
              onPressed: isProcessing
                  ? null
                  : () {
                      _editDisabledMessage(feature: feature, currentFlag: flag);
                    },
              icon: Icon(
                Icons.edit_note_rounded,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (isProcessing)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: _accentColor,
                    strokeWidth: 2,
                  ),
                ),
              )
            else
              Switch(
                value: isEnabled,
                activeThumbColor: _accentColor,
                onChanged: (bool value) {
                  _toggleFeature(feature: feature, isEnabled: value);
                },
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
          'Quản lý tính năng',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: _accentColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: StreamBuilder<Map<String, FeatureFlag>>(
          stream: _featureFlagService.getAllFlags(),
          builder:
              (
                BuildContext context,
                AsyncSnapshot<Map<String, FeatureFlag>> snapshot,
              ) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: _accentColor),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Text(
                        'Không thể tải danh sách tính năng: '
                        '${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                final Map<String, FeatureFlag> flags =
                    snapshot.data ?? <String, FeatureFlag>{};

                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 900),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              margin: const EdgeInsets.only(bottom: 20),
                              decoration: BoxDecoration(
                                color: _accentColor.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: _accentColor.withValues(alpha: 0.16),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.info_outline_rounded,
                                    color: _accentColor,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Tắt 1 tính năng sẽ làm mờ card tương ứng '
                                      'trên trang chủ học viên và chặn truy cập, '
                                      'kèm badge "Đang phát triển".',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        height: 1.4,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurface,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            for (final _FeatureDefinition feature
                                in _featureDefinitions)
                              _buildFeatureRow(
                                feature: feature,
                                flag: flags[feature.id],
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
        ),
      ),
    );
  }
}
