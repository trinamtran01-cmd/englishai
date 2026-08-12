import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'firebase_options.dart';
import 'screens/auth_gate.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  // Đảm bảo Flutter đã khởi tạo đầy đủ trước khi gọi Firebase.
  WidgetsFlutterBinding.ensureInitialized();

  // Nạp file .env chứa GEMINI_API_KEY trước khi chạy ứng dụng.
  await dotenv.load(fileName: '.env');

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

      theme: AppTheme.darkTheme,

      // AuthGate tự quyết định hiển thị LoginScreen hoặc HomeScreen.
      home: const AuthGate(),
    );
  }
}