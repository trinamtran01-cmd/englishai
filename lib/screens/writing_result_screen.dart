import 'package:flutter/material.dart';

import '../models/writing_ai_feedback.dart';
import '../models/writing_attempt.dart';
import '../models/writing_task.dart';

/// Màn hình hiển thị kết quả AI chấm bài Luyện Viết: band điểm tổng
/// + breakdown 4 tiêu chí, cùng 3 tab Tổng quan / Chữa bài / Nhận xét.
class WritingResultScreen extends StatelessWidget {
  const WritingResultScreen({
    super.key,
    required this.task,
    required this.attempt,
    required this.feedback,
  });

  final WritingTask task;
  final WritingAttempt attempt;
  final WritingAiFeedback feedback;

  static const Color _accentColor = Color(0xFFE8590C);

  String _formatBand(double band) {
    return band.toStringAsFixed(1);
  }

  Widget _buildBandHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_accentColor, Color(0xFFFF922B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _accentColor.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Band điểm tổng',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _formatBand(feedback.bandOverall),
            style: const TextStyle(
              fontSize: 52,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 18),
          _buildBandRow(
            'Lexical Resource',
            feedback.bandLexicalResource,
          ),
          const SizedBox(height: 10),
          _buildBandRow(
            'Task Achievement',
            feedback.bandTaskAchievement,
          ),
          const SizedBox(height: 10),
          _buildBandRow(
            'Grammatical Range & Accuracy',
            feedback.bandGrammaticalRange,
          ),
          const SizedBox(height: 10),
          _buildBandRow(
            'Coherence & Cohesion',
            feedback.bandCoherenceCohesion,
          ),
        ],
      ),
    );
  }

  Widget _buildBandRow(String label, double band) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white,
            ),
          ),
        ),
        Expanded(
          flex: 4,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (band / 9).clamp(0, 1),
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.25),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 28,
          child: Text(
            _formatBand(band),
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBulletSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required List<String> items,
    required String emptyText,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Text(
              emptyText,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            )
          else
            ...items.map(
              (String item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Icon(
                        Icons.circle,
                        size: 6,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color:
                              Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        _buildBulletSection(
          context,
          title: 'Điểm mạnh',
          icon: Icons.thumb_up_alt_rounded,
          color: const Color(0xFF2F9E44),
          items: feedback.strengths,
          emptyText: 'AI chưa ghi nhận điểm mạnh nổi bật nào.',
        ),
        _buildBulletSection(
          context,
          title: 'Ưu tiên sửa',
          icon: Icons.priority_high_rounded,
          color: const Color(0xFFE03131),
          items: feedback.priorityFixes,
          emptyText: 'Không có lỗi nào cần ưu tiên sửa.',
        ),
        _buildBulletSection(
          context,
          title: 'Phần còn thiếu',
          icon: Icons.report_problem_rounded,
          color: Colors.orange.shade700,
          items: feedback.missingParts,
          emptyText: 'Bài viết đã đủ các phần theo yêu cầu đề bài.',
        ),
      ],
    );
  }

  Widget _buildCorrectionTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        Text(
          'Bài làm của bạn (${attempt.wordCount} từ)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Text(
            attempt.userText,
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCommentTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
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
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.chat_bubble_outline_rounded,
                color: _accentColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  feedback.generalComment.trim().isEmpty
                      ? 'AI chưa để lại nhận xét tổng quan.'
                      : feedback.generalComment,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Kết quả chấm bài',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: _accentColor,
          foregroundColor: Colors.white,
          elevation: 0,
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: 'Tổng quan'),
              Tab(text: 'Chữa bài'),
              Tab(text: 'Nhận xét'),
            ],
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                child: _buildBandHeader(context),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildOverviewTab(context),
                    _buildCorrectionTab(context),
                    _buildCommentTab(context),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
