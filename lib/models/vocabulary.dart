import 'package:cloud_firestore/cloud_firestore.dart';

/// Model đại diện cho một từ vựng thuộc bài học.
///
/// Mỗi đối tượng Vocabulary tương ứng với một document
/// trong collection "vocabularies" trên Firestore.
class Vocabulary {
  final String id;
  final String lessonId;
  final String word;
  final String meaning;
  final String pronunciation;
  final String example;
  final String exampleMeaning;
  final String partOfSpeech;
  final String imageUrl;
  final String audioUrl;
  final int order;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Vocabulary({
    required this.id,
    required this.lessonId,
    required this.word,
    required this.meaning,
    required this.pronunciation,
    required this.example,
    required this.exampleMeaning,
    required this.partOfSpeech,
    required this.imageUrl,
    required this.audioUrl,
    required this.order,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  /// Tạo đối tượng Vocabulary từ document Firestore.
  factory Vocabulary.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final Map<String, dynamic> data =
        document.data() ?? <String, dynamic>{};

    return Vocabulary(
      id: document.id,
      lessonId: data['lessonId'] as String? ?? '',
      word: data['word'] as String? ?? '',
      meaning: data['meaning'] as String? ?? '',
      pronunciation: data['pronunciation'] as String? ?? '',
      example: data['example'] as String? ?? '',
      exampleMeaning: data['exampleMeaning'] as String? ?? '',
      partOfSpeech: data['partOfSpeech'] as String? ?? '',
      imageUrl: data['imageUrl'] as String? ?? '',
      audioUrl: data['audioUrl'] as String? ?? '',
      order: _parseInteger(
        data['order'],
        defaultValue: 0,
      ),
      isActive: data['isActive'] as bool? ?? true,
      createdAt: _parseDateTime(data['createdAt']),
      updatedAt: _parseDateTime(data['updatedAt']),
    );
  }

  /// Tạo đối tượng Vocabulary từ Map.
  factory Vocabulary.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    return Vocabulary(
      id: id,
      lessonId: data['lessonId'] as String? ?? '',
      word: data['word'] as String? ?? '',
      meaning: data['meaning'] as String? ?? '',
      pronunciation: data['pronunciation'] as String? ?? '',
      example: data['example'] as String? ?? '',
      exampleMeaning: data['exampleMeaning'] as String? ?? '',
      partOfSpeech: data['partOfSpeech'] as String? ?? '',
      imageUrl: data['imageUrl'] as String? ?? '',
      audioUrl: data['audioUrl'] as String? ?? '',
      order: _parseInteger(
        data['order'],
        defaultValue: 0,
      ),
      isActive: data['isActive'] as bool? ?? true,
      createdAt: _parseDateTime(data['createdAt']),
      updatedAt: _parseDateTime(data['updatedAt']),
    );
  }

  /// Chuyển Vocabulary thành Map để lưu lên Firestore.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'lessonId': lessonId.trim(),
      'word': word.trim(),
      'meaning': meaning.trim(),
      'pronunciation': pronunciation.trim(),
      'example': example.trim(),
      'exampleMeaning': exampleMeaning.trim(),
      'partOfSpeech': partOfSpeech.trim(),
      'imageUrl': imageUrl.trim(),
      'audioUrl': audioUrl.trim(),
      'order': order,
      'isActive': isActive,
      'createdAt': createdAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(createdAt!),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Tạo bản sao của từ vựng và thay đổi một số thuộc tính.
  Vocabulary copyWith({
    String? id,
    String? lessonId,
    String? word,
    String? meaning,
    String? pronunciation,
    String? example,
    String? exampleMeaning,
    String? partOfSpeech,
    String? imageUrl,
    String? audioUrl,
    int? order,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Vocabulary(
      id: id ?? this.id,
      lessonId: lessonId ?? this.lessonId,
      word: word ?? this.word,
      meaning: meaning ?? this.meaning,
      pronunciation: pronunciation ?? this.pronunciation,
      example: example ?? this.example,
      exampleMeaning: exampleMeaning ?? this.exampleMeaning,
      partOfSpeech: partOfSpeech ?? this.partOfSpeech,
      imageUrl: imageUrl ?? this.imageUrl,
      audioUrl: audioUrl ?? this.audioUrl,
      order: order ?? this.order,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Kiểm tra dữ liệu từ vựng có đủ nội dung bắt buộc hay không.
  bool get isValid {
    return lessonId.trim().isNotEmpty &&
        word.trim().isNotEmpty &&
        meaning.trim().isNotEmpty;
  }

  /// Trả về từ loại dùng để hiển thị.
  ///
  /// Nếu chưa nhập từ loại, ứng dụng sẽ hiển thị "Từ vựng".
  String get displayPartOfSpeech {
    final String cleanPartOfSpeech = partOfSpeech.trim();

    if (cleanPartOfSpeech.isEmpty) {
      return 'Từ vựng';
    }

    return cleanPartOfSpeech;
  }

  /// Chuyển dữ liệu số từ Firestore thành int an toàn.
  static int _parseInteger(
    dynamic value, {
    required int defaultValue,
  }) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    if (value is String) {
      return int.tryParse(value) ?? defaultValue;
    }

    return defaultValue;
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
    return 'Vocabulary('
        'id: $id, '
        'lessonId: $lessonId, '
        'word: $word, '
        'meaning: $meaning, '
        'order: $order, '
        'isActive: $isActive'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is Vocabulary && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}