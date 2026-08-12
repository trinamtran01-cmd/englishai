import 'package:flutter/material.dart';

import '../../models/writing_task.dart';
import '../../services/admin_service.dart';
import '../../services/writing_task_service.dart';
import '../../utils/seed_writing_data.dart';

/// Trang quản trị nội dung Luyện Viết AI.
///
/// Cho phép admin thêm, sửa, xóa các đề bài Writing Task 1/Task 2.
class AdminWritingScreen extends StatefulWidget {
  const AdminWritingScreen({super.key});

  @override
  State<AdminWritingScreen> createState() =>
      _AdminWritingScreenState();
}

class _AdminWritingScreenState extends State<AdminWritingScreen> {
  static const Color _accentColor = Color(0xFFE8590C);

  final AdminService _adminService = AdminService();

  final WritingTaskService _taskService = WritingTaskService();

  List<WritingTask> _tasks = <WritingTask>[];

  String? _processingTaskId;
  String? _errorMessage;

  bool _isLoading = true;
  bool _isCreatingSampleData = false;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  /// Tải lại danh sách một lần (không dùng stream sống), để tránh
  /// màn hình phía sau tự rebuild trong lúc dialog thêm/sửa đang
  /// đóng lại - nguyên nhân gây crash "_dependents.isEmpty" khi
  /// Navigator.pop() và một rebuild từ stream xảy ra gần như đồng
  /// thời.
  Future<void> _loadTasks() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final List<WritingTask> tasks =
          await _taskService.getAllTasksOnce();

      if (!mounted) {
        return;
      }

