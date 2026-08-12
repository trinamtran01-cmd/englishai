import 'package:flutter/material.dart';

import '../models/ai_vocabulary_scan.dart';
import '../services/ai_vision_vocabulary_service.dart';
import '../widgets/vocabulary_result_card.dart';

/// Màn hình Từ điển AI: người dùng gõ 1 từ/cụm từ tiếng Anh bất kỳ,
/// AI (Gemini) trả về nghĩa, phiên âm, từ loại, câu ví dụ.
///
/// Tái sử dụng AiVisionVocabularyService.analyzeTextAndSave (cùng
/// collection ai_vocabulary_scans, sourceType 'dictionary') và widget
/// VocabularyResultCard đã dùng chung với AI Camera từ vựng.
class AiDictionaryScreen extends StatefulWidget {
  const AiDictionaryScreen({super.key});

  @override
  State<AiDictionaryScreen> createState() =>
      _AiDictionaryScreenState();
}

class _AiDictionaryScreenState extends State<AiDictionaryScreen> {
  static const Color _accentColor = Color(0xFF3B5BDB);

  final AiVisionVocabularyService _visionService =
      AiVisionVocabularyService();

  final TextEditingController _searchController =
      TextEditingController();

  AiVocabularyScan? _currentResult;

  bool _isSearching = false;
  String? _errorMessage;

  @override
  void dispose() {
    _searchController.dispose();
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

  Future<void> _search() async {
    final String word = _searchController.text.trim();

    if (word.isEmpty || _isSearching) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isSearching = true;
      _errorMessage = null;
      _currentResult = null;
    });

    try {
      final AiVocabularyScan scan =
          await _visionService.analyzeTextAndSave(word);

      if (!mounted) {
        return;
      }

      setState(() {
        _currentResult = scan;
        _isSearching = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSearching = false;
        _errorMessage = _cleanErrorMessage(error);
      });
    }
  }

  /// Hiện lại một từ trong lịch sử ngay trên khung kết quả, không
  /// gọi lại AI vì dữ liệu đã có sẵn.
  void _showFromHistory(AiVocabularyScan scan) {
    FocusScope.of(context).unfocus();

    setState(() {
      _currentResult = scan;
      _errorMessage = null;
      _searchController.text = scan.word;
    });
  }

  Future<void> _confirmDeleteScan(AiVocabularyScan scan) async {
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Xóa từ vựng'),
          content: Text(
            'Bạn có chắc chắn muốn xóa từ "${scan.word}" '
            'khỏi lịch sử tra cứu không?',
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

      if (!mounted) {
        return;
      }

      if (_currentResult?.id == scan.id) {
        setState(() {
          _currentResult = null;
        });
      }
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

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: TextField(
        controller: _searchController,
        textInputAction: TextInputAction.search,
        onSubmitted: (String _) {
          _search();
        },
        decoration: InputDecoration(
          hintText: 'Nhập một từ hoặc cụm từ tiếng Anh...',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: _isSearching
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _accentColor,
                    ),
                  ),
                )
              : IconButton(
                  tooltip: 'Tra từ',
                  onPressed: _search,
                  icon: const Icon(
                    Icons.arrow_forward_rounded,
                    color: _accentColor,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.red.withValues(alpha: 0.24),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: Colors.red.shade400,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _errorMessage ?? 'Đã xảy ra lỗi không xác định.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistorySection() {
    return StreamBuilder<List<AiVocabularyScan>>(
      stream: _visionService.getCurrentUserScans(),
      builder: (
        BuildContext context,
        AsyncSnapshot<List<AiVocabularyScan>> snapshot,
      ) {
        final List<AiVocabularyScan> allScans =
            snapshot.data ?? <AiVocabularyScan>[];

        final List<AiVocabularyScan> historyScans = allScans
            .where(
              (AiVocabularyScan scan) =>
                  scan.sourceType == 'dictionary',
            )
            .toList();

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Lịch sử tra cứu gần đây',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              if (snapshot.connectionState ==
                      ConnectionState.waiting &&
                  !snapshot.hasData)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: _accentColor,
                    ),
                  ),
                )
              else if (historyScans.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Bạn chưa tra từ nào. Hãy thử tìm một từ '
                    'tiếng Anh bất kỳ ở ô tìm kiếm phía trên.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant,
                    ),
                  ),
                )
              else
                ...historyScans.map(_buildHistoryTile),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHistoryTile(AiVocabularyScan scan) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          _showFromHistory(scan);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 10,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      scan.word,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      scan.meaning,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                      ),
                    ),
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Từ điển AI',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: _accentColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          children: [
            _buildSearchBar(),
            if (_errorMessage != null) _buildErrorView(),
            if (_currentResult != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: VocabularyResultCard(scan: _currentResult!),
              ),
            _buildHistorySection(),
          ],
        ),
      ),
    );
  }
}
