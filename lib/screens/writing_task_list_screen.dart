import 'package:flutter/material.dart';

import '../models/writing_task.dart';
import '../services/writing_task_service.dart';
import 'writing_practice_screen.dart';

/// Danh sách đề bài Luyện Viết AI, chia tab Task 1 / Task 2.
class WritingTaskListScreen extends StatefulWidget {
  const WritingTaskListScreen({super.key});

  @override
  State<WritingTaskListScreen> createState() =>
      _WritingTaskListScreenState();
}

class _WritingTaskListScreenState extends State<WritingTaskListScreen> {
  static const Color _accentColor = Color(0xFFE8590C);

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

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
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

  Widget _buildTaskCard(WritingTask task) {
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
          _openPractice(task);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.edit_note_rounded,
                  color: _accentColor,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tối thiểu ${task.minWords} từ',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                      ),
                    ),
                    if (task.chartType.trim().isNotEmpty ||
                        task.source.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          if (task.chartType.trim().isNotEmpty)
                            _buildTag(
                              task.chartType.trim(),
                              _accentColor,
                            ),
                          if (task.source.trim().isNotEmpty)
                            _buildTag(
                              task.source.trim(),
                              const Color(0xFF364FC7),
                            ),
                        ],
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

  Widget _buildTaskList(
    AsyncSnapshot<List<WritingTask>> snapshot,
    String taskType,
  ) {
    if (snapshot.connectionState == ConnectionState.waiting &&
        !snapshot.hasData) {
      return _buildLoadingView();
    }

    if (snapshot.hasError) {
      return _buildErrorView(snapshot.error.toString());
    }

    final List<WritingTask> tasks = (snapshot.data ?? <WritingTask>[])
        .where(
          (WritingTask task) =>
              task.taskType.trim().toLowerCase() == taskType,
        )
        .toList();

    if (tasks.isEmpty) {
      return _buildEmptyView();
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: tasks.map(_buildTaskCard).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
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
