import 'package:flutter/material.dart';

import '../../services/admin_service.dart';
import '../../services/auth_service.dart';
import 'admin_feature_flags_screen.dart';
import 'admin_lesson_screen.dart';
import 'admin_listening_screen.dart';
import 'admin_question_screen.dart';
import 'admin_shadowing_screen.dart';
import 'admin_user_screen.dart';
import 'admin_vocabulary_screen.dart';
import 'admin_writing_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final AdminService _adminService = AdminService();
  final AuthService _authService = AuthService();

  bool _isLoading = true;
  bool _isLoggingOut = false;

  String? _errorMessage;

  Map<String, int> _statistics = <String, int>{};

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final bool isAdmin = await _adminService.isCurrentUserAdmin();

      if (!mounted) {
        return;
      }

      if (!isAdmin) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Tài khoản hiện tại không có quyền quản trị viên.';
        });

        return;
      }

      final Map<String, int> statistics = await _adminService
          .getDashboardStatistics();

      if (!mounted) {
        return;
      }

      setState(() {
        _statistics = statistics;
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

  Future<void> _handleLogout() async {
    final bool? shouldLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Đăng xuất'),
          content: const Text(
            'Bạn có chắc chắn muốn đăng xuất khỏi '
            'tài khoản quản trị không?',
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
              child: const Text('Đăng xuất'),
            ),
          ],
        );
      },
    );

    if (shouldLogout != true || !mounted) {
      return;
    }

    setState(() {
      _isLoggingOut = true;
    });

    try {
      await _authService.logout();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoggingOut = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể đăng xuất: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _openLessonManagement() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return const AdminLessonScreen();
        },
      ),
    );

    if (!mounted) {
      return;
    }

    await _loadDashboard();
  }

  Future<void> _openVocabularyManagement() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return const AdminVocabularyScreen();
        },
      ),
    );

    if (!mounted) {
      return;
    }

    await _loadDashboard();
  }

  Future<void> _openQuestionManagement() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return const AdminQuestionScreen();
        },
      ),
    );

    if (!mounted) {
      return;
    }

    await _loadDashboard();
  }

  Future<void> _openUserManagement() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return const AdminUserScreen();
        },
      ),
    );

    if (!mounted) {
      return;
    }

    await _loadDashboard();
  }

  Future<void> _openListeningManagement() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return const AdminListeningScreen();
        },
      ),
    );

    if (!mounted) {
      return;
    }

    await _loadDashboard();
  }

  Future<void> _openShadowingManagement() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return const AdminShadowingScreen();
        },
      ),
    );

    if (!mounted) {
      return;
    }

    await _loadDashboard();
  }

  Future<void> _openWritingManagement() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return const AdminWritingScreen();
        },
      ),
    );

    if (!mounted) {
      return;
    }

    await _loadDashboard();
  }

  Future<void> _openFeatureFlagsManagement() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return const AdminFeatureFlagsScreen();
        },
      ),
    );

    if (!mounted) {
      return;
    }

    await _loadDashboard();
  }

  Widget _buildStatisticCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 3),
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                height: 1.25,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Lưới 4 thẻ số liệu, tự tính số cột + tỉ lệ khung hình theo
  /// chiều rộng khả dụng để mỗi thẻ luôn có chiều cao cố định gọn
  /// gàng thay vì bị kéo giãn hết cỡ trên màn hình rộng (web).
  ///
  /// Mobile (< 500px khả dụng) giữ đúng 2 cột như trước.
  Widget _buildStatisticsGrid({
    required int totalUsers,
    required int totalStudents,
    required int totalAdmins,
    required int totalLessons,
    required int activeLessons,
    required int totalVocabularies,
    required int totalQuestions,
  }) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double availableWidth = constraints.maxWidth;

        final int crossAxisCount = availableWidth >= 700
            ? 4
            : availableWidth >= 500
            ? 3
            : 2;

        const double spacing = 12;
        const double cardHeight = 132;

        final double columnWidth =
            (availableWidth - spacing * (crossAxisCount - 1)) / crossAxisCount;

        final double childAspectRatio = columnWidth / cardHeight;

        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: spacing,
          crossAxisSpacing: spacing,
          childAspectRatio: childAspectRatio,
          children: [
            _buildStatisticCard(
              icon: Icons.people_alt_rounded,
              value: totalUsers.toString(),
              label:
                  '$totalStudents học viên, '
                  '$totalAdmins quản trị',
              color: const Color(0xFF364FC7),
            ),
            _buildStatisticCard(
              icon: Icons.menu_book_rounded,
              value: totalLessons.toString(),
              label: '$activeLessons bài học đang hoạt động',
              color: const Color(0xFF2F9E44),
            ),
            _buildStatisticCard(
              icon: Icons.translate_rounded,
              value: totalVocabularies.toString(),
              label: 'Tổng số từ vựng',
              color: const Color(0xFF9C36B5),
            ),
            _buildStatisticCard(
              icon: Icons.quiz_rounded,
              value: totalQuestions.toString(),
              label: 'Tổng số câu hỏi',
              color: const Color(0xFFF59F00),
            ),
          ],
        );
      },
    );
  }

  Widget _buildManagementCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(17),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 29),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF2F9E44,
                            ).withValues(alpha: 0.11),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Đã kết nối',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2F9E44),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_ios_rounded, color: color, size: 17),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardContent() {
    final int totalUsers = _statistics['totalUsers'] ?? 0;

    final int totalStudents = _statistics['totalStudents'] ?? 0;

    final int totalAdmins = _statistics['totalAdmins'] ?? 0;

    final int totalLessons = _statistics['totalLessons'] ?? 0;

    final int activeLessons = _statistics['activeLessons'] ?? 0;

    final int totalVocabularies = _statistics['totalVocabularies'] ?? 0;

    final int totalQuestions = _statistics['totalQuestions'] ?? 0;

    final int totalQuizResults = _statistics['totalQuizResults'] ?? 0;

    return RefreshIndicator(
      color: const Color(0xFF364FC7),
      onRefresh: _loadDashboard,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: _buildDashboardBody(
                totalUsers: totalUsers,
                totalStudents: totalStudents,
                totalAdmins: totalAdmins,
                totalLessons: totalLessons,
                activeLessons: activeLessons,
                totalVocabularies: totalVocabularies,
                totalQuestions: totalQuestions,
                totalQuizResults: totalQuizResults,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Nội dung chính của dashboard (banner, thống kê, chức năng quản
  /// lý), tách riêng để bọc trong `ConstrainedBox` giới hạn chiều
  /// rộng tối đa — tránh các thẻ bị kéo giãn hết cỡ trên web/màn
  /// hình rộng.
  Widget _buildDashboardBody({
    required int totalUsers,
    required int totalStudents,
    required int totalAdmins,
    required int totalLessons,
    required int activeLessons,
    required int totalVocabularies,
    required int totalQuestions,
    required int totalQuizResults,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF364FC7), Color(0xFF5C7CFA)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF364FC7).withValues(alpha: 0.22),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Row(
            children: [
              Icon(
                Icons.admin_panel_settings_rounded,
                color: Colors.white,
                size: 54,
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Trang quản trị hệ thống',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 7),
                    Text(
                      'Quản lý bài học, từ vựng, câu hỏi, '
                      'tài khoản và hoạt động hệ thống.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        Text(
          'Tổng quan hệ thống',
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        _buildStatisticsGrid(
          totalUsers: totalUsers,
          totalStudents: totalStudents,
          totalAdmins: totalAdmins,
          totalLessons: totalLessons,
          activeLessons: activeLessons,
          totalVocabularies: totalVocabularies,
          totalQuestions: totalQuestions,
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            color: const Color(0xFF0C8599).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF0C8599).withValues(alpha: 0.16),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.assignment_turned_in_rounded,
                color: Color(0xFF0C8599),
                size: 31,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Tổng số lượt làm bài kiểm tra',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              Text(
                totalQuizResults.toString(),
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0C8599),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 30),
        Text(
          'Chức năng quản lý',
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          'Chọn nội dung cần quản lý.',
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 17),
        _buildManagementCard(
          icon: Icons.menu_book_rounded,
          title: 'Quản lý bài học',
          description: 'Thêm, sửa, xóa và thay đổi trạng thái bài học.',
          color: const Color(0xFF3B5BDB),
          onTap: _openLessonManagement,
        ),
        const SizedBox(height: 12),
        _buildManagementCard(
          icon: Icons.translate_rounded,
          title: 'Quản lý từ vựng',
          description: 'Thêm, sửa, xóa và quản lý từ vựng theo bài học.',
          color: const Color(0xFF9C36B5),
          onTap: _openVocabularyManagement,
        ),
        const SizedBox(height: 12),
        _buildManagementCard(
          icon: Icons.quiz_rounded,
          title: 'Quản lý câu hỏi',
          description: 'Thêm, sửa, xóa và chọn đáp án đúng cho câu hỏi.',
          color: const Color(0xFFF59F00),
          onTap: _openQuestionManagement,
        ),
        const SizedBox(height: 12),
        _buildManagementCard(
          icon: Icons.manage_accounts_rounded,
          title: 'Quản lý tài khoản',
          description: 'Xem, tìm kiếm, lọc và thiết lập quyền tài khoản.',
          color: const Color(0xFF0C8599),
          onTap: _openUserManagement,
        ),
        const SizedBox(height: 12),
        _buildManagementCard(
          icon: Icons.headphones_rounded,
          title: 'Quản lý luyện nghe & nói',
          description:
              'Thêm, sửa, xóa video luyện nghe và câu gợi ý luyện nói.',
          color: const Color(0xFF0C8599),
          onTap: _openListeningManagement,
        ),
        const SizedBox(height: 12),
        _buildManagementCard(
          icon: Icons.record_voice_over_rounded,
          title: 'Quản lý luyện Shadowing',
          description:
              'Thêm, sửa, xóa bài luyện Shadowing và từng câu bên trong.',
          color: const Color(0xFF7048E8),
          onTap: _openShadowingManagement,
        ),
        const SizedBox(height: 12),
        _buildManagementCard(
          icon: Icons.edit_note_rounded,
          title: 'Quản lý Luyện Viết AI',
          description: 'Thêm, sửa, xóa đề bài Writing Task 1/Task 2.',
          color: const Color(0xFFE8590C),
          onTap: _openWritingManagement,
        ),
        const SizedBox(height: 12),
        _buildManagementCard(
          icon: Icons.toggle_on_rounded,
          title: 'Quản lý tính năng',
          description: 'Tạm bật/tắt từng tính năng trên trang chủ học viên.',
          color: const Color(0xFF364FC7),
          onTap: _openFeatureFlagsManagement,
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
            const CircularProgressIndicator(color: Color(0xFF364FC7)),
            const SizedBox(height: 18),
            Text(
              'Đang tải dữ liệu quản trị...',
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
            const Icon(Icons.gpp_bad_rounded, size: 68, color: Colors.red),
            const SizedBox(height: 18),
            Text(
              'Không thể mở trang quản trị',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: _loadDashboard,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Kiểm tra lại'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF364FC7),
                foregroundColor: Colors.white,
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
        automaticallyImplyLeading: false,
        title: const Text(
          'Quản trị hệ thống',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF364FC7),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            onPressed: _isLoading ? null : _loadDashboard,
            icon: const Icon(Icons.refresh_rounded),
          ),
          if (_isLoggingOut)
            const Padding(
              padding: EdgeInsets.only(right: 18),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
              ),
            )
          else
            IconButton(
              tooltip: 'Đăng xuất',
              onPressed: _handleLogout,
              icon: const Icon(Icons.logout_rounded),
            ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? _buildLoadingView()
            : _errorMessage != null
            ? _buildErrorView(_errorMessage!)
            : _buildDashboardContent(),
      ),
    );
  }
}
