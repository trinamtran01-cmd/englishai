import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  final AuthService _authService = AuthService();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final String? error = await _authService.register(
      name: _nameController.text,
      email: _emailController.text,
      password: _passwordController.text,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = false;
    });

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đăng ký tài khoản thành công!'),
        backgroundColor: Colors.green,
      ),
    );

    Navigator.of(context).pop();
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Color(0xFFE1E5F2),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Color(0xFF3B5BDB),
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Colors.red,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Colors.red,
          width: 2,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FF),
      appBar: AppBar(
        title: const Text(
          'Đăng ký tài khoản',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFFF5F7FF),
        foregroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior:
              ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(28, 20, 28, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 76,
                    height: 76,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B5BDB),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF3B5BDB)
                              .withValues(alpha: 0.25),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.person_add_alt_1_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                const Text(
                  'Tạo tài khoản mới',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 7),
                const Text(
                  'Bắt đầu hành trình học tiếng Anh cùng AI',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 30),

                // Họ và tên
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  enabled: !_isLoading,
                  decoration: _inputDecoration(
                    label: 'Họ và tên',
                    icon: Icons.person_outline_rounded,
                  ),
                  validator: (value) {
                    final String name = value?.trim() ?? '';

                    if (name.isEmpty) {
                      return 'Vui lòng nhập họ và tên';
                    }

                    if (name.length < 2) {
                      return 'Họ và tên không hợp lệ';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Email
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  enabled: !_isLoading,
                  decoration: _inputDecoration(
                    label: 'Email',
                    icon: Icons.email_outlined,
                  ),
                  validator: (value) {
                    final String email = value?.trim() ?? '';

                    if (email.isEmpty) {
                      return 'Vui lòng nhập email';
                    }

                    final RegExp emailPattern = RegExp(
                      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                    );

                    if (!emailPattern.hasMatch(email)) {
                      return 'Địa chỉ email không hợp lệ';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Mật khẩu
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.next,
                  enableSuggestions: false,
                  autocorrect: false,
                  enabled: !_isLoading,
                  decoration: _inputDecoration(
                    label: 'Mật khẩu',
                    icon: Icons.lock_outline_rounded,
                    suffixIcon: IconButton(
                      tooltip: _obscurePassword
                          ? 'Hiện mật khẩu'
                          : 'Ẩn mật khẩu',
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      onPressed: _isLoading
                          ? null
                          : () {
                              setState(() {
                                _obscurePassword =
                                    !_obscurePassword;
                              });
                            },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Vui lòng nhập mật khẩu';
                    }

                    if (value.length < 6) {
                      return 'Mật khẩu cần có ít nhất 6 ký tự';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Nhập lại mật khẩu
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  textInputAction: TextInputAction.done,
                  enableSuggestions: false,
                  autocorrect: false,
                  enabled: !_isLoading,
                  onFieldSubmitted: (_) {
                    if (!_isLoading) {
                      _handleRegister();
                    }
                  },
                  decoration: _inputDecoration(
                    label: 'Nhập lại mật khẩu',
                    icon: Icons.lock_reset_rounded,
                    suffixIcon: IconButton(
                      tooltip: _obscureConfirmPassword
                          ? 'Hiện mật khẩu'
                          : 'Ẩn mật khẩu',
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      onPressed: _isLoading
                          ? null
                          : () {
                              setState(() {
                                _obscureConfirmPassword =
                                    !_obscureConfirmPassword;
                              });
                            },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Vui lòng nhập lại mật khẩu';
                    }

                    if (value != _passwordController.text) {
                      return 'Hai mật khẩu không giống nhau';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Nút đăng ký
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleRegister,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B5BDB),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        const Color(0xFF3B5BDB)
                            .withValues(alpha: 0.6),
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                    ),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 21,
                          height: 21,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Đăng ký',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
                const SizedBox(height: 16),

                // Quay lại đăng nhập
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Đã có tài khoản?'),
                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                              Navigator.of(context).pop();
                            },
                      child: const Text(
                        'Đăng nhập',
                        style: TextStyle(
                          color: Color(0xFF3B5BDB),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}