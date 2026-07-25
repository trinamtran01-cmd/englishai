import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/auth_gate.dart';

Future<void> main() async {
  // Đảm bảo Flutter đã khởi tạo đầy đủ trước khi gọi Firebase.
  WidgetsFlutterBinding.ensureInitialized();

  // Khởi tạo Firebase bằng cấu hình do FlutterFire CLI tạo.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const EnglishAiApp());
}

class EnglishAiApp extends StatelessWidget {
  const EnglishAiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'English AI',

      // Tắt biểu tượng DEBUG ở góc phải màn hình.
      debugShowCheckedModeBanner: false,

      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3B5BDB),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F7FF),

        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
        ),

        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3B5BDB),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 15,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),

        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF3B5BDB),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 15,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),

        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
        ),
      ),

      // AuthGate tự quyết định hiển thị LoginScreen hoặc HomeScreen.
      home: const AuthGate(),
    );
  }
}