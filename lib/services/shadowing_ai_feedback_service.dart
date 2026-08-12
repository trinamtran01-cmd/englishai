import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/shadowing_ai_feedback.dart';

/// "AI Pronunciation Coach": phân tích khác biệt giữa câu gốc và
/// transcript người dùng đã nói, đưa ra nhận xét phát âm chi tiết
/// bằng tiếng Việt, giọng văn khích lệ.
///
/// Cách gọi Gemini API (text, đọc .env, parse JSON) tái sử dụng
/// đúng theo AiSpeakingFeedbackService, chỉ khác là input text
/// (transcript có sẵn) thay vì audio.
///
/// Collection sử dụng: shadowing_ai_feedbacks
class ShadowingAiFeedbackService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const String _model = 'gemini-3.5-flash-lite';

  static const Duration _requestTimeout = Duration(seconds: 45);

  CollectionReference<Map<String, dynamic>>
      get _feedbacksCollection {
    return _firestore.collection('shadowing_ai_feedbacks');
  }

  /// Lấy tài khoản hiện đang đăng nhập.
  User _requireCurrentUser() {
    final User? user = _auth.currentUser;

    if (user == null) {
      throw StateError(
        'Bạn cần đăng nhập để nhận xét phát âm từ AI.',
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

  /// Yêu cầu Gemini phân tích phát âm và lưu kết quả vào Firestore.
  Future<ShadowingAiFeedback> getFeedback(
    String segmentId,
    String expectedText,
    String userTranscript,
  ) async {
    final User user = _requireCurrentUser();
    final String apiKey = _requireApiKey();

    final String cleanSegmentId = segmentId.trim();

    if (cleanSegmentId.isEmpty) {
      throw ArgumentError('ID câu không được để trống.');
    }

    final Map<String, dynamic> analyzedData = await _callGeminiText(
      expectedText: expectedText,
      userTranscript: userTranscript,
      apiKey: apiKey,
    );

    final ShadowingAiFeedback feedback = ShadowingAiFeedback(
      id: '',
      userId: user.uid,
      segmentId: cleanSegmentId,
      overallAssessment:
          analyzedData['overallAssessment'] as String? ?? '',
      strengths: _parseStringList(analyzedData['strengths']),
      improvements: _parseStringList(
        analyzedData['improvements'],
      ),
      practiceTips: _parseStringList(
        analyzedData['practiceTips'],
      ),
      createdAt: DateTime.now(),
    );

    try {
      final DocumentReference<Map<String, dynamic>> document =
          await _feedbacksCollection.add(feedback.toMap());

      final DocumentSnapshot<Map<String, dynamic>>
          savedDocument = await document.get();

      return ShadowingAiFeedback.fromFirestore(savedDocument);
    } on FirebaseException catch (error) {
      throw Exception(
        'Không thể lưu nhận xét từ AI: ${error.code}',
      );
    }
  }

  /// Dịch nhanh 1 câu tiếng Anh sang tiếng Việt bằng Gemini.
  ///
  /// Dùng cho nút "Dịch bằng AI" khi câu chưa có sẵn
  /// `vietnameseTranslation`. Kết quả chỉ hiển thị tạm thời trên
  /// UI, không lưu vào Firestore.
  Future<String> quickTranslate(String englishText) async {
    _requireCurrentUser();
    final String apiKey = _requireApiKey();

    final String cleanText = englishText.trim();

    if (cleanText.isEmpty) {
      return '';
    }

    final Uri endpoint = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/'
      '$_model:generateContent?key=$apiKey',
    );

    final Map<String, dynamic> requestBody = {
      'contents': [
        {
          'parts': [
            {'text': _buildTranslatePrompt(cleanText)},
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

    final Map<String, dynamic> parsed = _parseFeedbackJson(
      rawText,
    );

    return parsed['translation'] as String? ?? '';
  }

  /// Nội dung prompt yêu cầu Gemini dịch nhanh sang tiếng Việt.
  String _buildTranslatePrompt(String englishText) {
    return 'Dịch câu tiếng Anh sau sang tiếng Việt tự nhiên, dễ '
        'hiểu, phù hợp ngữ cảnh giao tiếp:\n'
        '"$englishText"\n\n'
        'Trả về DUY NHẤT một đối tượng JSON thuần túy, không dùng '
        'markdown, không code fence, không giải thích thêm, theo '
        'đúng cấu trúc sau: {"translation": "bản dịch tiếng Việt"}.';
  }

  /// Gọi Gemini API với input text và phân tích kết quả JSON trả về.
  Future<Map<String, dynamic>> _callGeminiText({
    required String expectedText,
    required String userTranscript,
    required String apiKey,
  }) async {
    final Uri endpoint = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/'
      '$_model:generateContent?key=$apiKey',
    );

    final Map<String, dynamic> requestBody = {
      'contents': [
        {
          'parts': [
            {
              'text': _buildPrompt(
                expectedText: expectedText,
                userTranscript: userTranscript,
              ),
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

    return _parseFeedbackJson(rawText);
  }

  /// Nội dung prompt yêu cầu Gemini đóng vai huấn luyện viên phát âm.
  String _buildPrompt({
    required String expectedText,
    required String userTranscript,
  }) {
    final String cleanExpectedText = expectedText.trim();
    final String cleanUserTranscript = userTranscript.trim();

    return 'Bạn là một huấn luyện viên phát âm tiếng Anh thân '
        'thiện, đang hướng dẫn một học viên Việt Nam luyện tập '
        '"shadowing" (nghe rồi nhại lại câu).\n\n'
        'Câu gốc học viên cần nhại lại:\n'
        '"$cleanExpectedText"\n\n'
        'Bản phiên âm (transcript) những gì học viên đã nói, đã '
        'được nhận diện từ audio trước đó:\n'
        '"$cleanUserTranscript"\n\n'
        'Hãy so sánh hai câu trên (khác biệt từ vựng, từ bị thiếu, '
        'từ bị thừa, thứ tự từ) để suy luận ra những điểm học viên '
        'có thể đang phát âm chưa chuẩn, rồi trả về DUY NHẤT một '
        'đối tượng JSON thuần túy, không dùng markdown, không code '
        'fence, không giải thích thêm, theo đúng cấu trúc sau: '
        '{"overallAssessment": "1-2 câu đánh giá tổng quan bằng '
        'tiếng Việt, giọng văn khích lệ, khen trước rồi mới góp ý", '
        '"strengths": ["mỗi phần tử là một câu hoàn chỉnh bằng '
        'tiếng Việt nêu điểm học viên đã làm tốt"], '
        '"improvements": ["mỗi phần tử là một câu hoàn chỉnh bằng '
        'tiếng Việt, dễ hiểu, nêu rõ từ/âm cần cải thiện và vì sao, '
        'ví dụ: Từ \'thought\' bạn có thể đang phát âm gần giống '
        '\'taught\', chú ý âm th cần đặt lưỡi giữa hai hàm răng"], '
        '"practiceTips": ["mỗi phần tử là một câu hoàn chỉnh bằng '
        'tiếng Việt gợi ý cách luyện tập cụ thể"]}. '
        'Kết thúc phần overallAssessment hoặc phần cuối của '
        'practiceTips bằng một câu khích lệ học viên thử ghi âm '
        'lại. Nếu transcript trống hoặc không nghe rõ, vẫn trả về '
        'đúng cấu trúc JSON trên với overallAssessment giải thích '
        'lý do và practiceTips gợi ý ghi âm lại ở nơi yên tĩnh hơn.';
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
          'AI không phân tích được, vui lòng thử lại.',
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
          'AI không phân tích được, vui lòng thử lại.',
        );
      }

      final String text =
          (parts.first as Map<String, dynamic>)['text']
                  as String? ??
              '';

      if (text.trim().isEmpty) {
        throw Exception(
          'AI không phân tích được, vui lòng thử lại.',
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
  Map<String, dynamic> _parseFeedbackJson(String rawText) {
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
        'Không thể đọc kết quả phân tích từ AI, vui lòng thử lại.',
      );
    }
  }

  List<String> _parseStringList(dynamic value) {
    if (value is! List) {
      return <String>[];
    }

    return value.map((dynamic item) => item.toString()).toList();
  }
}
