import 'package:flutter/material.dart';

import '../models/writing_task.dart';
import '../services/writing_task_service.dart';
import '../widgets/card_thumbnail.dart';
import '../widgets/responsive_card_grid.dart';
import 'writing_practice_screen.dart';

/// Danh sách đề bài Luyện Viết AI dạng lưới thẻ, chia tab
/// Tất cả / Task 1 / Task 2.
class WritingTaskListScreen extends StatefulWidget {
  const WritingTaskListScreen({super.key});

  @override
  State<WritingTaskListScreen> createState() =>
      _WritingTaskListScreenState();
}

class _WritingTaskListScreenState extends State<WritingTaskListScreen> {
  static const Color _accentColor = Color(0xFFE8590C);
  static const Color _sourceTagColor = Color(0xFF5C7CFA);

  final WritingTaskService _taskService = WritingTaskService();

  void _openPractice(WritingTask task) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return WritingPracticeScreen(task: task);
        },
      ),
    );
  }

  /// Icon + nhãn hiển thị tương ứng với từng loại biểu đồ Task 1.
  ({IconData icon, String label}) _chartTypeDisplay(String chartType) {
    switch (chartType.trim().toLowerCase()) {
      case 'line':
        return (icon: Icons.show_chart_rounded, label: 'Biểu đồ đường');
      case 'bar':
        return (icon: Icons.bar_chart_rounded, label: 'Biểu đồ cột');
      case 'pie':
        return (icon: Icons.pie_chart_rounded, label: 'Biểu đồ tròn');
      case 'map':
        return (icon: Icons.map_rounded, label: 'Bản đồ / sơ đồ');
      case 'process':
        return (icon: Icons.sync_alt_rounded, label: 'Sơ đồ quy trình');
      case 'table':
        return (icon: Icons.table_chart_rounded, label: 'Bảng số liệu');
      default:
        return (icon: Icons.insert_chart_outlined_rounded, label: chartType);
    }
  }

  Widget _buildTag({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(WritingTask task) {
    final bool hasChartType = task.chartType.trim().isNotEmpty;
    final bool hasSource = task.source.trim().isNotEmpty;

    return Card(
      margin: EdgeInsets.zero,
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
          _openPractice(task);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CardThumbnail(
              imageUrl: task.imageUrl,
              placeholderIcon: Icons.description_rounded,
              placeholderColor: _accentColor,
              // Anh bieu do chua so lieu quan trong o sat vien - dung
              // contain + nen trang de khong bi cat mat chi tiet, khac
              // voi anh thumbnail video (cover) o cac man hinh khac.
              fit: BoxFit.contain,
              backgroundColor: Colors.white,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(13),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        height: 1.25,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tối thiểu ${task.minWords} từ',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                      ),
                    ),
                    if (hasChartType || hasSource) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (hasChartType)
                            _buildTag(
                              icon: _chartTypeDisplay(task.chartType).icon,
                              label: _chartTypeDisplay(task.chartType).label,
                              color: _accentColor,
                            ),
                          if (hasSource)
                            _buildTag(
                              icon: Icons.menu_book_rounded,
                              label: task.source.trim(),
                              color: _sourceTagColor,
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
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
              'Đang tải danh sách đề bài...',
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
              Icons.edit_note_rounded,
              color: _accentColor,
              size: 68,
            ),
            const SizedBox(height: 18),
            Text(
              'Chưa có đề bài',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Quản trị viên chưa thêm đề bài nào cho mục này. '
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

  /// Lưới thẻ đề bài, tự tính số cột theo chiều rộng khả dụng: màn
  /// hình rộng (web) 3 cột, hẹp hơn (mobile) 2 cột.
  Widget _buildTaskGrid(List<WritingTask> tasks) {
    if (tasks.isEmpty) {
      return _buildEmptyView();
    }

    return ResponsiveCardGrid(
      thumbnailAspectRatio: 16 / 9,
      contentHeight: 165,
      itemCount: tasks.length,
      itemBuilder: (BuildContext context, int index) {
        return _buildTaskCard(tasks[index]);
      },
    );
  }

  Widget _buildTaskList(
    AsyncSnapshot<List<WritingTask>> snapshot,
    String? taskType,
  ) {
    if (snapshot.connectionState == ConnectionState.waiting &&
        !snapshot.hasData) {
      return _buildLoadingView();
    }

    if (snapshot.hasError) {
      return _buildErrorView(snapshot.error.toString());
    }

    final List<WritingTask> allTasks = snapshot.data ?? <WritingTask>[];

    final List<WritingTask> tasks = taskType == null
        ? allTasks
        : allTasks
            .where(
              (WritingTask task) =>
                  task.taskType.trim().toLowerCase() == taskType,
            )
            .toList();

    return _buildTaskGrid(tasks);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Luyện Viết AI',
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
              Tab(text: 'Tất cả'),
              Tab(text: 'Task 1'),
              Tab(text: 'Task 2'),
            ],
          ),
        ),
        body: SafeArea(
          child: StreamBuilder<List<WritingTask>>(
            stream: _taskService.getAllTasks(),
            builder: (
              BuildContext context,
              AsyncSnapshot<List<WritingTask>> snapshot,
            ) {
              return TabBarView(
                children: [
                  _buildTaskList(snapshot, null),
                  _buildTaskList(snapshot, 'task1'),
                  _buildTaskList(snapshot, 'task2'),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
