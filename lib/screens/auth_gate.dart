import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/admin_service.dart';
import '../services/auth_service.dart';
import 'admin/admin_dashboard_screen.dart';
import 'home_screen.dart';
import 'login_screen.dart';

/// Điều hướng người dùng dựa trên trạng thái đăng nhập và vai trò:
///
/// - Chưa đăng nhập: LoginScreen.
/// - role = student: HomeScreen.
/// - role = admin: AdminDashboardScreen.
/// - Đang kiểm tra: LoadingScreen.
/// - Có lỗi: AuthenticationErrorScreen.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService();

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (
        BuildContext context,
        AsyncSnapshot<User?> authSnapshot,
      ) {
        // Firebase đang kiểm tra trạng thái đăng nhập.
        if (authSnapshot.connectionState ==
            ConnectionState.waiting) {
          return const _LoadingScreen(
            message: 'Đang kiểm tra tài khoản...',
          );
        }

        // Có lỗi khi kiểm tra Firebase Authentication.
        if (authSnapshot.hasError) {
          return _AuthenticationErrorScreen(
            message:
                'Không thể kiểm tra trạng thái đăng nhập.\n'
                '${authSnapshot.error}',
          );
        }

        final User? user = authSnapshot.data;

        // Người dùng chưa đăng nhập.
        if (user == null) {
          return const LoginScreen();
        }

        // Người dùng đã đăng nhập.
        // Tiếp tục kiểm tra vai trò trong Firestore.
        return const _RoleGate();
      },
    );
  }
}

/// Kiểm tra trường role trong document users/{uid}.
class _RoleGate extends StatelessWidget {
  const _RoleGate();

  @override
  Widget build(BuildContext context) {
    final AdminService adminService = AdminService();

    return StreamBuilder<Map<String, dynamic>?>(
      stream: adminService.getCurrentUserProfile(),
      builder: (
        BuildContext context,
        AsyncSnapshot<Map<String, dynamic>?> profileSnapshot,
      ) {
        // Đang đọc thông tin tài khoản từ Firestore.
        if (profileSnapshot.connectionState ==
            ConnectionState.waiting) {
          return const _LoadingScreen(
            message: 'Đang kiểm tra quyền tài khoản...',
          );
        }

        // Có lỗi khi đọc document người dùng.
        if (profileSnapshot.hasError) {
          return _AuthenticationErrorScreen(
            message:
                'Không thể tải thông tin tài khoản.\n'
                '${profileSnapshot.error}',
          );
        }

        final Map<String, dynamic>? profile =
            profileSnapshot.data;

        // Không tìm thấy document người dùng.
        if (profile == null) {
          return const _MissingProfileScreen();
        }

        final String role = profile['role']
                ?.toString()
                .trim()
                .toLowerCase() ??
            'student';

        switch (role) {
          case 'admin':
            return const AdminDashboardScreen();

          case 'student':
            return const HomeScreen();

          default:
            return _InvalidRoleScreen(
              role: role,
            );
        }
      },
    );
  }
}

/// Màn hình chờ khi kiểm tra đăng nhập hoặc phân quyền.
class _LoadingScreen extends StatelessWidget {
  final String message;

  const _LoadingScreen({
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 84,
                  height: 84,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B5BDB),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF3B5BDB)
                            .withValues(alpha: 0.22),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.school_rounded,
                    color: Colors.white,
                    size: 45,
                  ),
                ),
                const SizedBox(height: 26),
                const CircularProgressIndicator(
                  color: Color(0xFF3B5BDB),
                ),
                const SizedBox(height: 18),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Màn hình hiển thị khi xảy ra lỗi xác thực hoặc Firestore.
class _AuthenticationErrorScreen extends StatelessWidget {
  final String message;

  const _AuthenticationErrorScreen({
    required this.message,
  });

  Future<void> _logout(
    BuildContext context,
  ) async {
    try {
      await AuthService().logout();
    } catch (_) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Không thể đăng xuất. Vui lòng thử lại.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: Colors.red,
                  size: 68,
                ),
                const SizedBox(height: 18),
                Text(
                  'Không thể xác thực tài khoản',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 11),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () {
                    _logout(context);
                  },
                  icon: const Icon(
                    Icons.logout_rounded,
                  ),
                  label: const Text(
                    'Đăng xuất và thử lại',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        const Color(0xFF3B5BDB),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Màn hình hiển thị khi Authentication có tài khoản
/// nhưng Firestore chưa có document users/{uid}.
class _MissingProfileScreen extends StatefulWidget {
  const _MissingProfileScreen();

  @override
  State<_MissingProfileScreen> createState() =>
      _MissingProfileScreenState();
}

class _MissingProfileScreenState
    extends State<_MissingProfileScreen> {
  bool _isCreatingProfile = false;
  bool _isLoggingOut = false;

  Future<void> _createStudentProfile() async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null || _isCreatingProfile) {
      return;
    }

    setState(() {
      _isCreatingProfile = true;
    });

    try {
      await AdminService()
          .getCurrentUserProfileOnce();

      await FirebaseAuth.instance.currentUser
          ?.reload();

      if (!mounted) {
        return;
      }

      setState(() {
        _isCreatingProfile = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Không tìm thấy hồ sơ. Hãy đăng xuất và đăng ký lại tài khoản.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isCreatingProfile = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Không thể kiểm tra hồ sơ: $error',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _logout() async {
    if (_isLoggingOut) {
      return;
    }

    setState(() {
      _isLoggingOut = true;
    });

    try {
      await AuthService().logout();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoggingOut = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Không thể đăng xuất: $error',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final User? user =
        FirebaseAuth.instance.currentUser;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.person_off_outlined,
                  color: Colors.orange,
                  size: 68,
                ),
                const SizedBox(height: 18),
                Text(
                  'Chưa có hồ sơ người dùng',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 11),
                Text(
                  'Tài khoản ${user?.email ?? ''} đã đăng nhập '
                  'nhưng chưa có document tương ứng trong '
                  'collection users.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _isCreatingProfile
                      ? null
                      : _createStudentProfile,
                  icon: _isCreatingProfile
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child:
                              CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(
                          Icons.refresh_rounded,
                        ),
                  label: Text(
                    _isCreatingProfile
                        ? 'Đang kiểm tra...'
                        : 'Kiểm tra lại',
                  ),
                ),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed:
                      _isLoggingOut ? null : _logout,
                  icon: _isLoggingOut
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(
                          Icons.logout_rounded,
                        ),
                  label: const Text('Đăng xuất'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Màn hình hiển thị khi role không phải student hoặc admin.
class _InvalidRoleScreen extends StatelessWidget {
  final String role;

  const _InvalidRoleScreen({
    required this.role,
  });

  Future<void> _logout() async {
    await AuthService().logout();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.security_rounded,
                  color: Colors.red,
                  size: 68,
                ),
                const SizedBox(height: 18),
                Text(
                  'Vai trò tài khoản không hợp lệ',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 11),
                Text(
                  role.isEmpty
                      ? 'Tài khoản chưa được thiết lập vai trò.'
                      : 'Vai trò "$role" không được hệ thống hỗ trợ.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _logout,
                  icon: const Icon(
                    Icons.logout_rounded,
                  ),
                  label: const Text('Đăng xuất'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}