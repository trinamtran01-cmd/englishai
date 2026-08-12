import 'package:flutter/material.dart';

import '../models/ai_vocabulary_scan.dart';
import '../services/ai_vision_vocabulary_service.dart';

/// Màn hình hiển thị danh sách từ vựng đã quét bằng AI Camera.
class AiVocabularyScanHistoryScreen extends StatefulWidget {
  const AiVocabularyScanHistoryScreen({super.key});

  @override
  State<AiVocabularyScanHistoryScreen> createState() =>
      _AiVocabularyScanHistoryScreenState();
}

class _AiVocabularyScanHistoryScreenState
    extends State<AiVocabularyScanHistoryScreen> {
  final AiVisionVocabularyService _visionService =
      AiVisionVocabularyService();

  Future<void> _confirmDeleteScan(
    AiVocabularyScan scan,
  ) async {
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Xóa từ vựng'),
          content: Text(
            'Bạn có chắc chắn muốn xóa từ "${scan.word}" '
            'khỏi lịch sử đã quét không?',
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

    try {
      await _visionService.deleteScan(scan.id);
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể xóa từ vựng: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildEmptyView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.camera_alt_outlined,
              size: 68,
              color: Color(0xFF3B5BDB),
            ),
            const SizedBox(height: 18),
            Text(
              'Chưa có từ vựng nào',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Hãy dùng AI Camera để chụp ảnh và tạo từ vựng '
              'đầu tiên của bạn.',
              textAlign: TextAlign.center,
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
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 18),
            Text(
              'Không thể tải lịch sử đã quét',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanTile(AiVocabularyScan scan) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF3B5BDB)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.translate_rounded,
                color: Color(0xFF3B5BDB),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          scan.word,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                      if (scan.pronunciation
                          .trim()
                          .isNotEmpty)
                        Text(
                          scan.pronunciation,
                          style: const TextStyle(
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                            color: Color(0xFF3B5BDB),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    scan.meaning,
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (scan.example.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      scan.example,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              tooltip: 'Xóa',
              onPressed: () {
                _confirmDeleteScan(scan);
              },
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: Colors.red,
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
          'Lịch sử đã quét',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF3B5BDB),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: StreamBuilder<List<AiVocabularyScan>>(
          stream: _visionService.getCurrentUserScans(),
          builder: (
            BuildContext context,
            AsyncSnapshot<List<AiVocabularyScan>> snapshot,
          ) {
            if (snapshot.connectionState ==
                    ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF3B5BDB),
                ),
              );
            }

            if (snapshot.hasError) {
              return _buildErrorView(
                snapshot.error.toString(),
              );
            }

            final List<AiVocabularyScan> scans =
                snapshot.data ?? <AiVocabularyScan>[];

            if (scans.isEmpty) {
              return _buildEmptyView();
            }

            return ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: scans.length,
              itemBuilder: (
                BuildContext context,
                int index,
              ) {
                return _buildScanTile(scans[index]);
              },
            );
          },
        ),
      ),
    );
  }
}