      setState(() {
        _tasks = tasks;
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

  Future<void> _createSampleTask() async {
    if (_isCreatingSampleData) {
      return;
    }

    setState(() {
      _isCreatingSampleData = true;
    });

    try {
      await _adminService.requireAdmin();

      await seedSampleWritingTask();

      if (!mounted) {
        return;
      }

      setState(() {
        _isCreatingSampleData = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Đã kiểm tra và tạo dữ liệu đề Luyện Viết mẫu.',
          ),
          backgroundColor: Colors.green,
        ),
      );

      await _loadTasks();
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

  Future<void> _showTaskForm({WritingTask? task}) async {
    final bool isEditing = task != null;

    final TextEditingController titleController =
        TextEditingController(text: task?.title ?? '');

    final TextEditingController promptController =
        TextEditingController(text: task?.promptText ?? '');

    final TextEditingController imageUrlController =
        TextEditingController(text: task?.imageUrl ?? '');

    final TextEditingController chartTypeController =
        TextEditingController(text: task?.chartType ?? '');

    final TextEditingController sourceController =
        TextEditingController(text: task?.source ?? '');

    final TextEditingController minWordsController =
        TextEditingController(
      text: (task?.minWords ?? 150).toString(),
    );

    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    String taskType = task?.taskType ?? 'task1';
    bool isSaving = false;

    final bool? wasSaved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (
            BuildContext context,
            void Function(void Function()) setDialogState,
          ) {
            Future<void> saveTask() async {
              if (!formKey.currentState!.validate() || isSaving) {
                return;
              }

              setDialogState(() {
                isSaving = true;
              });

              final int parsedMinWords =
                  int.tryParse(minWordsController.text.trim()) ??
                      (taskType == 'task2' ? 250 : 150);

              final WritingTask taskToSave = WritingTask(
                id: task?.id ?? '',
                title: titleController.text.trim(),
                taskType: taskType,
                promptText: promptController.text.trim(),
                imageUrl: imageUrlController.text.trim(),
                chartType: chartTypeController.text.trim(),
                minWords: parsedMinWords,
                source: sourceController.text.trim(),
                createdAt: task?.createdAt,
              );

              try {
                await _adminService.requireAdmin();

                if (isEditing) {
                  await _taskService.updateTask(taskToSave);
                } else {
                  await _taskService.addTask(taskToSave);
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
                    content: Text('Không thể lưu đề bài: $error'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }

            return AlertDialog(
              title: Text(
                isEditing ? 'Chỉnh sửa đề bài' : 'Thêm đề bài mới',
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
                            if (value == null ||
                                value.trim().isEmpty) {
                              return 'Vui lòng nhập tiêu đề';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 15),
                        DropdownButtonFormField<String>(
                          initialValue: taskType,
                          decoration: const InputDecoration(
                            labelText: 'Loại đề',
                            prefixIcon: Icon(Icons.category_rounded),
                          ),
                          items: const [
                            DropdownMenuItem<String>(
                              value: 'task1',
                              child: Text('Writing Task 1'),
                            ),
                            DropdownMenuItem<String>(
                              value: 'task2',
                              child: Text('Writing Task 2'),
                            ),
                          ],
                          onChanged: isSaving
                              ? null
                              : (String? value) {
                                  if (value == null) {
                                    return;
                                  }

                                  setDialogState(() {
                                    taskType = value;

                                    final int? currentMinWords =
                                        int.tryParse(
                                      minWordsController.text.trim(),
                                    );

                                    final bool isDefaultValue =
                                        currentMinWords == 150 ||
                                            currentMinWords == 250;

                                    if (isDefaultValue) {
                                      minWordsController.text =
                                          value == 'task2'
                                              ? '250'
                                              : '150';
                                    }
                                  });
                                },
                        ),
                        const SizedBox(height: 15),
                        TextFormField(
                          controller: promptController,
                          enabled: !isSaving,
                          minLines: 3,
                          maxLines: 6,
                          decoration: const InputDecoration(
                            labelText: 'Đề bài (promptText)',
                            alignLabelWithHint: true,
                            prefixIcon: Icon(Icons.description_rounded),
                          ),
                          validator: (String? value) {
                            if (value == null ||
                                value.trim().isEmpty) {
                              return 'Vui lòng nhập đề bài';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 15),
                        TextFormField(
                          controller: imageUrlController,
                          enabled: !isSaving,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Link ảnh biểu đồ (nếu có)',
                            hintText: 'https://...',
                            prefixIcon: Icon(Icons.image_outlined),
                          ),
                        ),
                        const SizedBox(height: 15),
                        TextFormField(
                          controller: chartTypeController,
                          enabled: !isSaving,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText:
                                'Dạng biểu đồ (line/bar/map/process/pie)',
                            prefixIcon: Icon(Icons.bar_chart_rounded),
                          ),
                        ),
                        const SizedBox(height: 15),
                        TextFormField(
                          controller: minWordsController,
                          enabled: !isSaving,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Số từ tối thiểu',
                            prefixIcon: Icon(Icons.format_list_numbered_rounded),
                          ),
                          validator: (String? value) {
                            final int? parsed =
                                int.tryParse((value ?? '').trim());

                            if (parsed == null || parsed <= 0) {
                              return 'Vui lòng nhập số từ hợp lệ';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 15),
                        TextFormField(
                          controller: sourceController,
                          enabled: !isSaving,
                          decoration: const InputDecoration(
                            labelText: 'Nguồn đề (nếu có)',
                            hintText: 'Ví dụ: Cam 18 - Test 4',
                            prefixIcon: Icon(Icons.source_outlined),
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
                  onPressed: isSaving ? null : saveTask,
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
                            : 'Thêm đề bài',
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    titleController.dispose();
    promptController.dispose();
    imageUrlController.dispose();
    chartTypeController.dispose();
    sourceController.dispose();
    minWordsController.dispose();

    if (wasSaved != true || !mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isEditing ? 'Đã cập nhật đề bài.' : 'Đã thêm đề bài mới.',
        ),
        backgroundColor: Colors.green,
      ),
    );

    await _loadTasks();
  }

  Future<void> _deleteTask(WritingTask task) async {
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Xóa đề bài?'),
          content: Text(
            'Bạn có chắc muốn xóa "${task.title}" không?',
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
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
              ),
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
      _processingTaskId = task.id;
    });

    try {
      await _adminService.requireAdmin();

      await _taskService.deleteTask(task.id);

      if (!mounted) {
        return;
      }

      setState(() {
        _processingTaskId = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã xóa đề bài.'),
          backgroundColor: Colors.green,
        ),
      );

      await _loadTasks();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _processingTaskId = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể xóa đề bài: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildTaskCard(WritingTask task) {
    final bool isProcessing = _processingTaskId == task.id;

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
                    Icons.edit_note_rounded,
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
                        task.title,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${task.taskTypeLabel} • '
                        'Tối thiểu ${task.minWords} từ'
                        '${task.chartType.trim().isEmpty ? '' : ' • ${task.chartType}'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              task.promptText,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
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
                      _showTaskForm(task: task);
                    },
                    icon: const Icon(
                      Icons.edit_outlined,
                      color: Color(0xFF3B5BDB),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Xóa',
                    onPressed: () {
                      _deleteTask(task);
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

  Widget _buildEmptyView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.edit_note_rounded,
              color: _accentColor,
              size: 68,
            ),
            const SizedBox(height: 18),
            const Text(
              'Chưa có đề bài Luyện Viết',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () {
                _showTaskForm();
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Thêm đề bài'),
              style: FilledButton.styleFrom(
                backgroundColor: _accentColor,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed:
                  _isCreatingSampleData ? null : _createSampleTask,
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
              style: OutlinedButton.styleFrom(
                foregroundColor: _accentColor,
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
          'Quản lý Luyện Viết AI',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: _accentColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            onPressed: _isLoading ? null : _loadTasks,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showTaskForm();
        },
        backgroundColor: _accentColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Thêm đề bài'),
      ),
      body: SafeArea(
        child: Builder(
          builder: (BuildContext context) {
            if (_isLoading) {
              return const Center(
                child: CircularProgressIndicator(
                  color: _accentColor,
                ),
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

            if (_tasks.isEmpty) {
              return _buildEmptyView();
            }

            return RefreshIndicator(
              color: _accentColor,
              onRefresh: _loadTasks,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                children: _tasks.map(_buildTaskCard).toList(),
              ),
            );
          },
        ),
      ),
    );
  }
}
