import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/lesson.dart';
import '../models/vocabulary.dart';

/// Quản lý dữ liệu từ vựng trên Firebase Firestore.
///
/// Collection sử dụng: vocabularies
class VocabularyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>>
      get _vocabulariesCollection {
    return _firestore.collection('vocabularies');
  }

  /// Theo dõi danh sách từ vựng đang hoạt động của một bài học.
  ///
  /// Firestore chỉ lọc theo lessonId.
  /// Việc lọc isActive và sắp xếp order được thực hiện trong Flutter
  /// để không yêu cầu composite index trên Firebase.
  Stream<List<Vocabulary>> getActiveVocabularies(
    String lessonId,
  ) {
    final String cleanLessonId = lessonId.trim();

    if (cleanLessonId.isEmpty) {
      return Stream<List<Vocabulary>>.value(
        <Vocabulary>[],
      );
    }

    return _vocabulariesCollection
        .where(
          'lessonId',
          isEqualTo: cleanLessonId,
        )
        .snapshots()
        .map(
      (QuerySnapshot<Map<String, dynamic>> snapshot) {
        final List<Vocabulary> vocabularies = snapshot.docs
            .map(Vocabulary.fromFirestore)
            .where(
              (Vocabulary vocabulary) =>
                  vocabulary.isActive,
            )
            .toList();

        vocabularies.sort(
          (
            Vocabulary firstVocabulary,
            Vocabulary secondVocabulary,
          ) {
            return firstVocabulary.order.compareTo(
              secondVocabulary.order,
            );
          },
        );

        return vocabularies;
      },
    );
  }

  /// Lấy toàn bộ từ vựng thuộc một bài học.
  ///
  /// Hàm này có thể sử dụng cho trang quản trị sau này.
  Future<List<Vocabulary>> getVocabulariesByLesson(
    String lessonId,
  ) async {
    final String cleanLessonId = lessonId.trim();

    if (cleanLessonId.isEmpty) {
      throw ArgumentError(
        'ID bài học không được để trống.',
      );
    }

    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot =
          await _vocabulariesCollection
              .where(
                'lessonId',
                isEqualTo: cleanLessonId,
              )
              .get();

      final List<Vocabulary> vocabularies = snapshot.docs
          .map(Vocabulary.fromFirestore)
          .toList();

      vocabularies.sort(
        (
          Vocabulary firstVocabulary,
          Vocabulary secondVocabulary,
        ) {
          return firstVocabulary.order.compareTo(
            secondVocabulary.order,
          );
        },
      );

      return vocabularies;
    } on FirebaseException catch (error) {
      throw Exception(
        'Không thể tải danh sách từ vựng: ${error.code}',
      );
    }
  }

  /// Lấy thông tin một từ vựng theo ID.
  ///
  /// Trả về null nếu từ vựng không tồn tại.
  Future<Vocabulary?> getVocabularyById(
    String vocabularyId,
  ) async {
    final String cleanVocabularyId = vocabularyId.trim();

    if (cleanVocabularyId.isEmpty) {
      throw ArgumentError(
        'ID từ vựng không được để trống.',
      );
    }

    try {
      final DocumentSnapshot<Map<String, dynamic>> document =
          await _vocabulariesCollection
              .doc(cleanVocabularyId)
              .get();

      if (!document.exists) {
        return null;
      }

      return Vocabulary.fromFirestore(document);
    } on FirebaseException catch (error) {
      throw Exception(
        'Không thể tải thông tin từ vựng: ${error.code}',
      );
    }
  }

  /// Thêm một từ vựng mới.
  ///
  /// Trả về ID của từ vựng vừa được tạo.
  Future<String> addVocabulary(
    Vocabulary vocabulary,
  ) async {
    if (!vocabulary.isValid) {
      throw ArgumentError(
        'Từ vựng phải có lessonId, word và meaning.',
      );
    }

    try {
      final DocumentReference<Map<String, dynamic>> document =
          await _vocabulariesCollection.add(
        vocabulary.toMap(),
      );

      return document.id;
    } on FirebaseException catch (error) {
      throw Exception(
        'Không thể thêm từ vựng: ${error.code}',
      );
    }
  }

  /// Cập nhật thông tin một từ vựng.
  Future<void> updateVocabulary(
    Vocabulary vocabulary,
  ) async {
    final String cleanVocabularyId =
        vocabulary.id.trim();

    if (cleanVocabularyId.isEmpty) {
      throw ArgumentError(
        'ID từ vựng không được để trống.',
      );
    }

    if (!vocabulary.isValid) {
      throw ArgumentError(
        'Từ vựng phải có lessonId, word và meaning.',
      );
    }

    try {
      final Map<String, dynamic> data =
          vocabulary.toMap();

      // Không thay đổi thời gian tạo khi cập nhật.
      data.remove('createdAt');

      await _vocabulariesCollection
          .doc(cleanVocabularyId)
          .update(data);
    } on FirebaseException catch (error) {
      throw Exception(
        'Không thể cập nhật từ vựng: ${error.code}',
      );
    }
  }

  /// Bật hoặc tắt trạng thái hoạt động của từ vựng.
  Future<void> updateVocabularyStatus({
    required String vocabularyId,
    required bool isActive,
  }) async {
    final String cleanVocabularyId =
        vocabularyId.trim();

    if (cleanVocabularyId.isEmpty) {
      throw ArgumentError(
        'ID từ vựng không được để trống.',
      );
    }

    try {
      await _vocabulariesCollection
          .doc(cleanVocabularyId)
          .update({
        'isActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (error) {
      throw Exception(
        'Không thể cập nhật trạng thái từ vựng: '
        '${error.code}',
      );
    }
  }

  /// Xóa một từ vựng khỏi Firestore.
  Future<void> deleteVocabulary(
    String vocabularyId,
  ) async {
    final String cleanVocabularyId =
        vocabularyId.trim();

    if (cleanVocabularyId.isEmpty) {
      throw ArgumentError(
        'ID từ vựng không được để trống.',
      );
    }

    try {
      await _vocabulariesCollection
          .doc(cleanVocabularyId)
          .delete();
    } on FirebaseException catch (error) {
      throw Exception(
        'Không thể xóa từ vựng: ${error.code}',
      );
    }
  }

  /// Kiểm tra một bài học đã có dữ liệu từ vựng hay chưa.
  Future<bool> hasVocabularies(
    String lessonId,
  ) async {
    final String cleanLessonId = lessonId.trim();

    if (cleanLessonId.isEmpty) {
      return false;
    }

    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot =
          await _vocabulariesCollection
              .where(
                'lessonId',
                isEqualTo: cleanLessonId,
              )
              .limit(1)
              .get();

      return snapshot.docs.isNotEmpty;
    } on FirebaseException catch (error) {
      throw Exception(
        'Không thể kiểm tra dữ liệu từ vựng: '
        '${error.code}',
      );
    }
  }

  /// Tự tạo dữ liệu từ vựng mẫu cho một bài học.
  ///
  /// Dữ liệu chỉ được tạo nếu bài học chưa có từ vựng,
  /// giúp tránh bị trùng khi mở màn hình nhiều lần.
  Future<void> createSampleVocabularies(
    Lesson lesson,
  ) async {
    final String lessonId = lesson.id.trim();

    if (lessonId.isEmpty) {
      throw ArgumentError(
        'ID bài học không được để trống.',
      );
    }

    try {
      final bool alreadyHasVocabularies =
          await hasVocabularies(lessonId);

      if (alreadyHasVocabularies) {
        return;
      }

      final List<Map<String, dynamic>> sampleData =
          _getSampleDataForLesson(lesson);

      if (sampleData.isEmpty) {
        return;
      }

      final WriteBatch batch = _firestore.batch();

      for (int index = 0;
          index < sampleData.length;
          index++) {
        final DocumentReference<Map<String, dynamic>>
            document = _vocabulariesCollection.doc();

        final Map<String, dynamic> vocabularyData = {
          ...sampleData[index],
          'lessonId': lessonId,
          'order': index + 1,
          'isActive': true,
          'imageUrl': '',
          'audioUrl': '',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };

        batch.set(document, vocabularyData);
      }

      await batch.commit();
    } on FirebaseException catch (error) {
      throw Exception(
        'Không thể tạo dữ liệu từ vựng mẫu: '
        '${error.code}',
      );
    }
  }

  /// Chọn dữ liệu mẫu dựa trên tiêu đề bài học.
  List<Map<String, dynamic>> _getSampleDataForLesson(
    Lesson lesson,
  ) {
    final String normalizedTitle =
        lesson.title.trim().toLowerCase();

    if (normalizedTitle.contains('chào hỏi')) {
      return _greetingVocabularies();
    }

    if (normalizedTitle.contains('gia đình')) {
      return _familyVocabularies();
    }

    if (normalizedTitle.contains('trường học')) {
      return _schoolVocabularies();
    }

    if (normalizedTitle.contains('đồ ăn') ||
        normalizedTitle.contains('thức uống')) {
      return _foodVocabularies();
    }

    if (normalizedTitle.contains('hằng ngày') ||
        normalizedTitle.contains('hàng ngày') ||
        normalizedTitle.contains('công việc')) {
      return _dailyRoutineVocabularies();
    }

    return _defaultVocabularies();
  }

  List<Map<String, dynamic>> _greetingVocabularies() {
    return <Map<String, dynamic>>[
      {
        'word': 'Hello',
        'meaning': 'Xin chào',
        'pronunciation': '/həˈləʊ/',
        'partOfSpeech': 'Thán từ',
        'example': 'Hello, nice to meet you.',
        'exampleMeaning':
            'Xin chào, rất vui được gặp bạn.',
      },
      {
        'word': 'Good morning',
        'meaning': 'Chào buổi sáng',
        'pronunciation': '/ɡʊd ˈmɔːnɪŋ/',
        'partOfSpeech': 'Cụm từ',
        'example': 'Good morning, everyone.',
        'exampleMeaning':
            'Chào buổi sáng, mọi người.',
      },
      {
        'word': 'Goodbye',
        'meaning': 'Tạm biệt',
        'pronunciation': '/ˌɡʊdˈbaɪ/',
        'partOfSpeech': 'Thán từ',
        'example': 'Goodbye. See you tomorrow.',
        'exampleMeaning':
            'Tạm biệt. Hẹn gặp bạn ngày mai.',
      },
      {
        'word': 'Welcome',
        'meaning': 'Chào mừng',
        'pronunciation': '/ˈwelkəm/',
        'partOfSpeech': 'Động từ',
        'example': 'Welcome to our English class.',
        'exampleMeaning':
            'Chào mừng bạn đến với lớp tiếng Anh.',
      },
      {
        'word': 'Introduce',
        'meaning': 'Giới thiệu',
        'pronunciation': '/ˌɪntrəˈdjuːs/',
        'partOfSpeech': 'Động từ',
        'example': 'Let me introduce myself.',
        'exampleMeaning':
            'Hãy để tôi tự giới thiệu.',
      },
    ];
  }

  List<Map<String, dynamic>> _familyVocabularies() {
    return <Map<String, dynamic>>[
      {
        'word': 'Father',
        'meaning': 'Cha, bố',
        'pronunciation': '/ˈfɑːðə(r)/',
        'partOfSpeech': 'Danh từ',
        'example': 'My father works in a factory.',
        'exampleMeaning':
            'Bố tôi làm việc trong một nhà máy.',
      },
      {
        'word': 'Mother',
        'meaning': 'Mẹ',
        'pronunciation': '/ˈmʌðə(r)/',
        'partOfSpeech': 'Danh từ',
        'example': 'My mother is a teacher.',
        'exampleMeaning': 'Mẹ tôi là giáo viên.',
      },
      {
        'word': 'Brother',
        'meaning': 'Anh hoặc em trai',
        'pronunciation': '/ˈbrʌðə(r)/',
        'partOfSpeech': 'Danh từ',
        'example': 'I have one younger brother.',
        'exampleMeaning':
            'Tôi có một người em trai.',
      },
      {
        'word': 'Sister',
        'meaning': 'Chị hoặc em gái',
        'pronunciation': '/ˈsɪstə(r)/',
        'partOfSpeech': 'Danh từ',
        'example': 'My sister likes reading books.',
        'exampleMeaning':
            'Chị gái tôi thích đọc sách.',
      },
      {
        'word': 'Grandparents',
        'meaning': 'Ông bà',
        'pronunciation': '/ˈɡrænpeərənts/',
        'partOfSpeech': 'Danh từ',
        'example': 'I visit my grandparents every week.',
        'exampleMeaning':
            'Tôi thăm ông bà mỗi tuần.',
      },
    ];
  }

  List<Map<String, dynamic>> _schoolVocabularies() {
    return <Map<String, dynamic>>[
      {
        'word': 'Teacher',
        'meaning': 'Giáo viên',
        'pronunciation': '/ˈtiːtʃə(r)/',
        'partOfSpeech': 'Danh từ',
        'example': 'Our teacher explains the lesson.',
        'exampleMeaning':
            'Giáo viên giải thích bài học.',
      },
      {
        'word': 'Student',
        'meaning': 'Học sinh, sinh viên',
        'pronunciation': '/ˈstjuːdnt/',
        'partOfSpeech': 'Danh từ',
        'example': 'Every student has a notebook.',
        'exampleMeaning':
            'Mỗi học sinh đều có một quyển vở.',
      },
      {
        'word': 'Classroom',
        'meaning': 'Phòng học',
        'pronunciation': '/ˈklɑːsruːm/',
        'partOfSpeech': 'Danh từ',
        'example': 'The classroom is very clean.',
        'exampleMeaning': 'Phòng học rất sạch.',
      },
      {
        'word': 'Notebook',
        'meaning': 'Quyển vở',
        'pronunciation': '/ˈnəʊtbʊk/',
        'partOfSpeech': 'Danh từ',
        'example': 'I write new words in my notebook.',
        'exampleMeaning':
            'Tôi viết từ mới vào quyển vở.',
      },
      {
        'word': 'Homework',
        'meaning': 'Bài tập về nhà',
        'pronunciation': '/ˈhəʊmwɜːk/',
        'partOfSpeech': 'Danh từ',
        'example': 'I finish my homework after dinner.',
        'exampleMeaning':
            'Tôi hoàn thành bài tập sau bữa tối.',
      },
    ];
  }

  List<Map<String, dynamic>> _foodVocabularies() {
    return <Map<String, dynamic>>[
      {
        'word': 'Rice',
        'meaning': 'Cơm, gạo',
        'pronunciation': '/raɪs/',
        'partOfSpeech': 'Danh từ',
        'example': 'We eat rice every day.',
        'exampleMeaning': 'Chúng tôi ăn cơm mỗi ngày.',
      },
      {
        'word': 'Bread',
        'meaning': 'Bánh mì',
        'pronunciation': '/bred/',
        'partOfSpeech': 'Danh từ',
        'example': 'I have bread for breakfast.',
        'exampleMeaning':
            'Tôi ăn bánh mì vào bữa sáng.',
      },
      {
        'word': 'Water',
        'meaning': 'Nước',
        'pronunciation': '/ˈwɔːtə(r)/',
        'partOfSpeech': 'Danh từ',
        'example': 'Please drink more water.',
        'exampleMeaning': 'Hãy uống nhiều nước hơn.',
      },
      {
        'word': 'Vegetable',
        'meaning': 'Rau củ',
        'pronunciation': '/ˈvedʒtəbl/',
        'partOfSpeech': 'Danh từ',
        'example': 'Vegetables are good for your health.',
        'exampleMeaning':
            'Rau củ tốt cho sức khỏe của bạn.',
      },
      {
        'word': 'Delicious',
        'meaning': 'Ngon',
        'pronunciation': '/dɪˈlɪʃəs/',
        'partOfSpeech': 'Tính từ',
        'example': 'This soup is delicious.',
        'exampleMeaning': 'Món súp này rất ngon.',
      },
    ];
  }

  List<Map<String, dynamic>>
      _dailyRoutineVocabularies() {
    return <Map<String, dynamic>>[
      {
        'word': 'Wake up',
        'meaning': 'Thức dậy',
        'pronunciation': '/weɪk ʌp/',
        'partOfSpeech': 'Cụm động từ',
        'example': 'I wake up at six o’clock.',
        'exampleMeaning': 'Tôi thức dậy lúc sáu giờ.',
      },
      {
        'word': 'Have breakfast',
        'meaning': 'Ăn sáng',
        'pronunciation': '/hæv ˈbrekfəst/',
        'partOfSpeech': 'Cụm động từ',
        'example': 'I have breakfast with my family.',
        'exampleMeaning':
            'Tôi ăn sáng cùng gia đình.',
      },
      {
        'word': 'Go to work',
        'meaning': 'Đi làm',
        'pronunciation': '/ɡəʊ tə wɜːk/',
        'partOfSpeech': 'Cụm động từ',
        'example': 'I go to work by motorbike.',
        'exampleMeaning': 'Tôi đi làm bằng xe máy.',
      },
      {
        'word': 'Study',
        'meaning': 'Học tập',
        'pronunciation': '/ˈstʌdi/',
        'partOfSpeech': 'Động từ',
        'example': 'I study English every evening.',
        'exampleMeaning':
            'Tôi học tiếng Anh mỗi buổi tối.',
      },
      {
        'word': 'Go to bed',
        'meaning': 'Đi ngủ',
        'pronunciation': '/ɡəʊ tə bed/',
        'partOfSpeech': 'Cụm động từ',
        'example': 'I go to bed at ten o’clock.',
        'exampleMeaning': 'Tôi đi ngủ lúc mười giờ.',
      },
    ];
  }

  List<Map<String, dynamic>> _defaultVocabularies() {
    return <Map<String, dynamic>>[
      {
        'word': 'Learn',
        'meaning': 'Học',
        'pronunciation': '/lɜːn/',
        'partOfSpeech': 'Động từ',
        'example': 'I learn English every day.',
        'exampleMeaning':
            'Tôi học tiếng Anh mỗi ngày.',
      },
      {
        'word': 'Practice',
        'meaning': 'Luyện tập',
        'pronunciation': '/ˈpræktɪs/',
        'partOfSpeech': 'Động từ',
        'example': 'Practice helps you improve.',
        'exampleMeaning':
            'Luyện tập giúp bạn tiến bộ.',
      },
      {
        'word': 'Remember',
        'meaning': 'Ghi nhớ',
        'pronunciation': '/rɪˈmembə(r)/',
        'partOfSpeech': 'Động từ',
        'example': 'Try to remember this word.',
        'exampleMeaning':
            'Hãy cố gắng ghi nhớ từ này.',
      },
      {
        'word': 'Speak',
        'meaning': 'Nói',
        'pronunciation': '/spiːk/',
        'partOfSpeech': 'Động từ',
        'example': 'Please speak English in class.',
        'exampleMeaning':
            'Hãy nói tiếng Anh trong lớp.',
      },
      {
        'word': 'Understand',
        'meaning': 'Hiểu',
        'pronunciation': '/ˌʌndəˈstænd/',
        'partOfSpeech': 'Động từ',
        'example': 'I understand the lesson.',
        'exampleMeaning': 'Tôi hiểu bài học.',
      },
    ];
  }
}