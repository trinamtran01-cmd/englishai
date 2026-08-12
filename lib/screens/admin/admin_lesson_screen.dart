import 'package:flutter/material.dart';

import '../../models/lesson.dart';
import '../../services/admin_service.dart';
import '../../services/lesson_service.dart';

class AdminLessonScreen extends StatefulWidget {
  const AdminLessonScreen({super.key});

  @override
  State<AdminLessonScreen> createState() =>
      _AdminLessonScreenState();
}

class _AdminLessonScreenState
    extends State<AdminLessonScreen> {
  final LessonService _lessonService = LessonService();
  final AdminService _adminService = AdminService();

  late Future<List<Lesson>> _lessonsFuture;

  String? _processingLessonId;
  bool _isAddingLesson = false;

  @override
  void initState() {
    super.initState();
    _lessonsFuture = _loadLessons();
  }

  Future<List<Lesson>> _loadLessons() async {
    final bool isAdmin =
        await _adminService.isCurrentUserAdmin();

    if (!isAdmin) {
      throw StateError(
        'Tài khoản hiện tại không có quyền quản trị.',
      );
    }

    return _lessonService.getAllLessons();
  }

  Future<void> _refreshLessons() async {
    setState(() {
      _lessonsFuture = _loadLessons();
    });

    try {
      await _lessonsFuture;
    } catch (_) {
      // FutureBuilder sẽ hiển thị lỗi.
    }
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

      case 'travel':
        return Icons.flight_takeoff_rounded;

      case 'work':
        return Icons.work_outline_rounded;

      case 'shopping':
        return Icons.shopping_cart_outlined;

      case 'health':
        return Icons.health_and_safety_outlined;

      case 'menu_book':
      default:
        return Icons.menu_book_rounded;
    }
  }

  Color _getLessonColor(int colorValue) {
    return Color(colorValue);
  }

  Future<void> _showLessonForm({
    Lesson? lesson,
  }) async {
    final bool isEditing = lesson != null;

    final TextEditingController titleController =
        TextEditingController(
      text: lesson?.title ?? '',
    );

    final TextEditingController topicController =
        TextEditingController(
      text: lesson?.topic ?? '',
    );

    final TextEditingController descriptionController =
        TextEditingController(
      text: lesson?.description ?? '',
    );

    final TextEditingController orderController =
        TextEditingController(
      text: lesson?.order.toString() ?? '',
    );

    String selectedIcon =
        lesson?.icon ?? 'menu_book';

    int selectedColor =
        lesson?.color ?? 0xFF3B5BDB;

    bool isActive = lesson?.isActive ?? true;
    bool isSaving = false;

    final GlobalKey<FormState> formKey =
        GlobalKey<FormState>();

    final Lesson? savedLesson =
        await showDialog<Lesson>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (
            BuildContext context,
            void Function(void Function()) setDialogState,
          ) {
            Future<void> saveLesson() async {
              if (!formKey.currentState!.validate() ||
                  isSaving) {
                return;
              }

              setDialogState(() {
                isSaving = true;
              });

              final int order =
                  int.tryParse(orderController.text.trim()) ??
                      0;

              final Lesson lessonToSave = Lesson(
                id: lesson?.id ?? '',
                title: titleController.text.trim(),
                topic: topicController.text.trim(),
                description:
                    descriptionController.text.trim(),
                icon: selectedIcon,
                color: selectedColor,
                order: order,
                isActive: isActive,
                createdAt: lesson?.createdAt,
                updatedAt: lesson?.updatedAt,
              );

              try {
                await _adminService.requireAdmin();

                if (isEditing) {
                  await _lessonService.updateLesson(
                    lessonToSave,
                  );
                } else {
                  await _lessonService.addLesson(
                    lessonToSave,
                  );
                }

                if (!dialogContext.mounted) {
                  return;
                }

                Navigator.of(dialogContext).pop(
                  lessonToSave,
                );
              } catch (error) {
                if (!dialogContext.mounted) {
                  return;
                }

                setDialogState(() {
                  isSaving = false;
                });

                ScaffoldMessenger.of(dialogContext)
                    .showSnackBar(
                  SnackBar(
                    content: Text(
                      'Không thể lưu bài học: $error',
                    ),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }

            return AlertDialog(
              title: Text(
                isEditing
                    ? 'Chỉnh sửa bài học'
                    : 'Thêm bài học mới',
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
                          textInputAction:
                              TextInputAction.next,
                          decoration:
                              const InputDecoration(
                            labelText: 'Tên bài học',
                            prefixIcon: Icon(
                              Icons.title_rounded,
                            ),
                          ),
                          validator: (String? value) {
                            if (value == null ||
                                value.trim().isEmpty) {
                              return 'Vui lòng nhập tên bài học';
                            }

                            if (value.trim().length < 2) {
                              return 'Tên bài học quá ngắn';
                            }

                            return null;
                          },
                        ),
                        const SizedBox(height: 15),

                        TextFormField(
                          controller: topicController,
                          enabled: !isSaving,
                          textInputAction:
                              TextInputAction.next,
                          decoration:
                              const InputDecoration(
                            labelText: 'Chủ đề',
                            prefixIcon: Icon(
                              Icons.category_outlined,
                            ),
                          ),
                          validator: (String? value) {
                            if (value == null ||
                                value.trim().isEmpty) {
                              return 'Vui lòng nhập chủ đề';
                            }

                            return null;
                          },
                        ),
                        const SizedBox(height: 15),

                        TextFormField(
                          controller:
                              descriptionController,
                          enabled: !isSaving,
                          minLines: 3,
                          maxLines: 5,
                          decoration:
                              const InputDecoration(
                            labelText: 'Mô tả bài học',
                            alignLabelWithHint: true,
                            prefixIcon: Padding(
                              padding:
                                  EdgeInsets.only(
                                bottom: 50,
                              ),
                              child: Icon(
                                Icons.description_outlined,
                              ),
                            ),
                          ),
                          validator: (String? value) {
                            if (value == null ||
                                value.trim().isEmpty) {
                              return 'Vui lòng nhập mô tả';
                            }

                            return null;
                          },
                        ),
                        const SizedBox(height: 15),

                        TextFormField(
                          controller: orderController,
                          enabled: !isSaving,
                          keyboardType:
                              TextInputType.number,
                          textInputAction:
                              TextInputAction.done,
                          decoration:
                              const InputDecoration(
                            labelText: 'Thứ tự hiển thị',
                            prefixIcon: Icon(
                              Icons.format_list_numbered,
                            ),
                          ),
                          validator: (String? value) {
                            if (value == null ||
                                value.trim().isEmpty) {
                              return 'Vui lòng nhập thứ tự';
                            }

                            final int? order =
                                int.tryParse(
                              value.trim(),
                            );

                            if (order == null ||
                                order < 0) {
                              return 'Thứ tự phải là số từ 0 trở lên';
                            }

                            return null;
                          },
                        ),
                        const SizedBox(height: 15),

                        DropdownButtonFormField<String>(
                          initialValue: selectedIcon,
                          decoration:
                              const InputDecoration(
                            labelText: 'Biểu tượng',
                            prefixIcon: Icon(
                              Icons.emoji_symbols_rounded,
                            ),
                          ),
                          items: const [
                            DropdownMenuItem<String>(
                              value: 'menu_book',
                              child: Text('Sách'),
                            ),
                            DropdownMenuItem<String>(
                              value: 'waving_hand',
                              child: Text('Chào hỏi'),
                            ),
                            DropdownMenuItem<String>(
                              value: 'family',
                              child: Text('Gia đình'),
                            ),
                            DropdownMenuItem<String>(
                              value: 'school',
                              child: Text('Trường học'),
                            ),
                            DropdownMenuItem<String>(
                              value: 'restaurant',
                              child: Text(
                                'Đồ ăn và thức uống',
                              ),
                            ),
                            DropdownMenuItem<String>(
                              value: 'schedule',
                              child: Text(
                                'Hoạt động hằng ngày',
                              ),
                            ),
                            DropdownMenuItem<String>(
                              value: 'travel',
                              child: Text('Du lịch'),
                            ),
                            DropdownMenuItem<String>(
                              value: 'work',
                              child: Text('Công việc'),
                            ),
                            DropdownMenuItem<String>(
                              value: 'shopping',
                              child: Text('Mua sắm'),
                            ),
                            DropdownMenuItem<String>(
                              value: 'health',
                              child: Text('Sức khỏe'),
                            ),
                          ],
                          onChanged: isSaving
                              ? null
                              : (String? value) {
                                  if (value == null) {
                                    return;
                                  }

                                  setDialogState(() {
                                    selectedIcon = value;
                                  });
                                },
                        ),
                        const SizedBox(height: 15),

                        DropdownButtonFormField<int>(
                          initialValue: selectedColor,
                          decoration:
                              const InputDecoration(
                            labelText: 'Màu sắc',
                            prefixIcon: Icon(
                              Icons.palette_outlined,
                            ),
                          ),
                          items: const [
                            DropdownMenuItem<int>(
                              value: 0xFF3B5BDB,
                              child: _ColorOption(
                                color:
                                    Color(0xFF3B5BDB),
                                label: 'Xanh dương',
                              ),
                            ),
                            DropdownMenuItem<int>(
                              value: 0xFF2F9E44,
                              child: _ColorOption(
                                color:
                                    Color(0xFF2F9E44),
                                label: 'Xanh lá',
                              ),
                            ),
                            DropdownMenuItem<int>(
                              value: 0xFFF59F00,
                              child: _ColorOption(
                                color:
                                    Color(0xFFF59F00),
                                label: 'Cam',
                              ),
                            ),
                            DropdownMenuItem<int>(
                              value: 0xFFE64980,
                              child: _ColorOption(
                                color:
                                    Color(0xFFE64980),
                                label: 'Hồng',
                              ),
                            ),
                            DropdownMenuItem<int>(
                              value: 0xFF9C36B5,
                              child: _ColorOption(
                                color:
                                    Color(0xFF9C36B5),
                                label: 'Tím',
                              ),
                            ),
                            DropdownMenuItem<int>(
                              value: 0xFF0C8599,
                              child: _ColorOption(
                                color:
                                    Color(0xFF0C8599),
                                label: 'Xanh ngọc',
                              ),
                            ),
                            DropdownMenuItem<int>(
                              value: 0xFFE03131,
                              child: _ColorOption(
                                color:
                                    Color(0xFFE03131),
                                label: 'Đỏ',
                              ),
                            ),
                          ],
                          onChanged: isSaving
                              ? null
                              : (int? value) {
                                  if (value == null) {
                                    return;
                                  }

                                  setDialogState(() {
                                    selectedColor = value;
                                  });
                                },
                        ),
                        const SizedBox(height: 10),

                        SwitchListTile(
                          contentPadding:
                              EdgeInsets.zero,
                          title: const Text(
                            'Bài học đang hoạt động',
                          ),
                          subtitle: Text(
                            isActive
                                ? 'Học viên có thể nhìn thấy bài học'
                                : 'Bài học đang bị ẩn khỏi học viên',
                          ),
                          value: isActive,
                          activeThumbColor:
                              const Color(0xFF3B5BDB),
                          onChanged: isSaving
                              ? null
                              : (bool value) {
                                  setDialogState(() {
                                    isActive = value;
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
                          Navigator.of(dialogContext)
                              .pop();
                        },
                  child: const Text('Hủy'),
                ),
                FilledButton.icon(
                  onPressed:
                      isSaving ? null : saveLesson,
                  icon: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child:
                              CircularProgressIndicator(
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
                            : 'Thêm bài học',
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    titleController.dispose();
    topicController.dispose();
    descriptionController.dispose();
    orderController.dispose();

    if (savedLesson == null || !mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isEditing
              ? 'Đã cập nhật bài học thành công.'
              : 'Đã thêm bài học thành công.',
        ),
        backgroundColor: Colors.green,
      ),
    );

    await _refreshLessons();
  }

  Future<void> _addLesson() async {
    if (_isAddingLesson) {
      return;
    }

    setState(() {
      _isAddingLesson = true;
    });

    await _showLessonForm();

    if (!mounted) {
      return;
    }

    setState(() {
      _isAddingLesson = false;
    });
  }

  Future<void> _updateLessonStatus(
    Lesson lesson,
    bool newStatus,
  ) async {
    if (_processingLessonId != null) {
      return;
    }

    setState(() {
      _processingLessonId = lesson.id;
    });

    try {
      await _adminService.updateLessonStatus(
        lessonId: lesson.id,
        isActive: newStatus,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _processingLessonId = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newStatus
                ? 'Đã bật bài học "${lesson.title}".'
                : 'Đã ẩn bài học "${lesson.title}".',
          ),
          backgroundColor: Colors.green,
        ),
      );

      await _refreshLessons();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _processingLessonId = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Không thể cập nhật trạng thái: $error',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _confirmDeleteLesson(
    Lesson lesson,
  ) async {
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          icon: const Icon(
            Icons.warning_amber_rounded,
            color: Colors.red,
            size: 50,
          ),
          title: const Text(
            'Xóa bài học?',
            textAlign: TextAlign.center,
          ),
          content: Text(
            'Bạn có chắc chắn muốn xóa bài học '
            '"${lesson.title}" không?\n\n'
            'Thao tác này không thể hoàn tác. '
            'Từ vựng và câu hỏi liên quan nên được '
            'xử lý riêng.',
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Hủy'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              icon: const Icon(
                Icons.delete_outline_rounded,
              ),
              label: const Text('Xóa bài học'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
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
        SnackBar(
          content: Text(
            'Đã xóa bài học "${lesson.title}".',
          ),
          backgroundColor: Colors.green,
        ),
      );

      await _refreshLessons();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _processingLessonId = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Không thể xóa bài học: $error',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildLessonCard(Lesson lesson) {
    final Color lessonColor =
        _getLessonColor(lesson.color);

    final bool isProcessing =
        _processingLessonId == lesson.id;

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
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          children: [
            Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: lessonColor.withValues(
                      alpha: 0.12,
                    ),
                    borderRadius:
                        BorderRadius.circular(15),
                  ),
                  child: Icon(
                    _getLessonIcon(lesson.icon),
                    color: lessonColor,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              lesson.title,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight:
                                    FontWeight.bold,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface,
                              ),
                            ),
                          ),
                          Container(
                            padding:
                                const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: lesson.isActive
                                  ? const Color(
                                      0xFF2F9E44,
                                    ).withValues(
                                      alpha: 0.11,
                                    )
                                  : Colors.grey.withValues(
                                      alpha: 0.12,
                                    ),
                              borderRadius:
                                  BorderRadius.circular(
                                20,
                              ),
                            ),
                            child: Text(
                              lesson.isActive
                                  ? 'Hoạt động'
                                  : 'Đang ẩn',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight:
                                    FontWeight.bold,
                                color: lesson.isActive
                                    ? const Color(
                                        0xFF2F9E44,
                                      )
                                    : Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        lesson.topic,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: lessonColor,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        lesson.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            const Divider(height: 1),
            const SizedBox(height: 13),
            Row(
              children: [
                Icon(
                  Icons.format_list_numbered_rounded,
                  size: 18,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  'Thứ tự: ${lesson.order}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                if (isProcessing)
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: lessonColor,
                      strokeWidth: 2,
                    ),
                  )
                else ...[
                  IconButton(
                    tooltip: lesson.isActive
                        ? 'Ẩn bài học'
                        : 'Bật bài học',
                    onPressed: () {
                      _updateLessonStatus(
                        lesson,
                        !lesson.isActive,
                      );
                    },
                    icon: Icon(
                      lesson.isActive
                          ? Icons.visibility_rounded
                          : Icons
                              .visibility_off_rounded,
                      color: lesson.isActive
                          ? const Color(0xFF2F9E44)
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Chỉnh sửa',
                    onPressed: () {
                      _showLessonForm(
                        lesson: lesson,
                      );
                    },
                    icon: const Icon(
                      Icons.edit_outlined,
                      color: Color(0xFF3B5BDB),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Xóa bài học',
                    onPressed: () {
                      _confirmDeleteLesson(lesson);
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
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              color: Color(0xFF3B5BDB),
            ),
            const SizedBox(height: 18),
            Text(
              'Đang tải danh sách bài học...',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView(Object error) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 66,
              color: Colors.red,
            ),
            const SizedBox(height: 18),
            Text(
              'Không thể tải bài học',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: _refreshLessons,
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
            const Icon(
              Icons.menu_book_outlined,
              size: 70,
              color: Color(0xFF3B5BDB),
            ),
            const SizedBox(height: 18),
            Text(
              'Chưa có bài học',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Nhấn nút bên dưới để tạo bài học đầu tiên.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: _addLesson,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Thêm bài học'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLessonList(List<Lesson> lessons) {
    final int activeLessons = lessons
        .where(
          (Lesson lesson) => lesson.isActive,
        )
        .length;

    return RefreshIndicator(
      color: const Color(0xFF3B5BDB),
      onRefresh: _refreshLessons,
      child: ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          20,
          20,
          20,
          100,
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(
              color: const Color(0xFF3B5BDB)
                  .withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(17),
              border: Border.all(
                color: const Color(0xFF3B5BDB)
                    .withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.analytics_outlined,
                  color: Color(0xFF3B5BDB),
                  size: 32,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    '${lessons.length} bài học • '
                    '$activeLessons đang hoạt động • '
                    '${lessons.length - activeLessons} đang ẩn',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ...lessons.map(_buildLessonCard),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Quản lý bài học',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF3B5BDB),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            onPressed: _refreshLessons,
            icon: const Icon(
              Icons.refresh_rounded,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isAddingLesson
            ? null
            : _addLesson,
        backgroundColor: const Color(0xFF3B5BDB),
        foregroundColor: Colors.white,
        icon: _isAddingLesson
            ? const SizedBox(
                width: 19,
                height: 19,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.add_rounded),
        label: Text(
          _isAddingLesson
              ? 'Đang xử lý...'
              : 'Thêm bài học',
        ),
      ),
      body: SafeArea(
        child: FutureBuilder<List<Lesson>>(
          future: _lessonsFuture,
          builder: (
            BuildContext context,
            AsyncSnapshot<List<Lesson>> snapshot,
          ) {
            if (snapshot.connectionState ==
                ConnectionState.waiting) {
              return _buildLoadingView();
            }

            if (snapshot.hasError) {
              return _buildErrorView(
                snapshot.error!,
              );
            }

            final List<Lesson> lessons =
                snapshot.data ?? <Lesson>[];

            if (lessons.isEmpty) {
              return _buildEmptyView();
            }

            return _buildLessonList(lessons);
          },
        ),
      ),
    );
  }
}

class _ColorOption extends StatelessWidget {
  final Color color;
  final String label;

  const _ColorOption({
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 19,
          height: 19,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Text(label),
      ],
    );
  }
}