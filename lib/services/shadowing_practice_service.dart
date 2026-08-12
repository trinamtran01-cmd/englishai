import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/shadowing_attempt.dart';

/// Chấm điểm 1 lần luyện nhại câu (shadowing): gửi audio người dùng
/// vừa ghi âm lên Gemini API để lấy transcript, so khớp với câu gốc
/// theo từng từ, rồi lưu kết quả vào Firestore.
///
/// Nhận trực tiếp [Uint8List] + mimeType (không dùng `dart:io` File)
/// để hoạt động được trên cả mobile lẫn web: trên web không có hệ
/// thống file cục bộ, nên màn hình gọi dịch vụ này phải tự đọc dữ
/// liệu ghi âm ra bytes trước (từ File trên mobile, từ Blob trên
/// web) rồi truyền vào đây.
///
/// Cách gọi Gemini API (input audio, đọc .env, parse JSON) tái sử
/// dụng đúng theo AiSpeakingFeedbackService.
///
/// Collection sử dụng: shadowing_attempts
class ShadowingPracticeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const String _model = 'gemini-3.5-flash-lite';

  static const Duration _requestTimeout = Duration(seconds: 45);

  CollectionReference<Map<String, dynamic>>
      get _attemptsCollection {
    return _firestore.collection('shadowing_attempts');
  }

  /// Lấy tài khoản hiện đang đăng nhập.
  User _requireCurrentUser() {
    final User? user = _auth.currentUser;

    if (user == null) {
      throw StateError(
        'Bạn cần đăng nhập để luyện Shadowing.',
      );
    }

    return user;
  }

  /// Lấy API key Gemini từ file .env.
  String _requireApiKey() {
    final String apiKey =
        dotenv.env['GEMINI_API_KEY']?.trim() ?? '';

    if (apiKey.isEmpty) {
      throw Exception(
        'Chưa thiết lập GEMINI_API_KEY trong file .env. '
        'Vui lòng thêm API key trước khi sử dụng tính năng này.',
      );
    }

    return apiKey;
  }

  /// Gửi audio ghi âm lên Gemini, so khớp với câu gốc và lưu kết quả.
  ///
  /// [audioBytes] là dữ liệu ghi âm đã đọc sẵn thành bytes (mobile:
  /// đọc từ File; web: đọc từ Blob), [mimeType] mô tả định dạng
  /// tương ứng (ví dụ `audio/aac` trên mobile, `audio/wav` trên web).
  ///
  /// [expectedText] là câu người dùng được yêu cầu nhại lại.
  ///
  /// Trả về đối tượng ShadowingAttempt vừa được lưu.
  Future<ShadowingAttempt> submitAttempt(
    String segmentId,
    String lessonId,
    Uint8List audioBytes,
    String mimeType,
    String expectedText,
  ) async {
    final User user = _requireCurrentUser();
    final String apiKey = _requireApiKey();

    final String cleanSegmentId = segmentId.trim();
    final String cleanLessonId = lessonId.trim();

    if (cleanSegmentId.isEmpty || cleanLessonId.isEmpty) {
      throw ArgumentError(
        'ID câu và ID bài luyện Shadowing không được để trống.',
      );
    }

    final String transcript = await _callGeminiAudio(
      audioBytes: audioBytes,
      mimeType: mimeType,
      expectedText: expectedText,
      apiKey: apiKey,
    );

    final List<Map<String, dynamic>> wordResults = _buildWordResults(
      expectedText: expectedText,
      transcript: transcript,
    );

    final int correctCount = wordResults
        .where((Map<String, dynamic> item) => item['isCorrect'] == true)
        .length;

    final double accuracyPercent = wordResults.isEmpty
        ? 0
        : (correctCount / wordResults.length) * 100;

    final ShadowingAttempt attempt = ShadowingAttempt(
      id: '',
      userId: user.uid,
      segmentId: cleanSegmentId,
      lessonId: cleanLessonId,
      transcriptFromAudio: transcript,
      wordResults: wordResults,
      accuracyPercent: accuracyPercent,
      createdAt: DateTime.now(),
    );

    try {
      final DocumentReference<Map<String, dynamic>> document =
          await _attemptsCollection.add(attempt.toMap());

      final DocumentSnapshot<Map<String, dynamic>>
          savedDocument = await document.get();

      return ShadowingAttempt.fromFirestore(savedDocument);
    } on FirebaseException catch (error) {
      throw Exception(
        'Không thể lưu kết quả luyện Shadowing: ${error.code}',
      );
    }
  }

  /// So khớp từng từ giữa câu gốc và transcript, chuẩn hóa lowercase
  /// và bỏ dấu câu trước khi so sánh.
  ///
  /// Giữ nguyên thứ tự và cách viết gốc của từ trong [expectedText]
  /// để hiển thị chip, chỉ dùng bản chuẩn hóa để so khớp đúng/sai.
  List<Map<String, dynamic>> _buildWordResults({
    required String expectedText,
    required String transcript,
  }) {
    final List<String> expectedWords =
        _extractWords(expectedText);

    final Set<String> transcriptWords =
        _extractWords(transcript).map(_normalizeWord).toSet();

    return expectedWords.map((String word) {
      final bool isCorrect =
          transcriptWords.contains(_normalizeWord(word));

      return <String, dynamic>{
        'word': word,
        'isCorrect': isCorrect,
      };
    }).toList();
  }

  List<String> _extractWords(String text) {
    return RegExp(r"[a-zA-Z']+")
        .allMatches(text)
        .map((RegExpMatch match) => match.group(0) ?? '')
        .where((String word) => word.isNotEmpty)
        .toList();
  }

  String _normalizeWord(String word) {
    return word.trim().toLowerCase();
  }

  /// Gọi Gemini API với input audio, trả về transcript đã phiên âm.
  Future<String> _callGeminiAudio({
    required Uint8List audioBytes,
    required String mimeType,
    required String expectedText,
    required String apiKey,
  }) async {
    final String base64Audio = base64Encode(audioBytes);

    final Uri endpoint = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/'
      '$_model:generateContent?key=$apiKey',
    );

    final Map<String, dynamic> requestBody = {
      'contents': [
        {
          'parts': [
            {'text': _buildPrompt(expectedText)},
            {
              'inline_data': {
                'mime_type': mimeType,
                'data': base64Audio,
              },
            },
          ],
        },
      ],
    };

    http.Response response;

    try {
      response = await http
          .post(
            endpoint,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(_requestTimeout);
    } on SocketException {
      throw Exception(
        'Không có kết nối mạng, vui lòng kiểm tra lại '
        'đường truyền và thử lại.',
      );
    } on TimeoutException {
      throw Exception(
        'Kết nối tới AI quá lâu, vui lòng thử lại sau.',
      );
    } on HttpException {
      throw Exception(
        'Không thể kết nối tới máy chủ AI, vui lòng thử lại.',
      );
    }

    if (response.statusCode == 401 ||
        response.statusCode == 403) {
      throw Exception(
        'API key Gemini không hợp lệ hoặc đã bị từ chối. '
        'Vui lòng kiểm tra lại GEMINI_API_KEY trong file .env.',
      );
    }

    if (response.statusCode == 429) {
      throw Exception(
        'Đã vượt quá giới hạn sử dụng Gemini API (quota). '
        'Vui lòng thử lại sau.',
      );
    }

    if (response.statusCode != 200) {
      throw Exception(
        'Gemini API trả về lỗi (mã ${response.statusCode}). '
        'Vui lòng thử lại sau.',
      );
    }

    final String rawText = _extractTextFromResponse(
      response.body,
    );

    final Map<String, dynamic> parsed = _parseJson(rawText);

    return parsed['transcript'] as String? ?? '';
  }

  /// Nội dung prompt yêu cầu Gemini trả về đúng cấu trúc JSON.
  String _buildPrompt(String expectedText) {
    final String cleanExpectedText = expectedText.trim();

    return 'Học viên đang luyện "shadowing" (nghe rồi nhại lại), '
        'được yêu cầu nhại lại đúng câu tiếng Anh sau:\n'
        '"$cleanExpectedText"\n\n'
        'Hãy nghe file audio đính kèm và phiên âm lại chính xác '
        'từng từ những gì học viên đã nói (kể cả khi phát âm chưa '
        'chuẩn, vẫn phiên âm theo từ tiếng Anh gần đúng nhất mà '
        'bạn nghe được), rồi trả về DUY NHẤT một đối tượng JSON '
        'thuần túy, không dùng markdown, không code fence, không '
        'giải thích thêm, theo đúng cấu trúc sau: '
        '{"transcript": "phiên âm lại đúng những gì nghe được từ '
        'audio"}. '
        'Nếu không nghe rõ được nội dung audio, hãy trả về '
        '{"transcript": ""}.';
  }

  /// Trích nội dung text từ response JSON của Gemini.
  String _extractTextFromResponse(String responseBody) {
    try {
      final Map<String, dynamic> decoded =
          jsonDecode(responseBody) as Map<String, dynamic>;

      final List<dynamic>? candidates =
          decoded['candidates'] as List<dynamic>?;

      if (candidates == null || candidates.isEmpty) {
        throw Exception(
          'AI không phân tích được đoạn ghi âm, '
          'vui lòng thử ghi âm lại.',
        );
      }

      final Map<String, dynamic> firstCandidate =
          candidates.first as Map<String, dynamic>;

      final Map<String, dynamic>? content =
          firstCandidate['content'] as Map<String, dynamic>?;

      final List<dynamic>? parts =
          content?['parts'] as List<dynamic>?;

      if (parts == null || parts.isEmpty) {
        throw Exception(
          'AI không phân tích được đoạn ghi âm, '
          'vui lòng thử ghi âm lại.',
        );
      }

      final String text =
          (parts.first as Map<String, dynamic>)['text']
                  as String? ??
              '';

      if (text.trim().isEmpty) {
        throw Exception(
          'AI không phân tích được đoạn ghi âm, '
          'vui lòng thử ghi âm lại.',
        );
      }

      return text;
    } on FormatException {
      throw Exception(
        'Không thể đọc phản hồi từ AI, vui lòng thử lại.',
      );
    }
  }

  /// Bóc tách JSON từ chuỗi text, loại bỏ code fence nếu có.
  Map<String, dynamic> _parseJson(String rawText) {
    String cleanText = rawText.trim();

    if (cleanText.startsWith('```')) {
      cleanText = cleanText
          .replaceFirst(RegExp(r'^```(json)?'), '')
          .trim();

      if (cleanText.endsWith('```')) {
        cleanText = cleanText
            .substring(0, cleanText.length - 3)
            .trim();
      }
    }

    try {
      return jsonDecode(cleanText) as Map<String, dynamic>;
    } on FormatException {
      throw Exception(
        'Không thể đọc kết quả phân tích từ AI, '
        'vui lòng thử ghi âm lại.',
      );
    }
  }
}
