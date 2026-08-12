import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/writing_ai_feedback.dart';
import '../models/writing_task.dart';

/// Chấm điểm bài Luyện Viết AI theo tiêu chí IELTS Writing bằng
/// Gemini, đưa ra nhận xét chi tiết bằng tiếng Việt, giọng văn
/// xây dựng.
///
/// Cách gọi Gemini API (text, đọc .env, parse JSON) tái sử dụng
/// đúng theo ShadowingAiFeedbackService.
///
/// Collection sử dụng: writing_ai_feedbacks
class WritingAiGradingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const String _model = 'gemini-3.5-flash-lite';

  static const Duration _requestTimeout = Duration(seconds: 45);

  CollectionReference<Map<String, dynamic>>
      get _feedbacksCollection {
    return _firestore.collection('writing_ai_feedbacks');
  }

  /// Lấy tài khoản hiện đang đăng nhập.
  User _requireCurrentUser() {
    final User? user = _auth.currentUser;

    if (user == null) {
      throw StateError(
        'Bạn cần đăng nhập để được AI chấm bài viết.',
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

  /// Chấm bài viết theo đề [task] với nội dung [userText] bằng Gemini
  /// và lưu kết quả vào Firestore.
  Future<WritingAiFeedback> gradeAttempt({
    required String attemptId,
    required WritingTask task,
    required String userText,
  }) async {
    final User user = _requireCurrentUser();
    final String apiKey = _requireApiKey();

    final String cleanAttemptId = attemptId.trim();

    if (cleanAttemptId.isEmpty) {
      throw ArgumentError('ID bài làm không được để trống.');
    }

    final Map<String, dynamic> gradedData = await _callGeminiGrading(
      task: task,
      userText: userText,
      apiKey: apiKey,
    );

    final WritingAiFeedback feedback = WritingAiFeedback(
      id: '',
      attemptId: cleanAttemptId,
      userId: user.uid,
      bandOverall: _parseBandValue(gradedData['bandOverall']),
      bandLexicalResource:
          _parseBandValue(gradedData['bandLexicalResource']),
      bandTaskAchievement:
          _parseBandValue(gradedData['bandTaskAchievement']),
      bandGrammaticalRange:
          _parseBandValue(gradedData['bandGrammaticalRange']),
      bandCoherenceCohesion:
          _parseBandValue(gradedData['bandCoherenceCohesion']),
      strengths: _parseStringList(gradedData['strengths']),
      priorityFixes: _parseStringList(gradedData['priorityFixes']),
      missingParts: _parseStringList(gradedData['missingParts']),
      generalComment:
          gradedData['generalComment'] as String? ?? '',
      createdAt: DateTime.now(),
    );

    if (!feedback.isValid) {
      throw Exception(
        'AI không chấm được bài viết này, vui lòng thử lại.',
      );
    }

    try {
      final DocumentReference<Map<String, dynamic>> document =
          await _feedbacksCollection.add(feedback.toMap());

      final DocumentSnapshot<Map<String, dynamic>>
          savedDocument = await document.get();

      return WritingAiFeedback.fromFirestore(savedDocument);
    } on FirebaseException catch (error) {
      throw Exception(
        'Không thể lưu kết quả chấm bài: ${error.code}',
      );
    }
  }

  /// Gọi Gemini API với đề bài + bài viết và phân tích kết quả JSON.
  Future<Map<String, dynamic>> _callGeminiGrading({
    required WritingTask task,
    required String userText,
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
                task: task,
                userText: userText,
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

    return _parseGradingJson(rawText);
  }

  /// Nội dung prompt yêu cầu Gemini đóng vai giám khảo IELTS Writing.
  String _buildPrompt({
    required WritingTask task,
    required String userText,
  }) {
    final String cleanUserText = userText.trim();

    final String taskContext = task.taskType.trim().toLowerCase() ==
            'task2'
        ? 'Đây là đề IELTS Writing Task 2 (bài luận nghị luận).'
        : 'Đây là đề IELTS Writing Task 1 (mô tả biểu đồ/bản đồ/quy '
            'trình)${task.chartType.trim().isEmpty ? '' : ', dạng "${task.chartType.trim()}"'}.';

    return 'Bạn là một giám khảo chấm thi IELTS Writing chính thức, '
        'giàu kinh nghiệm, đang chấm bài cho một học viên Việt Nam.\n\n'
        '$taskContext\n\n'
        'Đề bài:\n"${task.promptText.trim()}"\n\n'
        'Số từ tối thiểu yêu cầu: ${task.minWords}.\n\n'
        'Bài làm của học viên:\n"$cleanUserText"\n\n'
        'Hãy chấm bài theo đúng 4 tiêu chí chính thức của IELTS '
        'Writing (Lexical Resource, Task Achievement/Response, '
        'Grammatical Range and Accuracy, Coherence and Cohesion), '
        'thang điểm band 0.0 đến 9.0 (có thể lẻ 0.5), rồi trả về DUY '
        'NHẤT một đối tượng JSON thuần túy, không dùng markdown, '
        'không code fence, không giải thích thêm, theo đúng cấu trúc '
        'sau: '
        '{"bandOverall": số thực band tổng (trung bình 4 tiêu chí, '
        'làm tròn theo quy tắc IELTS), '
        '"bandLexicalResource": số thực, '
        '"bandTaskAchievement": số thực, '
        '"bandGrammaticalRange": số thực, '
        '"bandCoherenceCohesion": số thực, '
        '"strengths": ["mỗi phần tử là một câu hoàn chỉnh bằng tiếng '
        'Việt nêu một điểm mạnh cụ thể của bài viết"], '
        '"priorityFixes": ["mỗi phần tử là một câu hoàn chỉnh bằng '
        'tiếng Việt nêu một lỗi hoặc điểm cần ưu tiên sửa, cụ thể, '
        'không chung chung, nêu rõ vị trí/loại lỗi trong bài"], '
        '"missingParts": ["mỗi phần tử là một câu hoàn chỉnh bằng '
        'tiếng Việt nêu một phần còn thiếu so với yêu cầu đề bài, ví '
        'dụ thiếu Overview, thiếu số liệu dẫn chứng, thiếu kết luận; '
        'nếu bài đã đủ các phần thì để mảng rỗng"], '
        '"generalComment": "3-5 câu nhận xét tổng quan bằng tiếng '
        'Việt, giọng văn xây dựng, khen điểm mạnh trước rồi mới góp '
        'ý, kết thúc bằng một câu khích lệ học viên"}. '
        'Nếu bài làm trống hoặc quá ngắn để đánh giá, vẫn trả về '
        'đúng cấu trúc JSON trên với band thấp phù hợp và '
        'generalComment giải thích lý do, khuyến khích viết đủ số từ '
        'yêu cầu.';
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
          'AI không chấm được bài viết này, vui lòng thử lại.',
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
          'AI không chấm được bài viết này, vui lòng thử lại.',
        );
      }

      final String text =
          (parts.first as Map<String, dynamic>)['text']
                  as String? ??
              '';

      if (text.trim().isEmpty) {
        throw Exception(
          'AI không chấm được bài viết này, vui lòng thử lại.',
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
  Map<String, dynamic> _parseGradingJson(String rawText) {
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
        'Không thể đọc kết quả chấm bài từ AI, vui lòng thử lại.',
      );
    }
  }

  double _parseBandValue(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return 0;
  }

  List<String> _parseStringList(dynamic value) {
    if (value is! List) {
      return <String>[];
    }

    return value.map((dynamic item) => item.toString()).toList();
  }
}
