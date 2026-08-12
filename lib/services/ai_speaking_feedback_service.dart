import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/speaking_feedback.dart';

/// Phân tích giọng nói của người học bằng Gemini API (multimodal audio)
/// và lưu kết quả vào Firestore.
///
/// Lưu ý quan trọng: đây là đánh giá dựa trên khả năng hiểu ngôn ngữ
/// của một mô hình AI tổng quát (so sánh nội dung, từ vựng, độ lưu
/// loát qua bản phiên âm và ngữ điệu tổng quát), KHÔNG phải một công
/// cụ chấm phát âm chuyên dụng ở mức phoneme. Với những trường hợp
/// Gemini không thể đánh giá chi tiết từng âm vị, phản hồi vẫn cố
/// gắng hữu ích ở mức từ vựng, ngữ điệu và độ lưu loát.
///
/// Collection sử dụng: speaking_feedbacks
class AiSpeakingFeedbackService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const String _model = 'gemini-3.5-flash-lite';

  static const Duration _requestTimeout = Duration(seconds: 45);

  CollectionReference<Map<String, dynamic>>
      get _feedbacksCollection {
    return _firestore.collection('speaking_feedbacks');
  }

  /// Lấy tài khoản hiện đang đăng nhập.
  User _requireCurrentUser() {
    final User? user = _auth.currentUser;

    if (user == null) {
      throw StateError(
        'Bạn cần đăng nhập để sử dụng tính năng luyện nói.',
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

  /// Phân tích dữ liệu ghi âm bằng Gemini và lưu kết quả vào Firestore.
  ///
  /// [audioBytes] là dữ liệu ghi âm đã đọc sẵn thành bytes (mobile:
  /// đọc từ File; web: đọc từ Blob, vì `dart:io` File không hoạt
  /// động trên web), [mimeType] mô tả định dạng tương ứng.
  ///
  /// [expectedText] là câu người dùng được yêu cầu đọc, dùng để Gemini
  /// so sánh và đánh giá chính xác hơn.
  ///
  /// Trả về đối tượng SpeakingFeedback vừa được lưu.
  Future<SpeakingFeedback> analyzeAudioAndSave(
    Uint8List audioBytes,
    String mimeType,
    String videoId,
    String expectedText,
  ) async {
    final User user = _requireCurrentUser();
    final String apiKey = _requireApiKey();

    final String cleanVideoId = videoId.trim();

    if (cleanVideoId.isEmpty) {
      throw ArgumentError(
        'ID bài luyện nghe không được để trống.',
      );
    }

    final Map<String, dynamic> analyzedData =
        await _callGeminiAudio(
      audioBytes: audioBytes,
      mimeType: mimeType,
      expectedText: expectedText,
      apiKey: apiKey,
    );

    final SpeakingFeedback feedback = SpeakingFeedback(
      id: '',
      userId: user.uid,
      videoId: cleanVideoId,
      transcriptFromAudio:
          analyzedData['transcriptFromAudio'] as String? ?? '',
      overallFeedback:
          analyzedData['overallFeedback'] as String? ?? '',
      pronunciationIssues: _parseStringList(
        analyzedData['pronunciationIssues'],
      ),
      pronunciationScore: _parseScore(
        analyzedData['pronunciationScore'],
      ),
      createdAt: DateTime.now(),
    );

    try {
      final DocumentReference<Map<String, dynamic>> document =
          await _feedbacksCollection.add(feedback.toMap());

      final DocumentSnapshot<Map<String, dynamic>>
          savedDocument = await document.get();

      return SpeakingFeedback.fromFirestore(savedDocument);
    } on FirebaseException catch (error) {
      throw Exception(
        'Không thể lưu kết quả luyện nói: ${error.code}',
      );
    }
  }

  /// Gọi Gemini API với input audio và phân tích kết quả JSON trả về.
  Future<Map<String, dynamic>> _callGeminiAudio({
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

    return _parseFeedbackJson(rawText);
  }

  /// Nội dung prompt yêu cầu Gemini trả về đúng cấu trúc JSON.
  String _buildPrompt(String expectedText) {
    final String cleanExpectedText = expectedText.trim();

    return 'Bạn là giáo viên tiếng Anh, chuyên chấm và nhận xét '
        'phần luyện nói của học viên Việt Nam. Học viên được yêu '
        'cầu đọc to đoạn sau bằng tiếng Anh:\n'
        '"$cleanExpectedText"\n\n'
        'Hãy nghe file audio đính kèm, phiên âm lại chính xác những '
        'gì học viên đã nói, so sánh với đoạn được yêu cầu ở trên, '
        'rồi trả về DUY NHẤT một đối tượng JSON thuần túy, không '
        'dùng markdown, không code fence, không giải thích thêm, '
        'theo đúng cấu trúc sau: '
        '{"transcriptFromAudio": "phiên âm lại đúng những gì nghe '
        'được từ audio", '
        '"overallFeedback": "nhận xét tổng quan bằng tiếng Việt về '
        'nội dung, từ vựng, ngữ điệu và độ lưu loát", '
        '"pronunciationIssues": ["mỗi phần tử là một câu hoàn chỉnh '
        'bằng tiếng Việt nêu rõ từ/âm phát âm chưa chuẩn và gợi ý '
        'cách sửa, ví dụ: Từ \'thought\' bạn phát âm gần giống '
        '\'taught\', chú ý âm th cần đặt lưỡi giữa hai hàm răng"], '
        '"pronunciationScore": số nguyên từ 0 đến 100 do bạn tự '
        'chấm dựa trên độ chính xác nội dung và khả năng phát âm '
        'ước lượng qua giọng nói}. '
        'Nếu không nghe rõ được nội dung audio, hãy vẫn trả về đúng '
        'cấu trúc JSON trên với transcriptFromAudio để trống và '
        'overallFeedback giải thích lý do không đánh giá được.';
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
        'Không thể đọc kết quả phân tích từ AI, '
        'vui lòng thử ghi âm lại.',
      );
    }
  }

  List<String> _parseStringList(dynamic value) {
    if (value is! List) {
      return <String>[];
    }

    return value.map((dynamic item) => item.toString()).toList();
  }

  int _parseScore(dynamic value) {
    if (value is int) {
      return value.clamp(0, 100);
    }

    if (value is num) {
      return value.toInt().clamp(0, 100);
    }

    if (value is String) {
      return (int.tryParse(value) ?? 0).clamp(0, 100);
    }

    return 0;
  }
}
