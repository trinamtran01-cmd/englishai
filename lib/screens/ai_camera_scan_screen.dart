import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/ai_vocabulary_scan.dart';
import '../services/ai_vision_vocabulary_service.dart';
import '../widgets/vocabulary_result_card.dart';
import 'ai_vocabulary_scan_history_screen.dart';

/// Màn hình chụp ảnh vật thể và nhờ AI (Gemini Vision) sinh
/// từ vựng tiếng Anh tương ứng, tự động lưu vào Firestore.
class AiCameraScanScreen extends StatefulWidget {
  const AiCameraScanScreen({super.key});

  @override
  State<AiCameraScanScreen> createState() =>
      _AiCameraScanScreenState();
}

class _AiCameraScanScreenState
    extends State<AiCameraScanScreen> {
  final AiVisionVocabularyService _visionService =
      AiVisionVocabularyService();

  final ImagePicker _imagePicker = ImagePicker();

  Uint8List? _selectedImageBytes;
  AiVocabularyScan? _scanResult;

  bool _isAnalyzing = false;
  String? _errorMessage;

  /// Mở camera, chụp ảnh rồi gửi cho Gemini Vision phân tích.
  ///
  /// Đọc bytes trực tiếp từ [XFile.readAsBytes] (hoạt động trên mọi
  /// nền tảng kể cả web) thay vì bọc qua `dart:io` File — File
  /// không đọc được đường dẫn dạng "blob:" mà web trả về.
  Future<void> _captureAndAnalyze() async {
    try {
      final XFile? capturedFile = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1280,
      );

      if (capturedFile == null || !mounted) {
        return;
      }

      final Uint8List imageBytes = await capturedFile.readAsBytes();

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedImageBytes = imageBytes;
        _scanResult = null;
        _errorMessage = null;
        _isAnalyzing = true;
      });

      final AiVocabularyScan scan = await _visionService
          .analyzeImageAndSave(imageBytes);

      if (!mounted) {
        return;
      }

      setState(() {
        _scanResult = scan;
        _isAnalyzing = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isAnalyzing = false;
        _errorMessage = _cleanErrorMessage(error);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_cleanErrorMessage(error)),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Loại bỏ tiền tố "Exception: " để hiển thị gọn hơn cho người dùng.
  String _cleanErrorMessage(Object error) {
    final String message = error.toString();

    if (message.startsWith('Exception: ')) {
      return message.substring('Exception: '.length);
    }

    return message;
  }

  /// Bắt đầu quét ảnh khác, quay lại giao diện ban đầu.
  void _scanAnotherImage() {
    setState(() {
      _selectedImageBytes = null;
      _scanResult = null;
      _errorMessage = null;
    });
  }

  void _openScanHistory() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return const AiVocabularyScanHistoryScreen();
        },
      ),
    );
  }

  Widget _buildStartView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 120,
              height: 120,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF3B5BDB)
                    .withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.camera_alt_rounded,
                color: Color(0xFF3B5BDB),
                size: 54,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Chụp ảnh để học từ vựng mới',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Chụp một vật thể bất kỳ, AI sẽ nhận diện và tạo '
              'từ vựng tiếng Anh kèm phiên âm, nghĩa và ví dụ.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _captureAndAnalyze,
              icon: const Icon(Icons.camera_alt_rounded),
              label: const Text('Chụp ảnh'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF3B5BDB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _openScanHistory,
              icon: const Icon(Icons.history_rounded),
              label: const Text('Xem lịch sử đã quét'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF3B5BDB),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    if (_selectedImageBytes == null) {
      return const SizedBox.shrink();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Image.memory(
        _selectedImageBytes!,
        height: 220,
        width: double.infinity,
        fit: BoxFit.cover,
      ),
    );
  }

  Widget _buildAnalyzingView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildImagePreview(),
          const SizedBox(height: 28),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(
                  color: Color(0xFF3B5BDB),
                ),
                const SizedBox(height: 18),
                Text(
                  'AI đang phân tích ảnh, vui lòng chờ...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildImagePreview(),
          const SizedBox(height: 24),
          Icon(
            Icons.error_outline_rounded,
            color: Colors.red.shade400,
            size: 56,
          ),
          const SizedBox(height: 14),
          Text(
            'Không thể phân tích ảnh',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage ?? 'Đã xảy ra lỗi không xác định.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _captureAndAnalyze,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Chụp lại'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF3B5BDB),
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
      ),
    );
  }

  Widget _buildResultView(AiVocabularyScan scan) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildImagePreview(),
          const SizedBox(height: 20),
          VocabularyResultCard(scan: scan),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _scanAnotherImage,
            icon: const Icon(Icons.camera_alt_rounded),
            label: const Text('Quét ảnh khác'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF3B5BDB),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                vertical: 15,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _openScanHistory,
            icon: const Icon(Icons.history_rounded),
            label: const Text('Xem lịch sử đã quét'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF3B5BDB),
              padding: const EdgeInsets.symmetric(
                vertical: 14,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'AI Camera từ vựng',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF3B5BDB),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Xem lịch sử đã quét',
            onPressed: _openScanHistory,
            icon: const Icon(Icons.history_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Builder(
          builder: (BuildContext context) {
            if (_isAnalyzing) {
              return _buildAnalyzingView();
            }

            if (_errorMessage != null) {
              return _buildErrorView();
            }

            if (_scanResult != null) {
              return _buildResultView(_scanResult!);
            }

            return _buildStartView();
          },
        ),
      ),
    );
  }
}
