import 'package:flutter/material.dart';

import '../../models/lesson.dart';
import '../../models/vocabulary.dart';
import '../../services/admin_service.dart';
import '../../services/lesson_service.dart';
import '../../services/vocabulary_service.dart';

class AdminVocabularyScreen extends StatefulWidget {
  const AdminVocabularyScreen({super.key});

  @override
  State<AdminVocabularyScreen> createState() =>
      _AdminVocabularyScreenState();
}

class _AdminVocabularyScreenState
    extends State<AdminVocabularyScreen> {
  final AdminService _adminService = AdminService();
  final LessonService _lessonService = LessonService();
  final VocabularyService _vocabularyService =
      VocabularyService();

  List<Lesson> _lessons = <Lesson>[];
  List<Vocabulary> _vocabularies = <Vocabulary>[];

  String? _selectedLessonId;
  String? _processingVocabularyId;
  String? _errorMessage;

  bool _isLoadingLessons = true;
  bool _isLoadingVocabularies = false;
  bool _isAddingVocabulary = false;

  Lesson? get _selectedLesson {
    if (_selectedLessonId == null) {
      return null;
    }

    for (final Lesson lesson in _lessons) {
      if (lesson.id == _selectedLessonId) {
        return lesson;
      }
    }

    return null;
  }

  @override
  void initState() {
    super.initState();
    _loadLessons();
  }

  Future<void> _loadLessons() async {
    setState(() {
      _isLoadingLessons = true;
      _errorMessage = null;
    });

    try {
      final bool isAdmin =
          await _adminService.isCurrentUserAdmin();

      if (!isAdmin) {
        throw StateError(
          'Tài khoản hiện tại không có quyền quản trị.',
        );
      }

      final List<Lesson> lessons =
          await _lessonService.getAllLessons();

      if (!mounted) {
        return;
      }

      String? selectedId = _selectedLessonId;

      if (lessons.isEmpty) {
        selectedId = null;
      } else {
        final bool stillExists = selectedId != null &&
            lessons.any(
              (Lesson lesson) => lesson.id == selectedId,
            );

        if (!stillExists) {
          selectedId = lessons.first.id;
        }
      }

      setState(() {
        _lessons = lessons;
        _selectedLessonId = selectedId;
        _isLoadingLessons = false;
      });

      if (selectedId != null) {
        await _loadVocabularies(selectedId);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingLessons = false;
        _errorMessage = error.toString();
      });
    }
  }

  Future<void> _loadVocabularies(
    String lessonId,
  ) async {
    setState(() {
      _isLoadingVocabularies = true;
      _errorMessage = null;
    });

    try {
      final List<Vocabulary> vocabularies =
          await _vocabularyService
              .getVocabulariesByLesson(lessonId);

      if (!mounted) {
        return;
      }

      setState(() {
        _vocabularies = vocabularies;
        _isLoadingVocabularies = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingVocabularies = false;
        _errorMessage = error.toString();
      });
    }
  }

  Future<void> _selectLesson(
    String? lessonId,
  ) async {
    if (lessonId == null ||
        lessonId == _selectedLessonId) {
      return;
    }

    setState(() {
      _selectedLessonId = lessonId;
      _vocabularies = <Vocabulary>[];
    });

    await _loadVocabularies(lessonId);
  }

  Future<void> _refreshData() async {
    final String? lessonId = _selectedLessonId;

    if (lessonId == null) {
      await _loadLessons();
      return;
    }

    await _loadVocabularies(lessonId);
  }

  Future<void> _createSampleVocabularies() async {
    final Lesson? lesson = _selectedLesson;

    if (lesson == null) {
      return;
    }

    setState(() {
      _isLoadingVocabularies = true;
    });

    try {
      await _adminService.requireAdmin();

      await _vocabularyService.createSampleVocabularies(
        lesson,
      );

      await _loadVocabularies(lesson.id);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Đã kiểm tra và tạo dữ liệu từ vựng mẫu.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingVocabularies = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Không thể tạo dữ liệu mẫu: $error',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showVocabularyForm({
    Vocabulary? vocabulary,
  }) async {
    final Lesson? lesson = _selectedLesson;

    if (lesson == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Vui lòng chọn bài học trước.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final bool isEditing = vocabulary != null;

    final TextEditingController wordController =
        TextEditingController(
      text: vocabulary?.word ?? '',
    );

    final TextEditingController meaningController =
        TextEditingController(
      text: vocabulary?.meaning ?? '',
    );

    final TextEditingController pronunciationController =
        TextEditingController(
      text: vocabulary?.pronunciation ?? '',
    );

    final TextEditingController partOfSpeechController =
        TextEditingController(
      text: vocabulary?.partOfSpeech ?? '',
    );

    final TextEditingController exampleController =
        TextEditingController(
      text: vocabulary?.example ?? '',
    );

    final TextEditingController
        exampleMeaningController =
        TextEditingController(
      text: vocabulary?.exampleMeaning ?? '',
    );

    final TextEditingController orderController =
        TextEditingController(
      text: vocabulary?.order.toString() ??
          (_vocabularies.length + 1).toString(),
    );

    final GlobalKey<FormState> formKey =
        GlobalKey<FormState>();

    bool isActive = vocabulary?.isActive ?? true;
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
            Future<void> saveVocabulary() async {
              if (!formKey.currentState!.validate() ||
                  isSaving) {
                return;
              }

              setDialogState(() {
                isSaving = true;
              });

              final Vocabulary vocabularyToSave =
                  Vocabulary(
                id: vocabulary?.id ?? '',
                lessonId: lesson.id,
                word: wordController.text.trim(),
                meaning: meaningController.text.trim(),
                pronunciation:
                    pronunciationController.text.trim(),
                example: exampleController.text.trim(),
                exampleMeaning:
                    exampleMeaningController.text.trim(),
                partOfSpeech:
                    partOfSpeechController.text.trim(),
                imageUrl: vocabulary?.imageUrl ?? '',
                audioUrl: vocabulary?.audioUrl ?? '',
                order: int.parse(
                  orderController.text.trim(),
                ),
                isActive: isActive,
                createdAt: vocabulary?.createdAt,
                updatedAt: vocabulary?.updatedAt,
              );

              try {
                await _adminService.requireAdmin();

                if (isEditing) {
                  await _vocabularyService
                      .updateVocabulary(
                    vocabularyToSave,
                  );
                } else {
                  await _vocabularyService.addVocabulary(
                    vocabularyToSave,
                  );
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

                ScaffoldMessenger.of(dialogContext)
                    .showSnackBar(
                  SnackBar(
                    content: Text(
                      'Không thể lưu từ vựng: $error',
                    ),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }

            return AlertDialog(
              title: Text(
                isEditing
                    ? 'Chỉnh sửa từ vựng'
                    : 'Thêm từ vựng mới',
              ),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF9C36B5)
                                .withValues(alpha: 0.08),
                            borderRadius:
                                BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Bài học: ${lesson.title}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF9C36B5),
                            ),
                          ),
                        ),
                        const SizedBox(height: 15),
                        TextFormField(
                          controller: wordController,
                          enabled: !isSaving,
                          textInputAction:
                              TextInputAction.next,
                          decoration:
                              const InputDecoration(
                            labelText: 'Từ tiếng Anh',
                            prefixIcon: Icon(
                              Icons.translate_rounded,
                            ),
                          ),
                          validator: (String? value) {
                            if (value == null ||
                                value.trim().isEmpty) {
                              return 'Vui lòng nhập từ tiếng Anh';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 15),
                        TextFormField(
                          controller: meaningController,
                          enabled: !isSaving,
                          textInputAction:
                              TextInputAction.next,
                          decoration:
                              const InputDecoration(
                            labelText: 'Nghĩa tiếng Việt',
                            prefixIcon: Icon(
                              Icons.language_rounded,
                            ),
                          ),
                          validator: (String? value) {
                            if (value == null ||
                                value.trim().isEmpty) {
                              return 'Vui lòng nhập nghĩa tiếng Việt';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 15),
                        TextFormField(
                          controller:
                              pronunciationController,
                          enabled: !isSaving,
                          textInputAction:
                              TextInputAction.next,
                          decoration:
                              const InputDecoration(
                            labelText: 'Phiên âm',
                            hintText: '/həˈləʊ/',
                            prefixIcon: Icon(
                              Icons.record_voice_over_rounded,
                            ),
                          ),
                        ),
                        const SizedBox(height: 15),
                        TextFormField(
                          controller:
                              partOfSpeechController,
                          enabled: !isSaving,
                          textInputAction:
                              TextInputAction.next,
                          decoration:
                              const InputDecoration(
                            labelText: 'Từ loại',
                            hintText:
                                'Danh từ, động từ, tính từ...',
                            prefixIcon: Icon(
                              Icons.category_outlined,
                            ),
                          ),
                        ),
                        const SizedBox(height: 15),
                        TextFormField(
                          controller: exampleController,
                          enabled: !isSaving,
                          minLines: 2,
                          maxLines: 4,
                          decoration:
                              const InputDecoration(
                            labelText:
                                'Câu ví dụ tiếng Anh',
                            alignLabelWithHint: true,
                            prefixIcon: Icon(
                              Icons.format_quote_rounded,
                            ),
                          ),
                        ),
                        const SizedBox(height: 15),
                        TextFormField(
                          controller:
                              exampleMeaningController,
                          enabled: !isSaving,
                          minLines: 2,
                          maxLines: 4,
                          decoration:
                              const InputDecoration(
                            labelText:
                                'Nghĩa câu ví dụ',
                            alignLabelWithHint: true,
                            prefixIcon: Icon(
                              Icons.subtitles_outlined,
                            ),
                          ),
                        ),
                        const SizedBox(height: 15),
                        TextFormField(
                          controller: orderController,
                          enabled: !isSaving,
                          keyboardType:
                              TextInputType.number,
                          decoration:
                              const InputDecoration(
                            labelText: 'Thứ tự hiển thị',
                            prefixIcon: Icon(
                              Icons.format_list_numbered,
                            ),
                          ),
                          validator: (String? value) {
                            final int? order =
                                int.tryParse(
                              value?.trim() ?? '',
                            );

                            if (order == null ||
                                order < 0) {
                              return 'Thứ tự phải là số từ 0 trở lên';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Từ vựng đang hoạt động',
                          ),
                          subtitle: Text(
                            isActive
                                ? 'Học viên có thể nhìn thấy từ này'
                                : 'Từ vựng đang bị ẩn',
                          ),
                          value: isActive,
                          activeThumbColor:
                              const Color(0xFF9C36B5),
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
                              .pop(false);
                        },
                  child: const Text('Hủy'),
                ),
                FilledButton.icon(
                  onPressed:
                      isSaving ? null : saveVocabulary,
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        const Color(0xFF9C36B5),
                    foregroundColor: Colors.white,
                  ),
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
                            : 'Thêm từ vựng',
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    wordController.dispose();
    meaningController.dispose();
    pronunciationController.dispose();
    partOfSpeechController.dispose();
    exampleController.dispose();
    exampleMeaningController.dispose();
    orderController.dispose();

    if (wasSaved != true || !mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isEditing
              ? 'Đã cập nhật từ vựng.'
              : 'Đã thêm từ vựng mới.',
        ),
        backgroundColor: Colors.green,
      ),
    );

    await _loadVocabularies(lesson.id);
  }

  Future<void> _addVocabulary() async {
    if (_isAddingVocabulary ||
        _selectedLesson == null) {
      return;
    }

    setState(() {
      _isAddingVocabulary = true;
    });

    await _showVocabularyForm();

    if (!mounted) {
      return;
    }

    setState(() {
      _isAddingVocabulary = false;
    });
  }

  Future<void> _updateVocabularyStatus(
    Vocabulary vocabulary,
  ) async {
    if (_processingVocabularyId != null) {
      return;
    }

    setState(() {
      _processingVocabularyId = vocabulary.id;
    });

    try {
      await _adminService.updateVocabularyStatus(
        vocabularyId: vocabulary.id,
        isActive: !vocabulary.isActive,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _processingVocabularyId = null;
      });

      await _refreshData();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _processingVocabularyId = null;
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

  Future<void> _deleteVocabulary(
    Vocabulary vocabulary,
  ) async {
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Xóa từ vựng?'),
          content: Text(
            'Bạn có chắc muốn xóa từ '
            '"${vocabulary.word}" không?',
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
      _processingVocabularyId = vocabulary.id;
    });

    try {
      await _adminService.requireAdmin();

      await _vocabularyService.deleteVocabulary(
        vocabulary.id,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _processingVocabularyId = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã xóa từ vựng.'),
          backgroundColor: Colors.green,
        ),
      );

      await _refreshData();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _processingVocabularyId = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Không thể xóa từ vựng: $error',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildVocabularyCard(
    Vocabulary vocabulary,
  ) {
    final bool isProcessing =
        _processingVocabularyId == vocabulary.id;

    final Color statusColor = vocabulary.isActive
        ? const Color(0xFF2F9E44)
        : Colors.grey;

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
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF9C36B5)
                        .withValues(alpha: 0.11),
                    borderRadius:
                        BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.translate_rounded,
                    color: Color(0xFF9C36B5),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        vocabulary.word,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                      if (vocabulary.pronunciation
                          .trim()
                          .isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          vocabulary.pronunciation,
                          style: const TextStyle(
                            fontStyle: FontStyle.italic,
                            color: Color(0xFF9C36B5),
                          ),
                        ),
                      ],
                      const SizedBox(height: 5),
                      Text(
                        vocabulary.meaning,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(
                      alpha: 0.1,
                    ),
                    borderRadius:
                        BorderRadius.circular(20),
                  ),
                  child: Text(
                    vocabulary.isActive
                        ? 'Hoạt động'
                        : 'Đang ẩn',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${vocabulary.displayPartOfSpeech} • '
              'Thứ tự ${vocabulary.order}',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            if (vocabulary.example
                .trim()
                .isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F8FC),
                  borderRadius:
                      BorderRadius.circular(12),
                ),
                child: Text(
                  vocabulary.example,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.4,
                  ),
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
                        color: Color(0xFF9C36B5),
                        strokeWidth: 2,
                      ),
                    ),
                  )
                else ...[
                  IconButton(
                    tooltip: vocabulary.isActive
                        ? 'Ẩn từ vựng'
                        : 'Hiện từ vựng',
                    onPressed: () {
                      _updateVocabularyStatus(
                        vocabulary,
                      );
                    },
                    icon: Icon(
                      vocabulary.isActive
                          ? Icons.visibility_rounded
                          : Icons
                              .visibility_off_rounded,
                      color: statusColor,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Chỉnh sửa',
                    onPressed: () {
                      _showVocabularyForm(
                        vocabulary: vocabulary,
                      );
                    },
                    icon: const Icon(
                      Icons.edit_outlined,
                      color: Color(0xFF3B5BDB),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Xóa',
                    onPressed: () {
                      _deleteVocabulary(vocabulary);
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

  Widget _buildLessonSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: DropdownButtonFormField<String>(
        initialValue: _selectedLessonId,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Chọn bài học',
          prefixIcon: Icon(
            Icons.menu_book_rounded,
          ),
        ),
        items: _lessons.map(
          (Lesson lesson) {
            return DropdownMenuItem<String>(
              value: lesson.id,
              child: Text(
                lesson.title,
                overflow: TextOverflow.ellipsis,
              ),
            );
          },
        ).toList(),
        onChanged: _isLoadingVocabularies
            ? null
            : _selectLesson,
      ),
    );
  }

  Widget _buildLoadingView(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(
            color: Color(0xFF9C36B5),
          ),
          const SizedBox(height: 18),
          Text(
            message,
            style: const TextStyle(
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.red,
              size: 64,
            ),
            const SizedBox(height: 18),
            Text(
              _errorMessage ?? 'Đã xảy ra lỗi.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _loadLessons,
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
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.translate_rounded,
              color: Color(0xFF9C36B5),
              size: 68,
            ),
            const SizedBox(height: 18),
            const Text(
              'Chưa có từ vựng',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _addVocabulary,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Thêm từ vựng'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _createSampleVocabularies,
              icon: const Icon(
                Icons.auto_awesome_rounded,
              ),
              label: const Text('Tạo dữ liệu mẫu'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVocabularyList() {
    return RefreshIndicator(
      color: const Color(0xFF9C36B5),
      onRefresh: _refreshData,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          20,
          20,
          20,
          100,
        ),
        children: _vocabularies
            .map(_buildVocabularyCard)
            .toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FF),
      appBar: AppBar(
        title: const Text(
          'Quản lý từ vựng',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF9C36B5),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            onPressed: _refreshData,
            icon: const Icon(
              Icons.refresh_rounded,
            ),
          ),
        ],
      ),
      floatingActionButton: _selectedLesson == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _isAddingVocabulary
                  ? null
                  : _addVocabulary,
              backgroundColor:
                  const Color(0xFF9C36B5),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Thêm từ vựng'),
            ),
      body: SafeArea(
        child: _isLoadingLessons
            ? _buildLoadingView(
                'Đang tải bài học...',
              )
            : _errorMessage != null
                ? _buildErrorView()
                : _lessons.isEmpty
                    ? const Center(
                        child: Text(
                          'Chưa có bài học để quản lý từ vựng.',
                        ),
                      )
                    : Column(
                        children: [
                          _buildLessonSelector(),
                          Expanded(
                            child: _isLoadingVocabularies
                                ? _buildLoadingView(
                                    'Đang tải từ vựng...',
                                  )
                                : _vocabularies.isEmpty
                                    ? _buildEmptyView()
                                    : _buildVocabularyList(),
                          ),
                        ],
                      ),
      ),
    );
  }
}