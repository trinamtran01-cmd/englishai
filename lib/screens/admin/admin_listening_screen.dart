import 'package:flutter/material.dart';

import '../../models/listening_video.dart';
import '../../services/admin_service.dart';
import '../../services/listening_video_service.dart';
import '../../utils/seed_listening_data.dart';

/// Trang quản trị nội dung bài luyện nghe & nói AI.
///
/// Cho phép admin thêm, sửa, xóa các video luyện nghe cùng
/// transcript và câu gợi ý luyện nói.
class AdminListeningScreen extends StatefulWidget {
  const AdminListeningScreen({super.key});

  @override
  State<AdminListeningScreen> createState() =>
      _AdminListeningScreenState();
}

class _AdminListeningScreenState
    extends State<AdminListeningScreen> {
  static const Color _accentColor = Color(0xFF0C8599);

  final AdminService _adminService = AdminService();

  final ListeningVideoService _videoService =
      ListeningVideoService();

  List<ListeningVideo> _videos = <ListeningVideo>[];

  String? _processingVideoId;
  String? _errorMessage;

  bool _isLoading = true;
  bool _isCreatingSampleData = false;

  @override
  void initState() {
    super.initState();
    _loadVideos();
  }

  /// Tải lại danh sách một lần (không dùng stream sống), để tránh
  /// màn hình phía sau tự rebuild trong lúc dialog thêm/sửa đang
  /// đóng lại - nguyên nhân gây crash "_dependents.isEmpty" khi
  /// Navigator.pop() và một rebuild từ stream xảy ra gần như đồng
  /// thời.
  Future<void> _loadVideos() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final List<ListeningVideo> videos =
          await _videoService.getAllVideosOnce();

      if (!mounted) {
        return;
      }

      setState(() {
        _videos = videos;
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

  Future<void> _createSampleVideo() async {
    if (_isCreatingSampleData) {
      return;
    }

    setState(() {
      _isCreatingSampleData = true;
    });

    try {
      await _adminService.requireAdmin();

      await seedSampleListeningVideo();

      if (!mounted) {
        return;
      }

      setState(() {
        _isCreatingSampleData = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Đã kiểm tra và tạo dữ liệu bài luyện nghe mẫu.',
          ),
          backgroundColor: Colors.green,
        ),
      );

      await _loadVideos();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isCreatingSampleData = false;
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

  /// Trích xuất ID video từ link YouTube đầy đủ hoặc trả về
  /// nguyên chuỗi nếu người dùng đã dán sẵn ID.
  String _extractYoutubeId(String input) {
    final String cleanInput = input.trim();

    final Uri? uri = Uri.tryParse(cleanInput);

    if (uri != null) {
      if (uri.host.contains('youtu.be') &&
          uri.pathSegments.isNotEmpty) {
        return uri.pathSegments.first;
      }

      final String? videoId = uri.queryParameters['v'];

      if (videoId != null && videoId.trim().isNotEmpty) {
        return videoId.trim();
      }
    }

    return cleanInput;
  }

  Future<void> _showVideoForm({
    ListeningVideo? video,
  }) async {
    final bool isEditing = video != null;

    final TextEditingController titleController =
        TextEditingController(text: video?.title ?? '');

    final TextEditingController youtubeController =
        TextEditingController(
      text: video?.youtubeVideoId ?? '',
    );

    final TextEditingController descriptionController =
        TextEditingController(
      text: video?.description ?? '',
    );

    final TextEditingController speakingPromptController =
        TextEditingController(
      text: video?.speakingPrompt ?? '',
    );

    final TextEditingController transcriptController =
        TextEditingController(
      text: video?.transcriptWords.join(' ') ?? '',
    );

    final GlobalKey<FormState> formKey =
        GlobalKey<FormState>();

    String level = video?.level ?? 'beginner';
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
            Future<void> saveVideo() async {
              if (!formKey.currentState!.validate() ||
                  isSaving) {
                return;
              }

              setDialogState(() {
                isSaving = true;
              });

              final List<String> transcriptWords =
                  ListeningVideo.parseTranscriptText(
                transcriptController.text,
              );

              final ListeningVideo videoToSave =
                  ListeningVideo(
                id: video?.id ?? '',
                title: titleController.text.trim(),
                youtubeVideoId: _extractYoutubeId(
                  youtubeController.text,
                ),
                description:
                    descriptionController.text.trim(),
                transcriptWords: transcriptWords,
                speakingPrompt:
                    speakingPromptController.text.trim(),
                level: level,
                createdAt: video?.createdAt,
              );

              try {
                await _adminService.requireAdmin();

                if (isEditing) {
                  await _videoService.updateVideo(
                    videoToSave,
                  );
                } else {
                  await _videoService.addVideo(videoToSave);
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
                      'Không thể lưu bài luyện nghe: $error',
                    ),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }

            return AlertDialog(
              title: Text(
                isEditing
                    ? 'Chỉnh sửa bài luyện nghe'
                    : 'Thêm bài luyện nghe mới',
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
                          decoration: const InputDecoration(
                            labelText: 'Tiêu đề',
                            prefixIcon: Icon(
                              Icons.title_rounded,
                            ),
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
                        TextFormField(
                          controller: youtubeController,
                          enabled: !isSaving,
                          textInputAction:
                              TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText:
                                'Link hoặc ID video YouTube',
                            hintText:
                                'https://www.youtube.com/watch?v=...',
                            prefixIcon: Icon(
                              Icons.smart_display_rounded,
                            ),
                          ),
                          validator: (String? value) {
                            if (value == null ||
                                value.trim().isEmpty) {
                              return 'Vui lòng nhập link hoặc ID video';
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
                            prefixIcon: Icon(
                              Icons.notes_rounded,
                            ),
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
                        const SizedBox(height: 15),
                        TextFormField(
                          controller:
                              speakingPromptController,
                          enabled: !isSaving,
                          minLines: 2,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText:
                                'Câu gợi ý luyện nói',
                            alignLabelWithHint: true,
                            prefixIcon: Icon(
                              Icons.record_voice_over_rounded,
                            ),
                          ),
                          validator: (String? value) {
                            if (value == null ||
                                value.trim().isEmpty) {
                              return 'Vui lòng nhập câu gợi ý luyện nói';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 15),
                        TextFormField(
                          controller: transcriptController,
                          enabled: !isSaving,
                          minLines: 3,
                          maxLines: 8,
                          decoration: const InputDecoration(
                            labelText:
                                'Transcript (dán cả đoạn văn bản)',
                            hintText:
                                'Dán toàn bộ transcript video, hệ '
                                'thống sẽ tự tách thành từng từ',
                            alignLabelWithHint: true,
                            prefixIcon: Icon(
                              Icons.subtitles_rounded,
                            ),
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
                          Navigator.of(dialogContext)
                              .pop(false);
                        },
                  child: const Text('Hủy'),
                ),
                FilledButton.icon(
                  onPressed: isSaving ? null : saveVideo,
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
                            : 'Thêm bài luyện nghe',
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    titleController.dispose();
    youtubeController.dispose();
    descriptionController.dispose();
    speakingPromptController.dispose();
    transcriptController.dispose();

    if (wasSaved != true || !mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isEditing
              ? 'Đã cập nhật bài luyện nghe.'
              : 'Đã thêm bài luyện nghe mới.',
        ),
        backgroundColor: Colors.green,
      ),
    );

    await _loadVideos();
  }

  Future<void> _deleteVideo(ListeningVideo video) async {
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Xóa bài luyện nghe?'),
          content: Text(
            'Bạn có chắc muốn xóa "${video.title}" không?',
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
      _processingVideoId = video.id;
    });

    try {
      await _adminService.requireAdmin();

      await _videoService.deleteVideo(video.id);

      if (!mounted) {
        return;
      }

      setState(() {
        _processingVideoId = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã xóa bài luyện nghe.'),
          backgroundColor: Colors.green,
        ),
      );

      await _loadVideos();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _processingVideoId = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Không thể xóa bài luyện nghe: $error',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildVideoCard(ListeningVideo video) {
    final bool isProcessing =
        _processingVideoId == video.id;

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
                    color:
                        _accentColor.withValues(alpha: 0.11),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.headphones_rounded,
                    color: _accentColor,
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
                        video.title,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${video.levelLabel} • '
                        '${video.transcriptWords.length} từ '
                        'transcript',
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
            if (video.speakingPrompt.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  video.speakingPrompt,
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
                        color: _accentColor,
                        strokeWidth: 2,
                      ),
                    ),
                  )
                else ...[
                  IconButton(
                    tooltip: 'Chỉnh sửa',
                    onPressed: () {
                      _showVideoForm(video: video);
                    },
                    icon: const Icon(
                      Icons.edit_outlined,
                      color: Color(0xFF3B5BDB),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Xóa',
                    onPressed: () {
                      _deleteVideo(video);
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
              Icons.headphones_outlined,
              color: _accentColor,
              size: 68,
            ),
            const SizedBox(height: 18),
            const Text(
              'Chưa có bài luyện nghe',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () {
                _showVideoForm();
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Thêm bài luyện nghe'),
              style: FilledButton.styleFrom(
                backgroundColor: _accentColor,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _isCreatingSampleData
                  ? null
                  : _createSampleVideo,
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
          'Quản lý luyện nghe & nói',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: _accentColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            onPressed: _isLoading ? null : _loadVideos,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showVideoForm();
        },
        backgroundColor: _accentColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Thêm bài luyện nghe'),
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

            if (_videos.isEmpty) {
              return _buildEmptyView();
            }

            return RefreshIndicator(
              color: _accentColor,
              onRefresh: _loadVideos,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  20,
                  20,
                  20,
                  100,
                ),
                children: _videos.map(_buildVideoCard).toList(),
              ),
            );
          },
        ),
      ),
    );
  }
}
