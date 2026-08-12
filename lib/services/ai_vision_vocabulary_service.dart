import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/ai_vocabulary_scan.dart';

/// Nhận diện vật thể trong ảnh bằng Gemini Vision API và
/// tự động sinh từ vựng tiếng Anh tương ứng.
///
/// Collection sử dụng: ai_vocabulary_scans
class AiVisionVocabularyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const String _model = 'gemini-3.5-flash-lite';

  static const Duration _requestTimeout = Duration(seconds: 30);

  CollectionReference<Map<String, dynamic>>
      get _scansCollection {
    return _firestore.collection('ai_vocabulary_scans');
  }

  /// Lấy tài khoản hiện đang đăng nhập.
  User _requireCurrentUser() {
    final User? user = _auth.currentUser;

    if (user == null) {
      throw StateError(
        'Bạn cần đăng nhập để sử dụng tính năng quét từ vựng.',
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

  /// Phân tích ảnh chụp bằng Gemini Vision và lưu kết quả vào Firestore.
  ///
  /// Nhận trực tiếp [Uint8List] (không dùng `dart:io` File) để hoạt
  /// động được trên cả mobile lẫn web — trên web `dart:io` là stub
  /// và không đọc được ảnh vừa chụp/chọn.
  ///
  /// Trả về đối tượng AiVocabularyScan vừa được lưu.
  Future<AiVocabularyScan> analyzeImageAndSave(
    Uint8List imageBytes,
  ) async {
    final User user = _requireCurrentUser();
    final String apiKey = _requireApiKey();

    final Map<String, dynamic> recognizedData =
        await _callGeminiVision(
      imageBytes: imageBytes,
      apiKey: apiKey,
    );

    final AiVocabularyScan scan = AiVocabularyScan(
      id: '',
      userId: user.uid,
      word: recognizedData['word'] as String? ?? '',
      meaning: recognizedData['meaning'] as String? ?? '',
      pronunciation:
          recognizedData['pronunciation'] as String? ?? '',
      partOfSpeech:
          recognizedData['partOfSpeech'] as String? ?? '',
      example: recognizedData['example'] as String? ?? '',
      exampleMeaning:
          recognizedData['exampleMeaning'] as String? ?? '',
      // Chưa thiết lập Firebase Storage nên tạm để trống.
      imageUrl: '',
      sourceType: 'camera',
      createdAt: DateTime.now(),
    );

    if (!scan.isValid) {
      throw Exception(
        'Không nhận diện được vật thể trong ảnh, '
        'vui lòng thử lại với ảnh rõ hơn.',
      );
    }

    try {
      final DocumentReference<Map<String, dynamic>> document =
          await _scansCollection.add(scan.toMap());

      final DocumentSnapshot<Map<String, dynamic>>
          savedDocument = await document.get();

      return AiVocabularyScan.fromFirestore(savedDocument);
    } on FirebaseException catch (error) {
      throw Exception(
        'Không thể lưu từ vựng vào Firestore: ${error.code}',
      );
    }
  }

  /// Tra nghĩa một từ/cụm từ tiếng Anh do người dùng gõ vào bằng
  /// Gemini (chỉ text, không cần ảnh) và lưu kết quả vào Firestore.
  ///
  /// Dùng cho tính năng Từ điển AI — tái sử dụng đúng cấu trúc JSON,
  /// cách parse và cách xử lý lỗi như [analyzeImageAndSave], chỉ khác
  /// nguồn dữ liệu đầu vào (text thay vì ảnh) và `sourceType`.
  ///
  /// Trả về đối tượng AiVocabularyScan vừa được lưu.
  Future<AiVocabularyScan> analyzeTextAndSave(String word) async {
    final User user = _requireCurrentUser();
    final String apiKey = _requireApiKey();

    final String cleanWord = word.trim();

    if (cleanWord.isEmpty) {
      throw ArgumentError(
        'Vui lòng nhập một từ hoặc cụm từ tiếng Anh.',
      );
    }

    final Map<String, dynamic> recognizedData =
        await _callGeminiDictionary(
      word: cleanWord,
      apiKey: apiKey,
    );

    final AiVocabularyScan scan = AiVocabularyScan(
      id: '',
      userId: user.uid,
      word: recognizedData['word'] as String? ?? '',
      meaning: recognizedData['meaning'] as String? ?? '',
      pronunciation:
          recognizedData['pronunciation'] as String? ?? '',
      partOfSpeech:
          recognizedData['partOfSpeech'] as String? ?? '',
      example: recognizedData['example'] as String? ?? '',
      exampleMeaning:
          recognizedData['exampleMeaning'] as String? ?? '',
      imageUrl: '',
      sourceType: 'dictionary',
      createdAt: DateTime.now(),
    );

    if (!scan.isValid) {
      throw Exception(
        'Không tra được nghĩa của từ này, vui lòng thử từ khác.',
      );
    }

    try {
      final DocumentReference<Map<String, dynamic>> document =
          await _scansCollection.add(scan.toMap());

      final DocumentSnapshot<Map<String, dynamic>>
          savedDocument = await document.get();

      return AiVocabularyScan.fromFirestore(savedDocument);
    } on FirebaseException catch (error) {
      throw Exception(
        'Không thể lưu từ vựng vào Firestore: ${error.code}',
      );
    }
  }

  /// Gọi Gemini API (chỉ text) để tra nghĩa một từ/cụm từ.
  Future<Map<String, dynamic>> _callGeminiDictionary({
    required String word,
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
            {'text': _buildDictionaryPrompt(word)},
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

    return _parseVocabularyJson(rawText);
  }

  /// Nội dung prompt yêu cầu Gemini tra nghĩa một từ/cụm từ tiếng Anh.
  String _buildDictionaryPrompt(String word) {
    return 'Bạn là trợ lý từ điển Anh - Việt. Hãy tra nghĩa của từ '
        'hoặc cụm từ tiếng Anh sau: "$word". Trả về DUY NHẤT một đối '
        'tượng JSON thuần túy, không dùng markdown, không code fence, '
        'không giải thích thêm, theo đúng cấu trúc sau: '
        '{"word": "chính từ/cụm từ tiếng Anh người dùng đã nhập, viết '
        'đúng chính tả", '
        '"meaning": "nghĩa tiếng Việt", '
        '"pronunciation": "phiên âm IPA, ví dụ /wɜːd/", '
        '"partOfSpeech": "từ loại bằng tiếng Việt, ví dụ Danh từ", '
        '"example": "một câu ví dụ tiếng Anh có chứa từ đó", '
        '"exampleMeaning": "nghĩa tiếng Việt của câu ví dụ"}. '
        'Nếu đây không phải một từ/cụm từ tiếng Anh hợp lệ hoặc bạn '
        'không tra được nghĩa, hãy trả về {"word": "", "meaning": "", '
        '"pronunciation": "", "partOfSpeech": "", "example": "", '
        '"exampleMeaning": ""}.';
  }

  /// Gọi Gemini Vision API và phân tích kết quả JSON trả về.
  Future<Map<String, dynamic>> _callGeminiVision({
    required Uint8List imageBytes,
    required String apiKey,
  }) async {
    final String base64Image = base64Encode(imageBytes);

    final Uri endpoint = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/'
      '$_model:generateContent?key=$apiKey',
    );

    final Map<String, dynamic> requestBody = {
      'contents': [
        {
          'parts': [
            {'text': _buildPrompt()},
            {
              'inline_data': {
                'mime_type': 'image/jpeg',
                'data': base64Image,
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

    return _parseVocabularyJson(rawText);
  }

  /// Nội dung prompt yêu cầu Gemini trả về đúng cấu trúc JSON.
  String _buildPrompt() {
    return 'Bạn là trợ lý học tiếng Anh. Hãy nhận diện vật thể '
        'chính trong ảnh và trả về DUY NHẤT một đối tượng JSON '
        'thuần túy, không dùng markdown, không code fence, không '
        'giải thích thêm, theo đúng cấu trúc sau: '
        '{"word": "tên tiếng Anh của vật thể", '
        '"meaning": "nghĩa tiếng Việt", '
        '"pronunciation": "phiên âm IPA, ví dụ /wɜːd/", '
        '"partOfSpeech": "từ loại bằng tiếng Việt, ví dụ Danh từ", '
        '"example": "một câu ví dụ tiếng Anh có chứa từ đó", '
        '"exampleMeaning": "nghĩa tiếng Việt của câu ví dụ"}. '
        'Nếu không nhận diện được vật thể rõ ràng trong ảnh, hãy '
        'trả về {"word": "", "meaning": "", "pronunciation": "", '
        '"partOfSpeech": "", "example": "", "exampleMeaning": ""}.';
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
          'Không nhận diện được vật thể trong ảnh, '
          'vui lòng thử lại với ảnh rõ hơn.',
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
          'Không nhận diện được vật thể trong ảnh, '
          'vui lòng thử lại với ảnh rõ hơn.',
        );
      }

      final String text =
          (parts.first as Map<String, dynamic>)['text']
                  as String? ??
              '';

      if (text.trim().isEmpty) {
        throw Exception(
          'Không nhận diện được vật thể trong ảnh, '
          'vui lòng thử lại với ảnh rõ hơn.',
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
  Map<String, dynamic> _parseVocabularyJson(String rawText) {
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
      final Map<String, dynamic> parsed =
          jsonDecode(cleanText) as Map<String, dynamic>;

      final String word =
          (parsed['word'] as String? ?? '').trim();

      if (word.isEmpty) {
        throw Exception(
          'Không nhận diện được vật thể trong ảnh, '
          'vui lòng thử lại với ảnh rõ hơn.',
        );
      }

      return parsed;
    } on FormatException {
      throw Exception(
        'Không thể đọc kết quả nhận diện từ AI, '
        'vui lòng thử lại với ảnh khác.',
      );
    }
  }

  /// Theo dõi danh sách từ vựng đã quét của người dùng hiện tại.
  ///
  /// Sắp xếp mới nhất trước, thực hiện trong Flutter để không
  /// yêu cầu composite index trên Firebase.
  Stream<List<AiVocabularyScan>> getCurrentUserScans() {
    final User? user = _auth.currentUser;

    if (user == null) {
      return Stream<List<AiVocabularyScan>>.value(
        <AiVocabularyScan>[],
      );
    }

    return _scansCollection
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .map(
      (QuerySnapshot<Map<String, dynamic>> snapshot) {
        final List<AiVocabularyScan> scans = snapshot.docs
            .map(AiVocabularyScan.fromFirestore)
            .toList();

        scans.sort(
          (
            AiVocabularyScan first,
            AiVocabularyScan second,
          ) {
            final DateTime firstDate = first.createdAt ??
                DateTime.fromMillisecondsSinceEpoch(0);

            final DateTime secondDate = second.createdAt ??
                DateTime.fromMillisecondsSinceEpoch(0);

            return secondDate.compareTo(firstDate);
          },
        );

        return scans;
      },
    );
  }

  /// Xóa một bản ghi từ vựng đã quét.
  Future<void> deleteScan(String scanId) async {
    final String cleanScanId = scanId.trim();

    if (cleanScanId.isEmpty) {
      throw ArgumentError(
        'ID từ vựng đã quét không được để trống.',
      );
    }

    try {
      await _scansCollection.doc(cleanScanId).delete();
    } on FirebaseException catch (error) {
      throw Exception(
        'Không thể xóa từ vựng đã quét: ${error.code}',
      );
    }
  }
}
