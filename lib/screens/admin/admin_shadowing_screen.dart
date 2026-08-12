import 'package:flutter/material.dart';

import '../../models/shadowing_lesson.dart';
import '../../models/shadowing_segment.dart';
import '../../services/admin_service.dart';
import '../../services/shadowing_lesson_service.dart';
import '../../utils/seed_shadowing_data.dart';

/// Trang quản trị nội dung bài luyện Shadowing.
///
/// Cho phép admin thêm, sửa, xóa các bài luyện Shadowing cùng danh
/// sách câu (segment) của từng bài.
class AdminShadowingScreen extends StatefulWidget {
  const AdminShadowingScreen({super.key});

  @override
  State<AdminShadowingScreen> createState() => _AdminShadowingScreenState();
}

class _AdminShadowingScreenState extends State<AdminShadowingScreen> {
  static const Color _accentColor = Color(0xFF7048E8);

  final AdminService _adminService = AdminService();

  final ShadowingLessonService _lessonService = ShadowingLessonService();

  List<ShadowingLesson> _lessons = <ShadowingLesson>[];

  String? _processingLessonId;
  String? _errorMessage;

  bool _isLoading = true;
  bool _isCreatingSampleData = false;

  @override
  void initState() {
    super.initState();
    _loadLessons();
  }

  /// Tải lại danh sách một lần (không dùng stream sống), cùng lý do
  /// với AdminListeningScreen: tránh crash khi dialog vừa đóng lại
  /// trùng lúc stream rebuild màn hình phía sau.
  Future<void> _loadLessons() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final List<ShadowingLesson> lessons = await _lessonService
          .getAllLessonsOnce();

      if (!mounted) {
        return;
      }

