import 'package:flutter/material.dart';

import '../models/listening_video.dart';
import '../services/listening_video_service.dart';
import 'listening_practice_screen.dart';

/// Danh sách các bài luyện nghe & nói AI dành cho học viên.
class ListeningVideoListScreen extends StatefulWidget {
  const ListeningVideoListScreen({super.key});

  @override
  State<ListeningVideoListScreen> createState() =>
      _ListeningVideoListScreenState();
}

class _ListeningVideoListScreenState
    extends State<ListeningVideoListScreen> {
  final ListeningVideoService _videoService =
      ListeningVideoService();

  static const Color _accentColor = Color(0xFF0C8599);

  /// Mở màn hình luyện tập cho bài luyện nghe được chọn.
  void _openPractice(ListeningVideo video) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return ListeningPracticeScreen(video: video);
        },
      ),
    );
  }

  Color _levelColor(String level) {
    switch (level.trim().toLowerCase()) {
      case 'intermediate':
        return const Color(0xFFF59F00);

      case 'advanced':
        return const Color(0xFFE03131);

      case 'beginner':
      default:
        return const Color(0xFF2F9E44);
    }
  }

  Widget _buildThumbnail(ListeningVideo video) {
    if (video.thumbnailUrl.isEmpty) {
      return Container(
        width: 96,
        height: 72,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _accentColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.headphones_rounded,
          color: _accentColor,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        video.thumbnailUrl,
        width: 96,
        height: 72,
        fit: BoxFit.cover,
        errorBuilder: (
          BuildContext context,
          Object error,
          StackTrace? stackTrace,
        ) {
          return Container(
            width: 96,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.headphones_rounded,
              color: _accentColor,
            ),
          );
        },
      ),
    );
  }

  Widget _buildVideoCard(ListeningVideo video) {
    final Color levelColor = _levelColor(video.level);

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
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          _openPractice(video);
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildThumbnail(video),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color:
                            levelColor.withValues(alpha: 0.12),
                        borderRadius:
                            BorderRadius.circular(20),
                      ),
                      child: Text(
                        video.levelLabel,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: levelColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      video.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    if (video.description.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        video.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
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
              'Đang tải danh sách bài luyện nghe...',
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
            Text(
              'Không thể tải danh sách',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
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
            Text(
              'Chưa có bài luyện nghe',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Quản trị viên chưa thêm bài luyện nghe nào. '
              'Vui lòng quay lại sau.',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Luyện nghe & nói AI',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: _accentColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(
                20,
                20,
                20,
                22,
              ),
              decoration: const BoxDecoration(
                color: _accentColor,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(26),
                  bottomRight: Radius.circular(26),
                ),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nghe, điền từ và luyện nói cùng AI',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 7),
                  Text(
                    'Chọn một video để bắt đầu luyện nghe, sau đó '
                    'ghi âm giọng nói để AI nhận xét.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<List<ListeningVideo>>(
                stream: _videoService.getAllVideos(),
                builder: (
                  BuildContext context,
                  AsyncSnapshot<List<ListeningVideo>> snapshot,
                ) {
                  if (snapshot.connectionState ==
                          ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return _buildLoadingView();
                  }

                  if (snapshot.hasError) {
                    return _buildErrorView(
                      snapshot.error.toString(),
                    );
                  }

                  final List<ListeningVideo> videos =
                      snapshot.data ?? <ListeningVideo>[];

                  if (videos.isEmpty) {
                    return _buildEmptyView();
                  }

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(
                      20,
                      20,
                      20,
                      32,
                    ),
                    children:
                        videos.map(_buildVideoCard).toList(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
