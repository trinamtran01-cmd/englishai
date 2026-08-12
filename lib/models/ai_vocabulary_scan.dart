import 'package:cloud_firestore/cloud_firestore.dart';

/// Model đại diện cho một từ vựng được AI nhận diện từ ảnh chụp.
///
/// Mỗi đối tượng AiVocabularyScan tương ứng với một document
/// trong collection "ai_vocabulary_scans" trên Firestore.
class AiVocabularyScan {
  final String id;
  final String userId;
  final String word;
  final String meaning;
  final String pronunciation;
  final String partOfSpeech;
  final String example;
  final String exampleMeaning;
  final String imageUrl;
  final String sourceType;
  final DateTime? createdAt;

  const AiVocabularyScan({
    required this.id,
    required this.userId,
    required this.word,
    required this.meaning,
    required this.pronunciation,
    required this.partOfSpeech,
    required this.example,
    required this.exampleMeaning,
    required this.imageUrl,
    required this.sourceType,
    this.createdAt,
  });

  /// Tạo đối tượng AiVocabularyScan từ document Firestore.
  factory AiVocabularyScan.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final Map<String, dynamic> data =
        document.data() ?? <String, dynamic>{};

    return AiVocabularyScan(
      id: document.id,
      userId: data['userId'] as String? ?? '',
      word: data['word'] as String? ?? '',
      meaning: data['meaning'] as String? ?? '',
      pronunciation: data['pronunciation'] as String? ?? '',
      partOfSpeech: data['partOfSpeech'] as String? ?? '',
      example: data['example'] as String? ?? '',
      exampleMeaning: data['exampleMeaning'] as String? ?? '',
      imageUrl: data['imageUrl'] as String? ?? '',
      sourceType: data['sourceType'] as String? ?? 'camera',
      createdAt: _parseDateTime(data['createdAt']),
    );
  }

  /// Tạo đối tượng AiVocabularyScan từ Map.
  factory AiVocabularyScan.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    return AiVocabularyScan(
      id: id,
      userId: data['userId'] as String? ?? '',
      word: data['word'] as String? ?? '',
      meaning: data['meaning'] as String? ?? '',
      pronunciation: data['pronunciation'] as String? ?? '',
      partOfSpeech: data['partOfSpeech'] as String? ?? '',
      example: data['example'] as String? ?? '',
      exampleMeaning: data['exampleMeaning'] as String? ?? '',
      imageUrl: data['imageUrl'] as String? ?? '',
      sourceType: data['sourceType'] as String? ?? 'camera',
      createdAt: _parseDateTime(data['createdAt']),
    );
  }

  /// Chuyển AiVocabularyScan thành Map để lưu lên Firestore.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'userId': userId.trim(),
      'word': word.trim(),
      'meaning': meaning.trim(),
      'pronunciation': pronunciation.trim(),
      'partOfSpeech': partOfSpeech.trim(),
      'example': example.trim(),
      'exampleMeaning': exampleMeaning.trim(),
      'imageUrl': imageUrl.trim(),
      'sourceType': sourceType.trim(),
      'createdAt': createdAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(createdAt!),
    };
  }

  /// Tạo bản sao của bản ghi và thay đổi một số thuộc tính.
  AiVocabularyScan copyWith({
    String? id,
    String? userId,
    String? word,
    String? meaning,
    String? pronunciation,
    String? partOfSpeech,
    String? example,
    String? exampleMeaning,
    String? imageUrl,
    String? sourceType,
    DateTime? createdAt,
  }) {
    return AiVocabularyScan(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      word: word ?? this.word,
      meaning: meaning ?? this.meaning,
      pronunciation: pronunciation ?? this.pronunciation,
      partOfSpeech: partOfSpeech ?? this.partOfSpeech,
      example: example ?? this.example,
      exampleMeaning: exampleMeaning ?? this.exampleMeaning,
      imageUrl: imageUrl ?? this.imageUrl,
      sourceType: sourceType ?? this.sourceType,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Kiểm tra dữ liệu có đủ nội dung bắt buộc hay không.
  bool get isValid {
    return userId.trim().isNotEmpty &&
        word.trim().isNotEmpty &&
        meaning.trim().isNotEmpty;
  }

  /// Trả về từ loại dùng để hiển thị.
  ///
  /// Nếu chưa có từ loại, ứng dụng sẽ hiển thị "Từ vựng".
  String get displayPartOfSpeech {
    final String cleanPartOfSpeech = partOfSpeech.trim();

    if (cleanPartOfSpeech.isEmpty) {
      return 'Từ vựng';
    }

    return cleanPartOfSpeech;
  }

  /// Chuyển Timestamp hoặc DateTime thành DateTime.
  static DateTime? _parseDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }

  @override
  String toString() {
    return 'AiVocabularyScan('
        'id: $id, '
        'userId: $userId, '
        'word: $word, '
        'meaning: $meaning, '
        'sourceType: $sourceType'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is AiVocabularyScan && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
