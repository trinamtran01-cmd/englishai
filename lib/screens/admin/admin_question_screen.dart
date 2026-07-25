import 'package:flutter/material.dart';

import '../../models/lesson.dart';
import '../../models/quiz_question.dart';
import '../../services/admin_service.dart';
import '../../services/lesson_service.dart';
import '../../services/quiz_service.dart';

class AdminQuestionScreen extends StatefulWidget {
  const AdminQuestionScreen({super.key});

  @override
  State<AdminQuestionScreen> createState() =>
      _AdminQuestionScreenState();
}

class _AdminQuestionScreenState
    extends State<AdminQuestionScreen> {
  final AdminService _adminService = AdminService();
  final LessonService _lessonService = LessonService();
  final QuizService _quizService = QuizService();

  List<Lesson> _lessons = <Lesson>[];
  List<QuizQuestion> _questions = <QuizQuestion>[];

  String? _selectedLessonId;
  String? _processingQuestionId;
  String? _errorMessage;

  bool _isLoadingLessons = true;
  bool _isLoadingQuestions = false;
  bool _isAddingQuestion = false;

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

      String? selectedLessonId = _selectedLessonId;

      if (lessons.isEmpty) {
        selectedLessonId = null;
      } else {
        final bool selectedLessonExists =
            selectedLessonId != null &&
                lessons.any(
                  (Lesson lesson) =>
                      lesson.id == selectedLessonId,
                );

        if (!selectedLessonExists) {
          selectedLessonId = lessons.first.id;
        }
      }

      setState(() {
        _lessons = lessons;
        _selectedLessonId = selectedLessonId;
        _isLoadingLessons = false;
      });

      if (selectedLessonId != null) {
        await _loadQuestions(selectedLessonId);
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

  Future<void> _loadQuestions(
    String lessonId,
  ) async {
    setState(() {
      _isLoadingQuestions = true;
      _errorMessage = null;
    });

    try {
      final List<QuizQuestion> questions =
          await _quizService.getQuestionsByLesson(
        lessonId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _questions = questions;
        _isLoadingQuestions = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingQuestions = false;
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
      _questions = <QuizQuestion>[];
    });

    await _loadQuestions(lessonId);
  }

  Future<void> _refreshData() async {
    final String? lessonId = _selectedLessonId;

    if (lessonId == null) {
      await _loadLessons();
      return;
    }

    await _loadQuestions(lessonId);
  }

  Future<void> _createSampleQuestions() async {
    final Lesson? lesson = _selectedLesson;

    if (lesson == null) {
      return;
    }

    setState(() {
      _isLoadingQuestions = true;
    });

    try {
      await _adminService.requireAdmin();
      await _quizService.createSampleQuestions(lesson);
      await _loadQuestions(lesson.id);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Đã kiểm tra và tạo dữ liệu câu hỏi mẫu.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingQuestions = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Không thể tạo câu hỏi mẫu: $error',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showQuestionForm({
    QuizQuestion? question,
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

    final bool isEditing = question != null;

    final TextEditingController questionController =
        TextEditingController(
      text: question?.question ?? '',
    );

    final List<TextEditingController> optionControllers =
        List<TextEditingController>.generate(
      4,
      (int index) {
        final String initialText =
            question != null &&
                    index < question.options.length
                ? question.options[index]
                : '';

        return TextEditingController(
          text: initialText,
        );
      },
    );

    final TextEditingController explanationController =
        TextEditingController(
      text: question?.explanation ?? '',
    );

    final TextEditingController orderController =
        TextEditingController(
      text: question?.order.toString() ??
          (_questions.length + 1).toString(),
    );

    final GlobalKey<FormState> formKey =
        GlobalKey<FormState>();

    int correctAnswerIndex =
        question?.correctAnswerIndex ?? 0;

    String difficulty =
        question?.difficulty.trim().toLowerCase() ??
            'easy';

    if (!<String>[
      'easy',
      'medium',
      'hard',
    ].contains(difficulty)) {
      difficulty = 'easy';
    }

    bool isActive = question?.isActive ?? true;
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
            Future<void> saveQuestion() async {
              if (!formKey.currentState!.validate() ||
                  isSaving) {
                return;
              }

              setDialogState(() {
                isSaving = true;
              });

              final List<String> options =
                  optionControllers
                      .map(
                        (
                          TextEditingController controller,
                        ) =>
                            controller.text.trim(),
                      )
                      .toList();

              final QuizQuestion questionToSave =
                  QuizQuestion(
                id: question?.id ?? '',
                lessonId: lesson.id,
                lessonTitle: lesson.title,
                question: questionController.text.trim(),
                options: options,
                correctAnswerIndex:
                    correctAnswerIndex,
                explanation:
                    explanationController.text.trim(),
                difficulty: difficulty,
                order: int.parse(
                  orderController.text.trim(),
                ),
                isActive: isActive,
                createdAt: question?.createdAt,
                updatedAt: question?.updatedAt,
              );

              try {
                await _adminService.requireAdmin();

                if (isEditing) {
                  await _quizService.updateQuestion(
                    questionToSave,
                  );
                } else {
                  await _quizService.addQuestion(
                    questionToSave,
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
                      'Không thể lưu câu hỏi: $error',
                    ),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }

            return AlertDialog(
              title: Text(
                isEditing
                    ? 'Chỉnh sửa câu hỏi'
                    : 'Thêm câu hỏi mới',
              ),
              content: SizedBox(
                width: 560,
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
                            color: const Color(0xFFF59F00)
                                .withValues(alpha: 0.10),
                            borderRadius:
                                BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Bài học: ${lesson.title}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFF08C00),
                            ),
                          ),
                        ),
                        const SizedBox(height: 15),
                        TextFormField(
                          controller: questionController,
                          enabled: !isSaving,
                          minLines: 2,
                          maxLines: 5,
                          decoration:
                              const InputDecoration(
                            labelText: 'Nội dung câu hỏi',
                            alignLabelWithHint: true,
                            prefixIcon: Padding(
                              padding: EdgeInsets.only(
                                bottom: 35,
                              ),
                              child: Icon(
                                Icons.help_outline_rounded,
                              ),
                            ),
                          ),
                          validator: (String? value) {
                            if (value == null ||
                                value.trim().isEmpty) {
                              return 'Vui lòng nhập nội dung câu hỏi';
                            }

                            return null;
                          },
                        ),
                        const SizedBox(height: 18),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Các phương án trả lời',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1A2E),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        for (
                          int index = 0;
                          index <
                              optionControllers.length;
                          index++
                        ) ...[
                          TextFormField(
                            controller:
                                optionControllers[index],
                            enabled: !isSaving,
                            textInputAction:
                                index ==
                                        optionControllers
                                                .length -
                                            1
                                    ? TextInputAction.done
                                    : TextInputAction.next,
                            decoration: InputDecoration(
                              labelText:
                                  'Đáp án ${String.fromCharCode(65 + index)}',
                              prefixIcon: IconButton(
                                tooltip: 'Chọn làm đáp án đúng',
                                onPressed: isSaving
                                    ? null
                                    : () {
                                        setDialogState(() {
                                          correctAnswerIndex = index;
                                        });
                                      },
                                icon: Icon(
                                  correctAnswerIndex == index
                                      ? Icons.radio_button_checked_rounded
                                      : Icons.radio_button_unchecked_rounded,
                                  color: correctAnswerIndex == index
                                      ? const Color(0xFFF59F00)
                                      : Colors.grey,
                                ),
                              ),
                              suffixIcon:
                                  correctAnswerIndex ==
                                          index
                                      ? const Icon(
                                          Icons
                                              .check_circle_rounded,
                                          color: Color(
                                            0xFF2F9E44,
                                          ),
                                        )
                                      : null,
                            ),
                            validator: (String? value) {
                              if (value == null ||
                                  value
                                      .trim()
                                      .isEmpty) {
                                return 'Vui lòng nhập đáp án';
                              }

                              return null;
                            },
                          ),
                          if (index <
                              optionControllers.length -
                                  1)
                            const SizedBox(height: 12),
                        ],
                        const SizedBox(height: 15),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2F9E44)
                                .withValues(alpha: 0.08),
                            borderRadius:
                                BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Đáp án đúng: '
                            '${String.fromCharCode(65 + correctAnswerIndex)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2F9E44),
                            ),
                          ),
                        ),
                        const SizedBox(height: 15),
                        TextFormField(
                          controller:
                              explanationController,
                          enabled: !isSaving,
                          minLines: 2,
                          maxLines: 5,
                          decoration:
                              const InputDecoration(
                            labelText: 'Lời giải thích',
                            alignLabelWithHint: true,
                            prefixIcon: Padding(
                              padding: EdgeInsets.only(
                                bottom: 35,
                              ),
                              child: Icon(
                                Icons
                                    .lightbulb_outline_rounded,
                              ),
                            ),
                          ),
                          validator: (String? value) {
                            if (value == null ||
                                value.trim().isEmpty) {
                              return 'Vui lòng nhập lời giải thích';
                            }

                            return null;
                          },
                        ),
                        const SizedBox(height: 15),
                        DropdownButtonFormField<String>(
                          initialValue: difficulty,
                          decoration:
                              const InputDecoration(
                            labelText: 'Mức độ khó',
                            prefixIcon: Icon(
                              Icons.signal_cellular_alt_rounded,
                            ),
                          ),
                          items: const [
                            DropdownMenuItem<String>(
                              value: 'easy',
                              child: Text('Dễ'),
                            ),
                            DropdownMenuItem<String>(
                              value: 'medium',
                              child: Text(
                                'Trung bình',
                              ),
                            ),
                            DropdownMenuItem<String>(
                              value: 'hard',
                              child: Text('Khó'),
                            ),
                          ],
                          onChanged: isSaving
                              ? null
                              : (String? value) {
                                  if (value == null) {
                                    return;
                                  }

                                  setDialogState(() {
                                    difficulty = value;
                                  });
                                },
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
                            'Câu hỏi đang hoạt động',
                          ),
                          subtitle: Text(
                            isActive
                                ? 'Câu hỏi được sử dụng trong bài kiểm tra'
                                : 'Câu hỏi đang bị ẩn',
                          ),
                          value: isActive,
                          activeThumbColor:
                              const Color(0xFFF59F00),
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
                      isSaving ? null : saveQuestion,
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        const Color(0xFFF59F00),
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
                            : 'Thêm câu hỏi',
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    questionController.dispose();
    explanationController.dispose();
    orderController.dispose();

    for (final TextEditingController controller
        in optionControllers) {
      controller.dispose();
    }

    if (wasSaved != true || !mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isEditing
              ? 'Đã cập nhật câu hỏi.'
              : 'Đã thêm câu hỏi mới.',
        ),
        backgroundColor: Colors.green,
      ),
    );

    await _loadQuestions(lesson.id);
  }

  Future<void> _addQuestion() async {
    if (_isAddingQuestion ||
        _selectedLesson == null) {
      return;
    }

    setState(() {
      _isAddingQuestion = true;
    });

    await _showQuestionForm();

    if (!mounted) {
      return;
    }

    setState(() {
      _isAddingQuestion = false;
    });
  }

  Future<void> _updateQuestionStatus(
    QuizQuestion question,
  ) async {
    if (_processingQuestionId != null) {
      return;
    }

    setState(() {
      _processingQuestionId = question.id;
    });

    try {
      await _adminService.updateQuestionStatus(
        questionId: question.id,
        isActive: !question.isActive,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _processingQuestionId = null;
      });

      await _refreshData();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _processingQuestionId = null;
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

  Future<void> _deleteQuestion(
    QuizQuestion question,
  ) async {
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          icon: const Icon(
            Icons.warning_amber_rounded,
            color: Colors.red,
            size: 48,
          ),
          title: const Text(
            'Xóa câu hỏi?',
            textAlign: TextAlign.center,
          ),
          content: Text(
            'Bạn có chắc chắn muốn xóa câu hỏi:\n\n'
            '“${question.question}”',
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
              label: const Text('Xóa'),
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
      _processingQuestionId = question.id;
    });

    try {
      await _adminService.requireAdmin();
      await _quizService.deleteQuestion(question.id);

      if (!mounted) {
        return;
      }

      setState(() {
        _processingQuestionId = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã xóa câu hỏi.'),
          backgroundColor: Colors.green,
        ),
      );

      await _refreshData();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _processingQuestionId = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Không thể xóa câu hỏi: $error',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Color _getDifficultyColor(
    String difficulty,
  ) {
    switch (difficulty.trim().toLowerCase()) {
      case 'hard':
        return Colors.red;

      case 'medium':
        return const Color(0xFFF59F00);

      case 'easy':
      default:
        return const Color(0xFF2F9E44);
    }
  }

  Widget _buildQuestionCard(
    QuizQuestion question,
  ) {
    final bool isProcessing =
        _processingQuestionId == question.id;

    final Color difficultyColor =
        _getDifficultyColor(question.difficulty);

    final Color statusColor = question.isActive
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
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59F00)
                        .withValues(alpha: 0.12),
                    borderRadius:
                        BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.quiz_rounded,
                    color: Color(0xFFF59F00),
                    size: 27,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Text(
                    question.question,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.4,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _QuestionLabel(
                  text: question.difficultyLabel,
                  color: difficultyColor,
                ),
                _QuestionLabel(
                  text: question.isActive
                      ? 'Hoạt động'
                      : 'Đang ẩn',
                  color: statusColor,
                ),
                _QuestionLabel(
                  text: 'Thứ tự ${question.order}',
                  color: const Color(0xFF3B5BDB),
                ),
              ],
            ),
            const SizedBox(height: 14),
            for (
              int index = 0;
              index < question.options.length;
              index++
            )
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(
                  bottom: 8,
                ),
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color:
                      index == question.correctAnswerIndex
                          ? const Color(0xFF2F9E44)
                              .withValues(alpha: 0.09)
                          : const Color(0xFFF7F8FC),
                  borderRadius:
                      BorderRadius.circular(11),
                  border: Border.all(
                    color:
                        index == question.correctAnswerIndex
                            ? const Color(0xFF2F9E44)
                                .withValues(alpha: 0.30)
                            : const Color(0xFFE8EAF2),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 29,
                      height: 29,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: index ==
                                question
                                    .correctAnswerIndex
                            ? const Color(0xFF2F9E44)
                            : Colors.grey.shade300,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        String.fromCharCode(65 + index),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: index ==
                                  question
                                      .correctAnswerIndex
                              ? Colors.white
                              : const Color(0xFF1A1A2E),
                        ),
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        question.options[index],
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                    ),
                    if (index ==
                        question.correctAnswerIndex)
                      const Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF2F9E44),
                        size: 20,
                      ),
                  ],
                ),
              ),
            if (question.explanation
                .trim()
                .isNotEmpty) ...[
              const SizedBox(height: 7),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59F00)
                      .withValues(alpha: 0.07),
                  borderRadius:
                      BorderRadius.circular(11),
                ),
                child: Text(
                  'Giải thích: ${question.explanation}',
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: Colors.grey,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
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
                        color: Color(0xFFF59F00),
                        strokeWidth: 2,
                      ),
                    ),
                  )
                else ...[
                  IconButton(
                    tooltip: question.isActive
                        ? 'Ẩn câu hỏi'
                        : 'Hiện câu hỏi',
                    onPressed: () {
                      _updateQuestionStatus(question);
                    },
                    icon: Icon(
                      question.isActive
                          ? Icons.visibility_rounded
                          : Icons
                              .visibility_off_rounded,
                      color: statusColor,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Chỉnh sửa',
                    onPressed: () {
                      _showQuestionForm(
                        question: question,
                      );
                    },
                    icon: const Icon(
                      Icons.edit_outlined,
                      color: Color(0xFF3B5BDB),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Xóa câu hỏi',
                    onPressed: () {
                      _deleteQuestion(question);
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
        onChanged:
            _isLoadingQuestions ? null : _selectLesson,
      ),
    );
  }

  Widget _buildLoadingView(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(
            color: Color(0xFFF59F00),
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
              Icons.quiz_outlined,
              color: Color(0xFFF59F00),
              size: 68,
            ),
            const SizedBox(height: 18),
            const Text(
              'Chưa có câu hỏi',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _addQuestion,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Thêm câu hỏi'),
              style: FilledButton.styleFrom(
                backgroundColor:
                    const Color(0xFFF59F00),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _createSampleQuestions,
              icon: const Icon(
                Icons.auto_awesome_rounded,
              ),
              label: const Text(
                'Tạo câu hỏi mẫu',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionList() {
    return RefreshIndicator(
      color: const Color(0xFFF59F00),
      onRefresh: _refreshData,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          20,
          20,
          20,
          100,
        ),
        children:
            _questions.map(_buildQuestionCard).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FF),
      appBar: AppBar(
        title: const Text(
          'Quản lý câu hỏi',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFFF59F00),
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
              onPressed: _isAddingQuestion
                  ? null
                  : _addQuestion,
              backgroundColor:
                  const Color(0xFFF59F00),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Thêm câu hỏi'),
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
                          'Chưa có bài học để quản lý câu hỏi.',
                        ),
                      )
                    : Column(
                        children: [
                          _buildLessonSelector(),
                          Expanded(
                            child: _isLoadingQuestions
                                ? _buildLoadingView(
                                    'Đang tải câu hỏi...',
                                  )
                                : _questions.isEmpty
                                    ? _buildEmptyView()
                                    : _buildQuestionList(),
                          ),
                        ],
                      ),
      ),
    );
  }
}

class _QuestionLabel extends StatelessWidget {
  final String text;
  final Color color;

  const _QuestionLabel({
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}