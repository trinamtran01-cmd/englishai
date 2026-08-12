import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:record/record.dart';

import '../models/shadowing_ai_feedback.dart';
import '../models/shadowing_attempt.dart';
import '../models/shadowing_lesson.dart';
import '../models/shadowing_segment.dart';
import '../services/shadowing_ai_feedback_service.dart';
import '../services/shadowing_lesson_service.dart';
import '../services/shadowing_practice_service.dart';

/// Màn hình luyện Shadowing: nghe từng câu (TTS đọc to), ghi âm nhại
/// lại, chấm điểm từng từ, và xem AI Coach nhận xét phát âm.
class ShadowingPracticeScreen extends StatefulWidget {
  final ShadowingLesson lesson;

  const ShadowingPracticeScreen({
    super.key,
    required this.lesson,
  });

  @override
  State<ShadowingPracticeScreen> createState() =>
      _ShadowingPracticeScreenState();
}

class _ShadowingPracticeScreenState
    extends State<ShadowingPracticeScreen> {
  static const Color _accentColor = Color(0xFF7048E8);

  final ShadowingLessonService _lessonService =
      ShadowingLessonService();

  final ShadowingPracticeService _practiceService =
      ShadowingPracticeService();

  final ShadowingAiFeedbackService _feedbackService =
      ShadowingAiFeedbackService();

  final FlutterTts _flutterTts = FlutterTts();

  final AudioRecorder _audioRecorder = AudioRecorder();

  final AudioPlayer _audioPlayer = AudioPlayer();

  List<ShadowingSegment> _segments = <ShadowingSegment>[];
  int _currentIndex = 0;
  final Set<int> _practicedIndices = <int>{};

  bool _isLoadingSegments = true;
  String? _loadError;

  double _speechRate = 0.45;
  bool _isSpeaking = false;

  bool _isRecording = false;
  bool _isSubmitting = false;

  /// Đường dẫn file ghi âm trên mobile (dùng để phát lại qua
  /// [DeviceFileSource]). Trên web luôn là null, dùng
  /// [_recordedAudioBytes] thay thế.
  String? _recordedAudioPath;

  /// Dữ liệu ghi âm dạng bytes trên web (dùng để phát lại qua
  /// [BytesSource], vì web không có hệ thống file cục bộ).
  Uint8List? _recordedAudioBytes;

  ShadowingAttempt? _attempt;
  String? _submitError;

  bool _isRequestingFeedback = false;

  final Set<int> _highlightedWordIndices = <int>{};

  bool _showIpa = true;
  bool _showTranslation = false;
  bool _isTranslating = false;
  String? _adHocTranslation;

  @override
  void initState() {
    super.initState();
    _configureTts();
    _loadSegments();
  }

  @override
  void dispose() {
    _flutterTts.stop();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  /// Loại bỏ tiền tố "Exception: " để hiển thị gọn hơn cho người dùng.
  String _cleanErrorMessage(Object error) {
    final String message = error.toString();

    if (message.startsWith('Exception: ')) {
      return message.substring('Exception: '.length);
    }

    return message;
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Nạp dữ liệu.
  // ---------------------------------------------------------------------

  Future<void> _configureTts() async {
    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setSpeechRate(_speechRate);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);

    _flutterTts.setCompletionHandler(() {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSpeaking = false;
      });
    });

    _flutterTts.setErrorHandler((dynamic message) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSpeaking = false;
      });
    });
  }

  Future<void> _loadSegments() async {
    setState(() {
      _isLoadingSegments = true;
      _loadError = null;
    });

    try {
      final List<ShadowingSegment> segments =
          await _lessonService.getSegmentsByLessonOnce(
        widget.lesson.id,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _segments = segments;
        _currentIndex = 0;
        _isLoadingSegments = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingSegments = false;
        _loadError = _cleanErrorMessage(error);
      });
    }
  }

  ShadowingSegment get _currentSegment => _segments[_currentIndex];

  // ---------------------------------------------------------------------
  // Nghe câu mẫu (TTS).
  // ---------------------------------------------------------------------

  Future<void> _speakCurrentSegment() async {
    if (_segments.isEmpty) {
      return;
    }

    setState(() {
      _isSpeaking = true;
    });

    await _flutterTts.stop();
    await _flutterTts.speak(_currentSegment.text);
  }

  Future<void> _changeSpeechRate(double rate) async {
    setState(() {
      _speechRate = rate;
    });

    await _flutterTts.setSpeechRate(rate);
  }

  // ---------------------------------------------------------------------
  // Ghi âm & chấm điểm.
  // ---------------------------------------------------------------------

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopRecordingAndSubmit();
    } else {
      await _startRecording();
    }
  }

  /// Cấu hình ghi âm.
  ///
  /// Trên mobile/desktop dùng AAC ghi ra file cục bộ như trước.
  /// Trên web KHÔNG có hệ thống file cục bộ (`dart:io` là stub và
  /// ném lỗi "_Namespace" ngay khi gọi `Directory`/`File`), nên
  /// dùng `AudioEncoder.wav`: đây là encoder duy nhất mà package
  /// `record` tạo trực tiếp một WAV blob hợp lệ trên web (qua
  /// AudioWorklet + WavEncoder nội bộ, không phụ thuộc trình duyệt
  /// có hỗ trợ ghi âm định dạng đó hay không như các encoder khác),
  /// và `audio/wav` cũng là định dạng Gemini hỗ trợ chính thức.
  RecordConfig get _recordConfig {
    if (kIsWeb) {
      return const RecordConfig(
        encoder: AudioEncoder.wav,
        numChannels: 1,
        sampleRate: 16000,
      );
    }

    return const RecordConfig(encoder: AudioEncoder.aacLc);
  }

  Future<void> _startRecording() async {
    try {
      final bool hasPermission =
          await _audioRecorder.hasPermission();

      if (!hasPermission) {
        if (!mounted) {
          return;
        }

        _showErrorSnackBar(
          'Bạn cần cấp quyền micro để ghi âm luyện Shadowing.',
        );
        return;
      }

      String recordingPath = '';

      if (!kIsWeb) {
        final Directory tempDirectory =
            await Directory.systemTemp.createTemp('shadowing');

        recordingPath = '${tempDirectory.path}'
            '${Platform.pathSeparator}shadowing_'
            '${DateTime.now().millisecondsSinceEpoch}.m4a';
      }

      // Trên web, tham số path bị package `record` bỏ qua.
      await _audioRecorder.start(
        _recordConfig,
        path: recordingPath,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isRecording = true;
        _attempt = null;
        _submitError = null;
        _recordedAudioPath = null;
        _recordedAudioBytes = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isRecording = false;
      });

      _showErrorSnackBar(
        'Không thể bắt đầu ghi âm: '
        '${_cleanErrorMessage(error)}',
      );
    }
  }

  Future<void> _stopRecordingAndSubmit() async {
    // Trên mobile: đường dẫn file vừa ghi.
    // Trên web: một object URL dạng "blob:..." trỏ tới dữ liệu ghi
    // âm trong bộ nhớ trình duyệt (không phải đường dẫn file thật).
    String? stopResult;

    try {
      stopResult = await _audioRecorder.stop();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isRecording = false;
      });

      _showErrorSnackBar(
        'Không thể dừng ghi âm: ${_cleanErrorMessage(error)}',
      );
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isRecording = false;
    });

    if (stopResult == null) {
      _showErrorSnackBar(
        'Không tìm thấy dữ liệu ghi âm, vui lòng thử lại.',
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submitError = null;
      _recordedAudioPath = null;
      _recordedAudioBytes = null;
    });

    try {
      final Uint8List audioBytes;
      final String mimeType;

      if (kIsWeb) {
        // Blob URL chỉ tồn tại trong bộ nhớ trình duyệt, phải fetch
        // lại mới lấy được bytes thật (dart:io File không đọc được
        // scheme "blob:").
        final http.Response response = await http.get(
          Uri.parse(stopResult),
        );

        if (response.statusCode != 200) {
          throw Exception(
            'Không thể đọc dữ liệu ghi âm vừa tạo, '
            'vui lòng thử lại.',
          );
        }

        audioBytes = response.bodyBytes;
        mimeType = 'audio/wav';
      } else {
        audioBytes = await File(stopResult).readAsBytes();
        mimeType = 'audio/aac';
      }

      if (!mounted) {
        return;
      }

      setState(() {
        if (kIsWeb) {
          _recordedAudioBytes = audioBytes;
        } else {
          _recordedAudioPath = stopResult;
        }
      });

      final ShadowingAttempt attempt =
          await _practiceService.submitAttempt(
        _currentSegment.id,
        widget.lesson.id,
        audioBytes,
        mimeType,
        _currentSegment.text,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _attempt = attempt;
        _isSubmitting = false;
        _practicedIndices.add(_currentIndex);
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      final String message = _cleanErrorMessage(error);

      setState(() {
        _isSubmitting = false;
        _submitError = message;
      });

      _showErrorSnackBar(message);
    }
  }

  Future<void> _playRecordedAudio() async {
    try {
      if (kIsWeb) {
        final Uint8List? bytes = _recordedAudioBytes;

        if (bytes == null) {
          return;
        }

        await _audioPlayer.play(
          BytesSource(bytes, mimeType: 'audio/wav'),
        );
      } else {
        final String? path = _recordedAudioPath;

        if (path == null) {
          return;
        }

        await _audioPlayer.play(DeviceFileSource(path));
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showErrorSnackBar('Không thể phát lại bản ghi âm của bạn.');
    }
  }

  void _retrySegment() {
    setState(() {
      _attempt = null;
      _submitError = null;
      _recordedAudioPath = null;
      _recordedAudioBytes = null;
    });
  }

  Future<void> _goToNextSegment() async {
    if (_currentIndex >= _segments.length - 1) {
      await _showCompletionDialog();
      return;
    }

    await _jumpToSegment(_currentIndex + 1);
  }

  /// Nhảy thẳng tới câu bất kỳ (từ thanh chọn câu ở đầu màn hình,
  /// hoặc từ nút "Câu tiếp theo").
  Future<void> _jumpToSegment(int index) async {
    if (index < 0 ||
        index >= _segments.length ||
        index == _currentIndex) {
      return;
    }

    await _flutterTts.stop();

    if (!mounted) {
      return;
    }

    setState(() {
      _currentIndex = index;
      _isSpeaking = false;
      _attempt = null;
      _submitError = null;
      _recordedAudioPath = null;
      _recordedAudioBytes = null;
      _highlightedWordIndices.clear();
      _adHocTranslation = null;
    });
  }

  Future<void> _showCompletionDialog() async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          icon: const Icon(
            Icons.celebration_rounded,
            color: _accentColor,
            size: 48,
          ),
          title: const Text(
            'Hoàn thành bài luyện Shadowing',
            textAlign: TextAlign.center,
          ),
          content: const Text(
            'Bạn đã luyện xong tất cả các câu trong bài này. '
            'Hãy tiếp tục luyện tập để phát âm ngày càng chuẩn '
            'hơn nhé!',
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              style: FilledButton.styleFrom(
                backgroundColor: _accentColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Đóng'),
            ),
          ],
        );
      },
    );

    if (!mounted) {
      return;
    }

    Navigator.of(context).pop();
  }

  // ---------------------------------------------------------------------
  // AI Pronunciation Coach.
  // ---------------------------------------------------------------------

  Future<void> _requestAiFeedback() async {
    final ShadowingAttempt? attempt = _attempt;

    if (attempt == null || _isRequestingFeedback) {
      return;
    }

    setState(() {
      _isRequestingFeedback = true;
    });

    try {
      final ShadowingAiFeedback feedback =
          await _feedbackService.getFeedback(
        _currentSegment.id,
        _currentSegment.text,
        attempt.transcriptFromAudio,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isRequestingFeedback = false;
      });

      await _openFeedbackSheet(feedback);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isRequestingFeedback = false;
      });

      _showErrorSnackBar(_cleanErrorMessage(error));
    }
  }

  Future<void> _openFeedbackSheet(
    ShadowingAiFeedback feedback,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (BuildContext sheetContext) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          minChildSize: 0.4,
          maxChildSize: 0.92,
          builder: (
            BuildContext context,
            ScrollController scrollController,
          ) {
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 18),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                Row(
                  children: [
                    const Icon(
                      Icons.psychology_alt_rounded,
                      color: _accentColor,
                      size: 26,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'AI Pronunciation Coach',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                if (feedback.overallAssessment.trim().isNotEmpty)
                  _buildFeedbackSection(
                    icon: Icons.emoji_events_rounded,
                    iconColor: const Color(0xFFF59F00),
                    title: 'Đánh giá chung',
                    children: [
                      Text(
                        feedback.overallAssessment,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                if (feedback.strengths.isNotEmpty)
                  _buildFeedbackSection(
                    icon: Icons.thumb_up_alt_rounded,
                    iconColor: const Color(0xFF2F9E44),
                    title: 'Điểm tốt',
                    children: feedback.strengths
                        .map(_buildBulletLine)
                        .toList(),
                  ),
                if (feedback.improvements.isNotEmpty)
                  _buildFeedbackSection(
                    icon: Icons.priority_high_rounded,
                    iconColor: const Color(0xFFE03131),
                    title: 'Cần cải thiện',
                    children: feedback.improvements
                        .map(_buildBulletLine)
                        .toList(),
                  ),
                if (feedback.practiceTips.isNotEmpty)
                  _buildFeedbackSection(
                    icon: Icons.lightbulb_rounded,
                    iconColor: _accentColor,
                    title: 'Mẹo luyện tập',
                    children: feedback.practiceTips
                        .map(_buildBulletLine)
                        .toList(),
                  ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    _retrySegment();
                  },
                  icon: const Icon(Icons.mic_rounded),
                  label: const Text('Thử ghi âm lại'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _accentColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: 15,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------
  // Dịch nhanh bằng AI (khi câu chưa có sẵn bản dịch).
  // ---------------------------------------------------------------------

  Future<void> _translateWithAi() async {
    if (_isTranslating) {
      return;
    }

    setState(() {
      _isTranslating = true;
    });

    try {
      final String translation = await _feedbackService.quickTranslate(
        _currentSegment.text,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _adHocTranslation = translation;
        _isTranslating = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isTranslating = false;
      });

      _showErrorSnackBar(_cleanErrorMessage(error));
    }
  }

  Widget _buildFeedbackSection({
    required IconData icon,
    required Color iconColor,
    required String title,
    required List<Widget> children,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 19),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _buildBulletLine(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Icon(
              Icons.circle,
              size: 6,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.5,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Giao diện.
  // ---------------------------------------------------------------------

  Widget _buildSpeedChip(String label, double rate) {
    final bool isSelected = _speechRate == rate;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (bool selected) {
        if (!selected) {
          return;
        }
        _changeSpeechRate(rate);
      },
      selectedColor: _accentColor,
      labelStyle: TextStyle(
        color: isSelected
            ? Colors.white
            : Theme.of(context).colorScheme.onSurface,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected
              ? _accentColor
              : Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
    );
  }

  Widget _buildListenPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Câu ${_currentIndex + 1} / ${_segments.length}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Wrap(
                spacing: 6,
                children: [
                  _buildSpeedChip('Chậm', 0.3),
                  _buildSpeedChip('Vừa', 0.45),
                  _buildSpeedChip('Nhanh', 0.6),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Center(
            child: GestureDetector(
              onTap: _speakCurrentSegment,
              child: Container(
                width: 72,
                height: 72,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _accentColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _accentColor.withValues(alpha: 0.3),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(
                  _isSpeaking
                      ? Icons.volume_up_rounded
                      : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 36,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              _isSpeaking ? 'Đang đọc...' : 'Nhấn để nghe câu mẫu',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Tách câu thành từng từ, gộp mọi khoảng trắng/xuống dòng liên
  /// tiếp thành 1 khoảng cách — đảm bảo luôn wrap như văn bản bình
  /// thường (không phụ thuộc câu gốc có lỡ chứa ký tự xuống dòng
  /// hay không, vì `Wrap` tự ngắt dòng theo từng phần tử riêng).
  List<String> get _currentSentenceWords {
    return _currentSegment.text
        .split(RegExp(r'\s+'))
        .where((String word) => word.isNotEmpty)
        .toList();
  }

  Widget _buildSentenceWord(int index, String word) {
    final bool isHighlighted =
        _highlightedWordIndices.contains(index);

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isHighlighted) {
            _highlightedWordIndices.remove(index);
          } else {
            _highlightedWordIndices.add(index);
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 4,
          vertical: 2,
        ),
        decoration: BoxDecoration(
          color: isHighlighted
              ? _accentColor.withValues(alpha: 0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          word,
          style: TextStyle(
            fontSize: 20,
            height: 1.4,
            fontWeight: FontWeight.bold,
            color: isHighlighted
                ? _accentColor
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _buildToggleButton({
    required bool isActive,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: isActive
              ? _accentColor.withValues(alpha: 0.12)
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? _accentColor.withValues(alpha: 0.4)
                : Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive
                  ? Icons.visibility_rounded
                  : Icons.visibility_off_rounded,
              size: 15,
              color: isActive
                  ? _accentColor
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isActive
                    ? _accentColor
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTranslationBlock() {
    final String storedTranslation =
        _currentSegment.vietnameseTranslation.trim();

    final String? translation = storedTranslation.isNotEmpty
        ? storedTranslation
        : _adHocTranslation;

    if (translation != null && translation.trim().isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            translation,
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          if (storedTranslation.isEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '(Dịch bởi AI)',
              style: TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: Text(
            'Chưa có bản dịch cho câu này',
            style: TextStyle(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        TextButton.icon(
          onPressed: _isTranslating ? null : _translateWithAi,
          icon: _isTranslating
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _accentColor,
                  ),
                )
              : const Icon(Icons.translate_rounded, size: 18),
          label: const Text('Dịch bằng AI'),
          style: TextButton.styleFrom(
            foregroundColor: _accentColor,
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
        ),
      ],
    );
  }

  Widget _buildSentenceCard() {
    final String ipa = _currentSegment.ipaPronunciation.trim();
    final List<String> words = _currentSentenceWords;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _accentColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _accentColor.withValues(alpha: 0.16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 2,
            runSpacing: 2,
            children: [
              for (int index = 0; index < words.length; index++)
                _buildSentenceWord(index, words[index]),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (ipa.isNotEmpty)
                _buildToggleButton(
                  isActive: _showIpa,
                  label: 'IPA',
                  onTap: () {
                    setState(() {
                      _showIpa = !_showIpa;
                    });
                  },
                ),
              _buildToggleButton(
                isActive: _showTranslation,
                label: 'Dịch nghĩa',
                onTap: () {
                  setState(() {
                    _showTranslation = !_showTranslation;
                  });
                },
              ),
            ],
          ),
          if (_showIpa && ipa.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              ipa,
              style: const TextStyle(
                fontSize: 15,
                fontStyle: FontStyle.italic,
                color: _accentColor,
              ),
            ),
          ],
          if (_showTranslation) ...[
            const SizedBox(height: 10),
            _buildTranslationBlock(),
          ],
        ],
      ),
    );
  }

  Widget _buildRecordButton() {
    final Color color = _isRecording
        ? const Color(0xFFE03131)
        : _accentColor;

    final bool isDisabled = _isSubmitting;

    return GestureDetector(
      onTap: isDisabled ? null : _toggleRecording,
      child: Opacity(
        opacity: isDisabled ? 0.5 : 1,
        child: Container(
          width: 100,
          height: 100,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Icon(
            _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
            color: Colors.white,
            size: 44,
          ),
        ),
      ),
    );
  }

  Widget _buildResultCard(ShadowingAttempt attempt) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${attempt.roundedAccuracyPercent}%',
                style: const TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.bold,
                  color: _accentColor,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(
                  bottom: 8,
                  left: 8,
                ),
                child: Text(
                  '${attempt.correctWordCount}/'
                  '${attempt.wordResults.length} từ đúng',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (_recordedAudioPath != null || _recordedAudioBytes != null)
            Center(
              child: TextButton.icon(
                onPressed: _playRecordedAudio,
                icon: const Icon(Icons.play_circle_fill_rounded),
                label: const Text('Nghe lại bản ghi âm của bạn'),
                style: TextButton.styleFrom(
                  foregroundColor: _accentColor,
                ),
              ),
            ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: attempt.wordResults
                .map(_buildWordChip)
                .toList(),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed:
                _isRequestingFeedback ? null : _requestAiFeedback,
            icon: _isRequestingFeedback
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.psychology_alt_rounded),
            label: Text(
              _isRequestingFeedback
                  ? 'Đang phân tích...'
                  : 'Nhận xét phát âm từ AI',
            ),
            style: FilledButton.styleFrom(
              backgroundColor: _accentColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWordChip(Map<String, dynamic> item) {
    final bool isCorrect = item['isCorrect'] == true;
    final String word = item['word']?.toString() ?? '';

    final Color color = isCorrect
        ? const Color(0xFF2F9E44)
        : const Color(0xFFE03131);

    return Chip(
      label: Text(
        word,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: color,
      avatar: Icon(
        isCorrect ? Icons.check_rounded : Icons.close_rounded,
        color: Colors.white,
        size: 18,
      ),
    );
  }

  Widget _buildBottomActions() {
    final bool isLastSegment =
        _currentIndex >= _segments.length - 1;

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _isSubmitting ? null : _retrySegment,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Thử lại câu này'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _accentColor,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            onPressed: _attempt == null ? null : _goToNextSegment,
            icon: Icon(
              isLastSegment
                  ? Icons.check_circle_rounded
                  : Icons.arrow_forward_rounded,
            ),
            label: Text(
              isLastSegment ? 'Hoàn thành' : 'Câu tiếp theo',
            ),
            style: FilledButton.styleFrom(
              backgroundColor: _accentColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: _accentColor),
            const SizedBox(height: 18),
            Text(
              'Đang tải bài luyện Shadowing...',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              color: Colors.red,
              size: 62,
            ),
            const SizedBox(height: 18),
            const Text(
              'Không thể tải bài luyện',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _loadSegments,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Thử lại'),
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

  Widget _buildEmptyView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Text(
          'Bài luyện này chưa có câu nào. Vui lòng quay lại sau.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _buildSegmentSelector() {
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _segments.length,
        separatorBuilder: (BuildContext context, int index) {
          return const SizedBox(width: 8);
        },
        itemBuilder: (BuildContext context, int index) {
          final bool isCurrent = index == _currentIndex;
          final bool isPracticed = _practicedIndices.contains(index);

          final Color borderColor = isCurrent
              ? _accentColor
              : isPracticed
                  ? const Color(0xFF2F9E44)
                  : Theme.of(context).colorScheme.outlineVariant;

          return GestureDetector(
            onTap: () {
              _jumpToSegment(index);
            },
            child: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isCurrent
                    ? _accentColor
                    : isPracticed
                        ? const Color(0xFF2F9E44)
                            .withValues(alpha: 0.12)
                        : Theme.of(context).colorScheme.surface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: borderColor,
                  width: isCurrent ? 0 : 1.4,
                ),
              ),
              child: isPracticed && !isCurrent
                  ? const Icon(
                      Icons.check_rounded,
                      color: Color(0xFF2F9E44),
                      size: 20,
                    )
                  : Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isCurrent
                            ? Colors.white
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSegmentSelector(),
          const SizedBox(height: 16),
          _buildListenPanel(),
          const SizedBox(height: 16),
          _buildSentenceCard(),
          const SizedBox(height: 8),
          Text(
            'Nhấn vào từ để đánh dấu ôn lại nếu cần, sau đó nhấn '
            'nút micro để ghi âm nhại lại câu trên.',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Column(
              children: [
                if (_isSubmitting)
                  Column(
                    children: [
                      const CircularProgressIndicator(
                        color: _accentColor,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'AI đang chấm điểm phát âm, vui lòng chờ...',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  )
                else ...[
                  _buildRecordButton(),
                  const SizedBox(height: 12),
                  Text(
                    _isRecording
                        ? 'Đang ghi âm... nhấn để dừng'
                        : 'Nhấn để ghi âm nhại lại câu trên',
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (_submitError != null &&
              _attempt == null &&
              !_isSubmitting) ...[
            const SizedBox(height: 16),
            Text(
              _submitError!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.red,
              ),
            ),
          ],
          if (_attempt != null) ...[
            const SizedBox(height: 22),
            _buildResultCard(_attempt!),
          ],
          const SizedBox(height: 26),
          _buildBottomActions(),
        ],
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
        elevation: 0,
      ),
      body: SafeArea(
        child: _isLoadingSegments
            ? _buildLoadingView()
            : _loadError != null
                ? _buildErrorView(_loadError!)
                : _segments.isEmpty
                    ? _buildEmptyView()
                    : _buildContent(),
      ),
    );
  }
}