      setState(() {
        _lessons = lessons;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = error.toString();
      });
    }
  }

  Future<void> _createSampleLesson() async {
    if (_isCreatingSampleData) {
      return;
    }

    setState(() {
      _isCreatingSampleData = true;
    });

    try {
      await _adminService.requireAdmin();

      await seedSampleShadowingLesson();

      if (!mounted) {
        return;
      }

      setState(() {
        _isCreatingSampleData = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã kiểm tra và tạo dữ liệu bài luyện Shadowing mẫu.'),
          backgroundColor: Colors.green,
        ),
      );

      await _loadLessons();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isCreatingSampleData = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể tạo dữ liệu mẫu: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showLessonForm({ShadowingLesson? lesson}) async {
    final bool isEditing = lesson != null;

    final TextEditingController titleController = TextEditingController(
      text: lesson?.title ?? '',
    );

    final TextEditingController descriptionController = TextEditingController(
      text: lesson?.description ?? '',
    );

    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    String level = lesson?.level ?? 'beginner';
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
                Future<void> saveLesson() async {
                  if (!formKey.currentState!.validate() || isSaving) {
                    return;
                  }

                  setDialogState(() {
                    isSaving = true;
                  });

                  final ShadowingLesson lessonToSave = ShadowingLesson(
                    id: lesson?.id ?? '',
                    title: titleController.text.trim(),
                    description: descriptionController.text.trim(),
                    level: level,
                    createdAt: lesson?.createdAt,
                  );

                  try {
                    await _adminService.requireAdmin();

                    if (isEditing) {
                      await _lessonService.updateLesson(lessonToSave);
                    } else {
                      await _lessonService.addLesson(lessonToSave);
                    }

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
                        content: Text(
                          'Không thể lưu bài luyện Shadowing: $error',
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }

                return AlertDialog(
                  title: Text(
                    isEditing
                        ? 'Chỉnh sửa bài luyện Shadowing'
                        : 'Thêm bài luyện Shadowing mới',
                  ),
                  content: SizedBox(
                    width: 520,
                    child: SingleChildScrollView(
                      child: Form(
                        key: formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextFormField(
                              controller: titleController,
                              enabled: !isSaving,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Tiêu đề',
                                prefixIcon: Icon(Icons.title_rounded),
                              ),
                              validator: (String? value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Vui lòng nhập tiêu đề';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 15),
                            TextFormField(
                              controller: descriptionController,
                              enabled: !isSaving,
                              minLines: 2,
                              maxLines: 4,
                              decoration: const InputDecoration(
                                labelText: 'Mô tả',
                                alignLabelWithHint: true,
                                prefixIcon: Icon(Icons.notes_rounded),
                              ),
                            ),
                            const SizedBox(height: 15),
                            DropdownButtonFormField<String>(
                              initialValue: level,
                              decoration: const InputDecoration(
                                labelText: 'Mức độ',
                                prefixIcon: Icon(
                                  Icons.signal_cellular_alt_rounded,
                                ),
                              ),
                              items: const [
                                DropdownMenuItem<String>(
                                  value: 'beginner',
                                  child: Text('Cơ bản'),
                                ),
                                DropdownMenuItem<String>(
                                  value: 'intermediate',
                                  child: Text('Trung cấp'),
                                ),
                                DropdownMenuItem<String>(
                                  value: 'advanced',
                                  child: Text('Nâng cao'),
                                ),
                              ],
                              onChanged: isSaving
                                  ? null
                                  : (String? value) {
                                      if (value == null) {
                                        return;
                                      }
                                      setDialogState(() {
                                        level = value;
                                      });
                                    },
                            ),
                          ],
                        ),
                      ),
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
                      onPressed: isSaving ? null : saveLesson,
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
                          : Icon(
                              isEditing
                                  ? Icons.save_rounded
                                  : Icons.add_rounded,
                            ),
                      label: Text(
                        isSaving
                            ? 'Đang lưu...'
                            : isEditing
                            ? 'Lưu thay đổi'
                            : 'Thêm bài luyện',
                      ),
                    ),
                  ],
                );
              },
        );
      },
    );

    titleController.dispose();
    descriptionController.dispose();

    if (wasSaved != true || !mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isEditing
              ? 'Đã cập nhật bài luyện Shadowing.'
              : 'Đã thêm bài luyện Shadowing mới.',
        ),
        backgroundColor: Colors.green,
      ),
    );

    await _loadLessons();
  }

  Future<void> _deleteLesson(ShadowingLesson lesson) async {
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Xóa bài luyện Shadowing?'),
          content: Text(
            'Bạn có chắc muốn xóa "${lesson.title}" không? '
            'Toàn bộ câu trong bài này sẽ bị xóa theo.',
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
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Xóa'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true || !mounted) {
      return;
    }

    setState(() {
      _processingLessonId = lesson.id;
    });

    try {
      await _adminService.requireAdmin();

      await _lessonService.deleteLesson(lesson.id);

      if (!mounted) {
        return;
      }

      setState(() {
        _processingLessonId = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã xóa bài luyện Shadowing.'),
          backgroundColor: Colors.green,
        ),
      );

      await _loadLessons();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _processingLessonId = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể xóa bài luyện Shadowing: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _openSegmentManagement(ShadowingLesson lesson) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return _AdminShadowingSegmentsScreen(lesson: lesson);
        },
      ),
    );
  }

  Widget _buildLessonCard(ShadowingLesson lesson) {
    final bool isProcessing = _processingLessonId == lesson.id;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          _openSegmentManagement(lesson);
        },
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _accentColor.withValues(alpha: 0.11),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.record_voice_over_rounded,
                      color: _accentColor,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lesson.title,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          lesson.levelLabel,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              if (lesson.description.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    lesson.description,
                    style: const TextStyle(fontSize: 13, height: 1.4),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              const Divider(height: 1),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (isProcessing)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 21,
                        height: 21,
                        child: CircularProgressIndicator(
                          color: _accentColor,
                          strokeWidth: 2,
                        ),
                      ),
                    )
                  else ...[
                    IconButton(
                      tooltip: 'Chỉnh sửa',
                      onPressed: () {
                        _showLessonForm(lesson: lesson);
                      },
                      icon: const Icon(
                        Icons.edit_outlined,
                        color: Color(0xFF3B5BDB),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Xóa',
                      onPressed: () {
                        _deleteLesson(lesson);
                      },
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
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
            const Text(
              'Chưa có bài luyện Shadowing',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () {
                _showLessonForm();
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Thêm bài luyện Shadowing'),
              style: FilledButton.styleFrom(
                backgroundColor: _accentColor,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _isCreatingSampleData ? null : _createSampleLesson,
              icon: _isCreatingSampleData
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: _accentColor,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.auto_awesome_rounded),
              label: Text(
                _isCreatingSampleData
                    ? 'Đang tạo dữ liệu...'
                    : 'Tạo dữ liệu mẫu',
              ),
              style: OutlinedButton.styleFrom(foregroundColor: _accentColor),
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
          'Quản lý luyện Shadowing',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: _accentColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            onPressed: _isLoading ? null : _loadLessons,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showLessonForm();
        },
        backgroundColor: _accentColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Thêm bài luyện'),
      ),
      body: SafeArea(
        child: Builder(
          builder: (BuildContext context) {
            if (_isLoading) {
              return const Center(
                child: CircularProgressIndicator(color: _accentColor),
              );
            }

            if (_errorMessage != null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Text(
                    'Không thể tải danh sách: $_errorMessage',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            if (_lessons.isEmpty) {
              return _buildEmptyView();
            }

            return RefreshIndicator(
              color: _accentColor,
              onRefresh: _loadLessons,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 900),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: _lessons.map(_buildLessonCard).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Trang quản trị danh sách câu (segment) thuộc một bài luyện
/// Shadowing cụ thể.
class _AdminShadowingSegmentsScreen extends StatefulWidget {
  final ShadowingLesson lesson;

  const _AdminShadowingSegmentsScreen({required this.lesson});

  @override
  State<_AdminShadowingSegmentsScreen> createState() =>
      _AdminShadowingSegmentsScreenState();
}

class _AdminShadowingSegmentsScreenState
    extends State<_AdminShadowingSegmentsScreen> {
  static const Color _accentColor = Color(0xFF7048E8);

  final AdminService _adminService = AdminService();

  final ShadowingLessonService _lessonService = ShadowingLessonService();

  List<ShadowingSegment> _segments = <ShadowingSegment>[];

  String? _processingSegmentId;
  String? _errorMessage;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSegments();
  }

  Future<void> _loadSegments() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final List<ShadowingSegment> segments = await _lessonService
          .getSegmentsByLessonOnce(widget.lesson.id);

      if (!mounted) {
        return;
      }

      setState(() {
        _segments = segments;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = error.toString();
      });
    }
  }

  Future<void> _showSegmentForm({ShadowingSegment? segment}) async {
    final bool isEditing = segment != null;

    final TextEditingController textController = TextEditingController(
      text: segment?.text ?? '',
    );

    final TextEditingController ipaController = TextEditingController(
      text: segment?.ipaPronunciation ?? '',
    );

    final TextEditingController translationController = TextEditingController(
      text: segment?.vietnameseTranslation ?? '',
    );

    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

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
                Future<void> saveSegment() async {
                  if (!formKey.currentState!.validate() || isSaving) {
                    return;
                  }

                  setDialogState(() {
                    isSaving = true;
                  });

                  final int order = segment?.order ?? _segments.length + 1;

                  final ShadowingSegment segmentToSave = ShadowingSegment(
                    id: segment?.id ?? '',
                    lessonId: widget.lesson.id,
                    order: order,
                    text: textController.text.trim(),
                    ipaPronunciation: ipaController.text.trim(),
                    vietnameseTranslation: translationController.text.trim(),
                  );

                  try {
                    await _adminService.requireAdmin();

                    if (isEditing) {
                      await _lessonService.updateSegment(segmentToSave);
                    } else {
                      await _lessonService.addSegment(segmentToSave);
                    }

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
                        content: Text('Không thể lưu câu: $error'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }

                return AlertDialog(
                  title: Text(isEditing ? 'Chỉnh sửa câu' : 'Thêm câu mới'),
                  content: SizedBox(
                    width: 520,
                    child: SingleChildScrollView(
                      child: Form(
                        key: formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextFormField(
                              controller: textController,
                              enabled: !isSaving,
                              minLines: 2,
                              maxLines: 4,
                              decoration: const InputDecoration(
                                labelText: 'Câu tiếng Anh',
                                hintText:
                                    'Ví dụ: Could you send me that '
                                    'report by noon?',
                                alignLabelWithHint: true,
                                prefixIcon: Icon(Icons.format_quote_rounded),
                              ),
                              validator: (String? value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Vui lòng nhập câu tiếng Anh';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 15),
                            TextFormField(
                              controller: ipaController,
                              enabled: !isSaving,
                              decoration: const InputDecoration(
                                labelText: 'Phiên âm IPA (không bắt buộc)',
                                hintText: r'Ví dụ: /kʊd juː sɛnd miː/',
                                prefixIcon: Icon(
                                  Icons.record_voice_over_outlined,
                                ),
                              ),
                            ),
                            const SizedBox(height: 15),
                            TextFormField(
                              controller: translationController,
                              enabled: !isSaving,
                              minLines: 1,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                labelText:
                                    'Bản dịch tiếng Việt (không bắt '
                                    'buộc)',
                                hintText:
                                    'Ví dụ: Bạn có thể gửi báo cáo đó '
                                    'cho tôi trước buổi trưa không?',
                                alignLabelWithHint: true,
                                prefixIcon: Icon(Icons.translate_rounded),
                              ),
                            ),
                          ],
                        ),
                      ),
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
                      onPressed: isSaving ? null : saveSegment,
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
                          : Icon(
                              isEditing
                                  ? Icons.save_rounded
                                  : Icons.add_rounded,
                            ),
                      label: Text(
                        isSaving
                            ? 'Đang lưu...'
                            : isEditing
                            ? 'Lưu thay đổi'
                            : 'Thêm câu',
                      ),
                    ),
                  ],
                );
              },
        );
      },
    );

    textController.dispose();
    ipaController.dispose();
    translationController.dispose();

    if (wasSaved != true || !mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isEditing ? 'Đã cập nhật câu.' : 'Đã thêm câu mới.'),
        backgroundColor: Colors.green,
      ),
    );

    await _loadSegments();
  }

  Future<void> _deleteSegment(ShadowingSegment segment) async {
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Xóa câu này?'),
          content: Text('Bạn có chắc muốn xóa câu "${segment.text}" không?'),
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
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Xóa'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true || !mounted) {
      return;
    }

    setState(() {
      _processingSegmentId = segment.id;
    });

    try {
      await _adminService.requireAdmin();

      await _lessonService.deleteSegment(segment.id);

      if (!mounted) {
        return;
      }

      setState(() {
        _processingSegmentId = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã xóa câu.'),
          backgroundColor: Colors.green,
        ),
      );

      await _loadSegments();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _processingSegmentId = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể xóa câu: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildSegmentCard(ShadowingSegment segment) {
    final bool isProcessing = _processingSegmentId == segment.id;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _accentColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Text(
                '${segment.order}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _accentColor,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    segment.text,
                    style: TextStyle(
                      fontSize: 14.5,
                      height: 1.4,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  if (segment.ipaPronunciation.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      segment.ipaPronunciation,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontStyle: FontStyle.italic,
                        color: _accentColor,
                      ),
                    ),
                  ],
                  if (segment.vietnameseTranslation.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      segment.vietnameseTranslation,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (isProcessing)
              const Padding(
                padding: EdgeInsets.all(8),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    color: _accentColor,
                    strokeWidth: 2,
                  ),
                ),
              )
            else ...[
              IconButton(
                tooltip: 'Chỉnh sửa',
                onPressed: () {
                  _showSegmentForm(segment: segment);
                },
                icon: const Icon(
                  Icons.edit_outlined,
                  color: Color(0xFF3B5BDB),
                  size: 20,
                ),
              ),
              IconButton(
                tooltip: 'Xóa',
                onPressed: () {
                  _deleteSegment(segment);
                },
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.red,
                  size: 20,
                ),
              ),
            ],
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
              Icons.format_quote_rounded,
              color: _accentColor,
              size: 62,
            ),
            const SizedBox(height: 16),
            const Text(
              'Bài này chưa có câu nào',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Nhấn nút bên dưới để thêm câu tiếng Anh đầu tiên.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () {
                _showSegmentForm();
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Thêm câu'),
              style: FilledButton.styleFrom(
                backgroundColor: _accentColor,
                foregroundColor: Colors.white,
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
        title: Text(
          widget.lesson.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: _accentColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            onPressed: _isLoading ? null : _loadSegments,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showSegmentForm();
        },
        backgroundColor: _accentColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Thêm câu'),
      ),
      body: SafeArea(
        child: Builder(
          builder: (BuildContext context) {
            if (_isLoading) {
              return const Center(
                child: CircularProgressIndicator(color: _accentColor),
              );
            }

            if (_errorMessage != null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Text(
                    'Không thể tải danh sách câu: $_errorMessage',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            if (_segments.isEmpty) {
              return _buildEmptyView();
            }

            return RefreshIndicator(
              color: _accentColor,
              onRefresh: _loadSegments,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 900),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: _segments.map(_buildSegmentCard).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
