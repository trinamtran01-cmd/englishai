import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:record/record.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../models/listening_attempt.dart';
import '../models/listening_video.dart';
import '../models/speaking_feedback.dart';
import '../services/ai_speaking_feedback_service.dart';
import '../services/listening_practice_service.dart';

enum _PracticeStage { listening, speaking }

class _TypedWordResult {
  final String word;
  final bool isCorrect;

  const _TypedWordResult({
    required this.word,
    required this.isCorrect,
  });
}

/// Màn hình luyện tập 2 bước cho một bài luyện nghe & nói:
///
/// - Giai đoạn A: xem video YouTube, nghe & điền từ, chấm ngay từng từ.
/// - Giai đoạn B: ghi âm đọc lại câu gợi ý, gửi Gemini API phân tích.
class ListeningPracticeScreen extends StatefulWidget {
  final ListeningVideo video;

  const ListeningPracticeScreen({
    super.key,
    required this.video,
  });

  @override
  State<ListeningPracticeScreen> createState() =>
      _ListeningPracticeScreenState();
}

class _ListeningPracticeScreenState
    extends State<ListeningPracticeScreen> {
  static const Color _accentColor = Color(0xFF0C8599);

  final ListeningPracticeService _practiceService =
      ListeningPracticeService();

  final AiSpeakingFeedbackService _speakingService =
      AiSpeakingFeedbackService();

  final AudioRecorder _audioRecorder = AudioRecorder();

  final TextEditingController _wordController =
      TextEditingController();

  late final YoutubePlayerController _youtubeController;

  _PracticeStage _stage = _PracticeStage.listening;

  final List<_TypedWordResult> _typedWords =
      <_TypedWordResult>[];

  bool _isSubmittingListening = false;

  bool _isRecording = false;
  bool _isAnalyzingSpeaking = false;

  SpeakingFeedback? _speakingFeedback;
  String? _speakingError;

  @override
  void initState() {
    super.initState();
    _youtubeController = YoutubePlayerController.fromVideoId(
      videoId: widget.video.youtubeVideoId,
      autoPlay: false,
    );
  }

  @override
  void dispose() {
    _youtubeController.close();
    _wordController.dispose();
    _audioRecorder.dispose();
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
  // Giai đoạn A: nghe & điền từ.
  // ---------------------------------------------------------------------

  void _addTypedWord() {
    final String rawWord = _wordController.text.trim();

    if (rawWord.isEmpty) {
      return;
    }

    final bool isCorrect = widget.video.transcriptWords
        .contains(rawWord.toLowerCase());

    setState(() {
      _typedWords.add(
        _TypedWordResult(
          word: rawWord,
          isCorrect: isCorrect,
        ),
      );
      _wordController.clear();
    });
  }

  Future<void> _completeListening() async {
    if (_isSubmittingListening) {
      return;
    }

    if (_typedWords.isEmpty) {
      _showErrorSnackBar(
        'Vui lòng gõ ít nhất một từ bạn nghe được.',
      );
      return;
    }

    setState(() {
      _isSubmittingListening = true;
    });

    try {
      final ListeningAttempt attempt =
          await _practiceService.submitAttempt(
        widget.video.id,
        _typedWords
            .map((_TypedWordResult item) => item.word)
            .toList(),
        widget.video.transcriptWords,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isSubmittingListening = false;
      });

      await _showListeningResultDialog(attempt);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSubmittingListening = false;
      });

      _showErrorSnackBar(_cleanErrorMessage(error));
    }
  }

  Future<void> _showListeningResultDialog(
    ListeningAttempt attempt,
  ) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          icon: const Icon(
            Icons.headphones_rounded,
            color: _accentColor,
            size: 48,
          ),
          title: const Text(
            'Hoàn thành nghe & điền từ',
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${attempt.roundedScore}%',
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: _accentColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Đúng ${attempt.correctCount} • '
                'Sai ${attempt.incorrectCount}',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            FilledButton.icon(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                setState(() {
                  _stage = _PracticeStage.speaking;
                });
              },
              icon: const Icon(Icons.mic_rounded),
              label: const Text('Tiếp tục luyện nói'),
              style: FilledButton.styleFrom(
                backgroundColor: _accentColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------
  // Giai đoạn B: luyện nói.
  // ---------------------------------------------------------------------

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopRecordingAndAnalyze();
    } else {
      await _startRecording();
    }
  }

  /// Cấu hình ghi âm.
  ///
  /// Web không có hệ thống file cục bộ (`dart:io` là stub và ném
  /// lỗi "_Namespace" ngay khi gọi `Directory`/`File`), nên dùng
  /// `AudioEncoder.wav`: encoder duy nhất mà package `record` tạo
  /// trực tiếp một WAV blob hợp lệ trên web (qua AudioWorklet nội
  /// bộ, không phụ thuộc trình duyệt hỗ trợ ghi âm định dạng đó hay
  /// không), và `audio/wav` cũng là định dạng Gemini hỗ trợ chính
  /// thức.
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
          'Bạn cần cấp quyền micro để ghi âm luyện nói.',
        );
        return;
      }

      String recordingPath = '';

      if (!kIsWeb) {
        final Directory tempDirectory =
            await Directory.systemTemp.createTemp(
          'listening_speaking',
        );

        recordingPath = '${tempDirectory.path}'
            '${Platform.pathSeparator}speaking_'
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
        _speakingFeedback = null;
        _speakingError = null;
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

  Future<void> _stopRecordingAndAnalyze() async {
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
        'Không thể dừng ghi âm: '
        '${_cleanErrorMessage(error)}',
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
      _isAnalyzingSpeaking = true;
      _speakingError = null;
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

      final SpeakingFeedback feedback =
          await _speakingService.analyzeAudioAndSave(
        audioBytes,
        mimeType,
        widget.video.id,
        widget.video.speakingPrompt,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _speakingFeedback = feedback;
        _isAnalyzingSpeaking = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      final String message = _cleanErrorMessage(error);

      setState(() {
        _isAnalyzingSpeaking = false;
        _speakingError = message;
      });

      _showErrorSnackBar(message);
    }
  }

  void _retrySpeaking() {
    setState(() {
      _speakingFeedback = null;
      _speakingError = null;
    });
  }

  void _finishPractice() {
    Navigator.of(context).pop();
  }

  // ---------------------------------------------------------------------
  // Giao diện.
  // ---------------------------------------------------------------------

  Widget _buildWordChip(_TypedWordResult item) {
    final Color color = item.isCorrect
        ? const Color(0xFF2F9E44)
        : const Color(0xFFE03131);

    return Chip(
      label: Text(
        item.word,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: color,
      avatar: Icon(
        item.isCorrect
            ? Icons.check_rounded
            : Icons.close_rounded,
        color: Colors.white,
        size: 18,
      ),
    );
  }

  Widget _buildListeningStage() {
    final int correctCount = _typedWords
        .where((_TypedWordResult item) => item.isCorrect)
        .length;

    final int incorrectCount =
        _typedWords.length - correctCount;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: ConstrainedBox(
              // Giới hạn chiều rộng tối đa để video không bị phóng to
              // tràn màn hình trên web/desktop (viewport rộng hơn
              // nhiều so với điện thoại); trên mobile, chiều rộng màn
              // hình luôn nhỏ hơn mức này nên không ảnh hưởng gì.
              constraints: const BoxConstraints(maxWidth: 640),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: YoutubePlayer(
                  controller: _youtubeController,
                  aspectRatio: 16 / 9,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            widget.video.title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Vừa nghe vừa gõ những từ tiếng Anh bạn nghe được. '
            'Mỗi từ sẽ được chấm ngay: xanh là đúng, đỏ là sai.',
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _wordController,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Gõ một từ bạn nghe được',
                    prefixIcon: Icon(Icons.edit_note_rounded),
                  ),
                  onSubmitted: (String _) {
                    _addTypedWord();
                  },
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: _addTypedWord,
                style: FilledButton.styleFrom(
                  backgroundColor: _accentColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_typedWords.isEmpty)
            Text(
              'Chưa có từ nào được thêm.',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            )
          else ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  _typedWords.map(_buildWordChip).toList(),
            ),
            const SizedBox(height: 10),
            Text(
              'Đúng $correctCount • Sai $incorrectCount',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _isSubmittingListening
                ? null
                : _completeListening,
            icon: _isSubmittingListening
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.check_circle_rounded),
            label: Text(
              _isSubmittingListening
                  ? 'Đang chấm điểm...'
                  : 'Hoàn thành nghe',
            ),
            style: FilledButton.styleFrom(
              backgroundColor: _accentColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                vertical: 16,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordButton() {
    final Color color = _isRecording
        ? const Color(0xFFE03131)
        : _accentColor;

    return GestureDetector(
      onTap: _isAnalyzingSpeaking ? null : _toggleRecording,
      child: Container(
        width: 108,
        height: 108,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.35),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Icon(
          _isRecording
              ? Icons.stop_rounded
              : Icons.mic_rounded,
          color: Colors.white,
          size: 48,
        ),
      ),
    );
  }

  Widget _buildFeedbackCard(SpeakingFeedback feedback) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${feedback.pronunciationScore}',
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: _accentColor,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(
                    top: 14,
                    left: 4,
                  ),
                  child: Text(
                    '/100',
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (feedback.transcriptFromAudio
                .trim()
                .isNotEmpty) ...[
              Text(
                'AI nghe được',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  feedback.transcriptFromAudio,
                  style: const TextStyle(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Text(
              'Nhận xét tổng quan',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              feedback.overallFeedback,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            if (feedback.pronunciationIssues
                .isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Điểm cần cải thiện',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              ...feedback.pronunciationIssues.map(
                (String issue) {
                  return Padding(
                    padding: const EdgeInsets.only(
                      bottom: 10,
                    ),
                    child: Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.priority_high_rounded,
                          color: Color(0xFFF59F00),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            issue,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.4,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSpeakingStage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _accentColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _accentColor.withValues(alpha: 0.18),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.format_quote_rounded,
                      color: _accentColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Câu cần đọc',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  widget.video.speakingPrompt,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Center(
            child: Column(
              children: [
                if (_isAnalyzingSpeaking)
                  Column(
                    children: [
                      const CircularProgressIndicator(
                        color: _accentColor,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'AI đang phân tích giọng nói, '
                        'vui lòng chờ...',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  )
                else if (_speakingFeedback == null) ...[
                  _buildRecordButton(),
                  const SizedBox(height: 14),
                  Text(
                    _isRecording
                        ? 'Đang ghi âm... nhấn để dừng'
                        : 'Nhấn để bắt đầu ghi âm',
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (_speakingError != null &&
              _speakingFeedback == null &&
              !_isAnalyzingSpeaking) ...[
            const SizedBox(height: 20),
            Text(
              _speakingError!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.red,
              ),
            ),
          ],
          if (_speakingFeedback != null) ...[
            const SizedBox(height: 8),
            _buildFeedbackCard(_speakingFeedback!),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _retrySpeaking,
                    icon: const Icon(Icons.mic_rounded),
                    label: const Text('Luyện lại'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _accentColor,
                      padding: const EdgeInsets.symmetric(
                        vertical: 15,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _finishPractice,
                    icon: const Icon(
                      Icons.check_circle_rounded,
                    ),
                    label: const Text('Hoàn thành'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _accentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        vertical: 15,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _stage == _PracticeStage.listening
              ? 'Nghe & điền từ'
              : 'Luyện nói',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: _accentColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: _stage == _PracticeStage.listening
            ? _buildListeningStage()
            : _buildSpeakingStage(),
      ),
    );
  }
}
