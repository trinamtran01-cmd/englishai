import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/admin_service.dart';

class AdminUserScreen extends StatefulWidget {
  const AdminUserScreen({super.key});

  @override
  State<AdminUserScreen> createState() =>
      _AdminUserScreenState();
}

class _AdminUserScreenState
    extends State<AdminUserScreen> {
  final AdminService _adminService = AdminService();

  final TextEditingController _searchController =
      TextEditingController();

  String _selectedRoleFilter = 'all';
  String _searchKeyword = '';
  String? _processingUserId;

  @override
  void initState() {
    super.initState();

    _searchController.addListener(
      _handleSearchChanged,
    );
  }

  @override
  void dispose() {
    _searchController.removeListener(
      _handleSearchChanged,
    );

    _searchController.dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    final String keyword =
        _searchController.text.trim().toLowerCase();

    if (keyword == _searchKeyword) {
      return;
    }

    setState(() {
      _searchKeyword = keyword;
    });
  }

  String _getUserRole(
    Map<String, dynamic> user,
  ) {
    final String role =
        user['role']?.toString().trim().toLowerCase() ??
            'student';

    return role == 'admin' ? 'admin' : 'student';
  }

  String _getUserName(
    Map<String, dynamic> user,
  ) {
    final String name =
        user['name']?.toString().trim() ?? '';

    return name.isEmpty ? 'Chưa cập nhật tên' : name;
  }

  String _getUserEmail(
    Map<String, dynamic> user,
  ) {
    final String email =
        user['email']?.toString().trim() ?? '';

    return email.isEmpty ? 'Chưa có email' : email;
  }

  String _getAvatarLetter(
    Map<String, dynamic> user,
  ) {
    final String name = _getUserName(user);

    if (name.isNotEmpty &&
        name != 'Chưa cập nhật tên') {
      return name.substring(0, 1).toUpperCase();
    }

    final String email = _getUserEmail(user);

    if (email.isNotEmpty &&
        email != 'Chưa có email') {
      return email.substring(0, 1).toUpperCase();
    }

    return 'U';
  }

  List<Map<String, dynamic>> _filterUsers(
    List<Map<String, dynamic>> users,
  ) {
    final List<Map<String, dynamic>> filteredUsers =
        users.where(
      (Map<String, dynamic> user) {
        final String role = _getUserRole(user);
        final String name =
            _getUserName(user).toLowerCase();
        final String email =
            _getUserEmail(user).toLowerCase();

        final bool matchesRole =
            _selectedRoleFilter == 'all' ||
                role == _selectedRoleFilter;

        final bool matchesSearch =
            _searchKeyword.isEmpty ||
                name.contains(_searchKeyword) ||
                email.contains(_searchKeyword);

        return matchesRole && matchesSearch;
      },
    ).toList();

    filteredUsers.sort(
      (
        Map<String, dynamic> firstUser,
        Map<String, dynamic> secondUser,
      ) {
        final String firstName =
            _getUserName(firstUser).toLowerCase();

        final String secondName =
            _getUserName(secondUser).toLowerCase();

        return firstName.compareTo(secondName);
      },
    );

    return filteredUsers;
  }

  Future<void> _changeUserRole({
    required Map<String, dynamic> user,
    required String newRole,
  }) async {
    final String userId =
        user['id']?.toString().trim() ?? '';

    if (userId.isEmpty ||
        _processingUserId != null) {
      return;
    }

    final String currentUserId =
        FirebaseAuth.instance.currentUser?.uid ?? '';

    if (userId == currentUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Bạn không thể tự thay đổi quyền của chính mình.',
          ),
          backgroundColor: Colors.orange,
        ),
      );

      return;
    }

    final String currentRole = _getUserRole(user);

    if (currentRole == newRole) {
      return;
    }

    final String name = _getUserName(user);
    final String roleLabel =
        newRole == 'admin'
            ? 'Quản trị viên'
            : 'Học viên';

    final bool? shouldChange =
        await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          icon: Icon(
            newRole == 'admin'
                ? Icons.admin_panel_settings_rounded
                : Icons.school_rounded,
            color: newRole == 'admin'
                ? const Color(0xFF364FC7)
                : const Color(0xFF2F9E44),
            size: 48,
          ),
          title: const Text(
            'Thay đổi quyền tài khoản?',
            textAlign: TextAlign.center,
          ),
          content: Text(
            'Bạn có chắc chắn muốn đặt tài khoản '
            '"$name" thành "$roleLabel" không?',
            textAlign: TextAlign.center,
          ),
          actionsAlignment:
              MainAxisAlignment.center,
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
                backgroundColor:
                    const Color(0xFF364FC7),
                foregroundColor: Colors.white,
              ),
              child: const Text('Xác nhận'),
            ),
          ],
        );
      },
    );

    if (shouldChange != true || !mounted) {
      return;
    }

    setState(() {
      _processingUserId = userId;
    });

    try {
      await _adminService.updateUserRole(
        userId: userId,
        role: newRole,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _processingUserId = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Đã đặt tài khoản "$name" thành $roleLabel.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _processingUserId = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Không thể thay đổi quyền tài khoản: $error',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildSummarySection(
    List<Map<String, dynamic>> users,
  ) {
    final int totalAdmins = users.where(
      (Map<String, dynamic> user) {
        return _getUserRole(user) == 'admin';
      },
    ).length;

    final int totalStudents =
        users.length - totalAdmins;

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0xFF0C8599)
            .withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: const Color(0xFF0C8599)
              .withValues(alpha: 0.16),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryItem(
              icon: Icons.people_alt_rounded,
              value: users.length.toString(),
              label: 'Tổng tài khoản',
              color: const Color(0xFF0C8599),
            ),
          ),
          Container(
            width: 1,
            height: 54,
            color: const Color(0xFFE1E5F2),
          ),
          Expanded(
            child: _buildSummaryItem(
              icon: Icons.school_rounded,
              value: totalStudents.toString(),
              label: 'Học viên',
              color: const Color(0xFF2F9E44),
            ),
          ),
          Container(
            width: 1,
            height: 54,
            color: const Color(0xFFE1E5F2),
          ),
          Expanded(
            child: _buildSummaryItem(
              icon:
                  Icons.admin_panel_settings_rounded,
              value: totalAdmins.toString(),
              label: 'Quản trị',
              color: const Color(0xFF364FC7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(
          icon,
          color: color,
          size: 24,
        ),
        const SizedBox(height: 7),
        Text(
          value,
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchAndFilter() {
    return Column(
      children: [
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            labelText: 'Tìm kiếm tài khoản',
            hintText: 'Nhập họ tên hoặc email',
            prefixIcon: const Icon(
              Icons.search_rounded,
            ),
            suffixIcon: _searchKeyword.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Xóa tìm kiếm',
                    onPressed: () {
                      _searchController.clear();
                    },
                    icon: const Icon(
                      Icons.clear_rounded,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _selectedRoleFilter,
          decoration: const InputDecoration(
            labelText: 'Lọc theo vai trò',
            prefixIcon: Icon(
              Icons.filter_list_rounded,
            ),
          ),
          items: const [
            DropdownMenuItem<String>(
              value: 'all',
              child: Text('Tất cả tài khoản'),
            ),
            DropdownMenuItem<String>(
              value: 'student',
              child: Text('Học viên'),
            ),
            DropdownMenuItem<String>(
              value: 'admin',
              child: Text('Quản trị viên'),
            ),
          ],
          onChanged: (String? value) {
            if (value == null) {
              return;
            }

            setState(() {
              _selectedRoleFilter = value;
            });
          },
        ),
      ],
    );
  }

  Widget _buildUserCard(
    Map<String, dynamic> user,
  ) {
    final String userId =
        user['id']?.toString().trim() ?? '';

    final String currentUserId =
        FirebaseAuth.instance.currentUser?.uid ?? '';

    final String name = _getUserName(user);
    final String email = _getUserEmail(user);
    final String role = _getUserRole(user);

    final bool isAdmin = role == 'admin';
    final bool isCurrentUser =
        userId == currentUserId;

    final bool isProcessing =
        _processingUserId == userId;

    final Color roleColor = isAdmin
        ? const Color(0xFF364FC7)
        : const Color(0xFF2F9E44);

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: isCurrentUser
              ? const Color(0xFF364FC7)
              : const Color(0xFFE8EAF2),
          width: isCurrentUser ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: roleColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Text(
                _getAvatarLetter(user),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: roleColor,
                ),
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
                      Flexible(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow:
                              TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A2E),
                          ),
                        ),
                      ),
                      if (isCurrentUser) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding:
                              const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF364FC7)
                                .withValues(alpha: 0.11),
                            borderRadius:
                                BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Bạn',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF364FC7),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color:
                          roleColor.withValues(alpha: 0.10),
                      borderRadius:
                          BorderRadius.circular(20),
                    ),
                    child: Text(
                      isAdmin
                          ? 'Quản trị viên'
                          : 'Học viên',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: roleColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (isProcessing)
              SizedBox(
                width: 23,
                height: 23,
                child: CircularProgressIndicator(
                  color: roleColor,
                  strokeWidth: 2,
                ),
              )
            else
              PopupMenuButton<String>(
                tooltip: isCurrentUser
                    ? 'Không thể tự đổi quyền'
                    : 'Thay đổi quyền',
                enabled: !isCurrentUser &&
                    _processingUserId == null,
                onSelected: (String value) {
                  _changeUserRole(
                    user: user,
                    newRole: value,
                  );
                },
                itemBuilder: (
                  BuildContext context,
                ) {
                  return [
                    PopupMenuItem<String>(
                      value: 'student',
                      enabled: role != 'student',
                      child: const Row(
                        children: [
                          Icon(
                            Icons.school_rounded,
                            color: Color(0xFF2F9E44),
                          ),
                          SizedBox(width: 10),
                          Text('Đặt làm học viên'),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'admin',
                      enabled: role != 'admin',
                      child: const Row(
                        children: [
                          Icon(
                            Icons
                                .admin_panel_settings_rounded,
                            color: Color(0xFF364FC7),
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Đặt làm quản trị viên',
                          ),
                        ],
                      ),
                    ),
                  ];
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingView() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              color: Color(0xFF0C8599),
            ),
            SizedBox(height: 18),
            Text(
              'Đang tải danh sách tài khoản...',
              style: TextStyle(
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView(Object error) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 68,
              color: Colors.red,
            ),
            const SizedBox(height: 18),
            const Text(
              'Không thể tải tài khoản',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                height: 1.5,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView({
    required bool isFiltered,
  }) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.person_search_rounded,
              size: 68,
              color: Color(0xFF0C8599),
            ),
            const SizedBox(height: 18),
            Text(
              isFiltered
                  ? 'Không tìm thấy tài khoản'
                  : 'Chưa có tài khoản',
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              isFiltered
                  ? 'Hãy thay đổi từ khóa hoặc bộ lọc.'
                  : 'Danh sách tài khoản hiện đang trống.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            if (isFiltered) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () {
                  _searchController.clear();

                  setState(() {
                    _selectedRoleFilter = 'all';
                  });
                },
                icon: const Icon(
                  Icons.filter_alt_off_rounded,
                ),
                label: const Text('Xóa bộ lọc'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUserList(
    List<Map<String, dynamic>> allUsers,
  ) {
    final List<Map<String, dynamic>> filteredUsers =
        _filterUsers(allUsers);

    final bool isFiltered =
        _searchKeyword.isNotEmpty ||
            _selectedRoleFilter != 'all';

    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(
            16,
            16,
            16,
            18,
          ),
          child: Column(
            children: [
              _buildSummarySection(allUsers),
              const SizedBox(height: 16),
              _buildSearchAndFilter(),
            ],
          ),
        ),
        Expanded(
          child: filteredUsers.isEmpty
              ? _buildEmptyView(
                  isFiltered: isFiltered,
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    20,
                    20,
                    20,
                    32,
                  ),
                  itemCount: filteredUsers.length,
                  itemBuilder: (
                    BuildContext context,
                    int index,
                  ) {
                    return _buildUserCard(
                      filteredUsers[index],
                    );
                  },
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FF),
      appBar: AppBar(
        title: const Text(
          'Quản lý tài khoản',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF0C8599),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: StreamBuilder<bool>(
          stream:
              _adminService.isCurrentUserAdminStream,
          builder: (
            BuildContext context,
            AsyncSnapshot<bool> adminSnapshot,
          ) {
            if (adminSnapshot.connectionState ==
                    ConnectionState.waiting &&
                !adminSnapshot.hasData) {
              return _buildLoadingView();
            }

            if (adminSnapshot.hasError) {
              return _buildErrorView(
                adminSnapshot.error!,
              );
            }

            if (adminSnapshot.data != true) {
              return _buildErrorView(
                StateError(
                  'Tài khoản hiện tại không có quyền quản trị.',
                ),
              );
            }

            return StreamBuilder<
                List<Map<String, dynamic>>>(
              stream: _adminService.getUsersStream(),
              builder: (
                BuildContext context,
                AsyncSnapshot<
                        List<Map<String, dynamic>>>
                    userSnapshot,
              ) {
                if (userSnapshot.connectionState ==
                        ConnectionState.waiting &&
                    !userSnapshot.hasData) {
                  return _buildLoadingView();
                }

                if (userSnapshot.hasError) {
                  return _buildErrorView(
                    userSnapshot.error!,
                  );
                }

                final List<Map<String, dynamic>> users =
                    userSnapshot.data ??
                        <Map<String, dynamic>>[];

                return _buildUserList(users);
              },
            );
          },
        ),
      ),
    );
  }
}