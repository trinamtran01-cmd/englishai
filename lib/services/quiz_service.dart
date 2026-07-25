import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/lesson.dart';
import '../models/quiz_question.dart';

/// Quản lý dữ liệu câu hỏi trắc nghiệm trên Firebase Firestore.
///
/// Collection sử dụng: quiz_questions
class QuizService {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>>
      get _questionsCollection {
    return _firestore.collection('quiz_questions');
  }

  /// Theo dõi các câu hỏi đang hoạt động của một bài học.
  ///
  /// Firestore chỉ lọc theo lessonId.
  /// Việc lọc isActive và sắp xếp order được thực hiện
  /// trong Flutter để không cần composite index.
  Stream<List<QuizQuestion>> getActiveQuestions(
    String lessonId,
  ) {
    final String cleanLessonId = lessonId.trim();

    if (cleanLessonId.isEmpty) {
      return Stream<List<QuizQuestion>>.value(
        <QuizQuestion>[],
      );
    }

    return _questionsCollection
        .where(
          'lessonId',
          isEqualTo: cleanLessonId,
        )
        .snapshots()
        .map(
      (
        QuerySnapshot<Map<String, dynamic>> snapshot,
      ) {
        final List<QuizQuestion> questions =
            snapshot.docs
                .map(QuizQuestion.fromFirestore)
                .where(
                  (QuizQuestion question) =>
                      question.isActive &&
                      question.isValid,
                )
                .toList();

        questions.sort(
          (
            QuizQuestion firstQuestion,
            QuizQuestion secondQuestion,
          ) {
            return firstQuestion.order.compareTo(
              secondQuestion.order,
            );
          },
        );

        return questions;
      },
    );
  }

  /// Lấy các câu hỏi của một bài học một lần.
  Future<List<QuizQuestion>> getQuestionsByLesson(
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
          await _questionsCollection
              .where(
                'lessonId',
                isEqualTo: cleanLessonId,
              )
              .get();

      final List<QuizQuestion> questions =
          snapshot.docs
              .map(QuizQuestion.fromFirestore)
              .toList();

      questions.sort(
        (
          QuizQuestion firstQuestion,
          QuizQuestion secondQuestion,
        ) {
          return firstQuestion.order.compareTo(
            secondQuestion.order,
          );
        },
      );

      return questions;
    } on FirebaseException catch (error) {
      throw Exception(
        'Không thể tải câu hỏi: ${error.code}',
      );
    }
  }

  /// Lấy một câu hỏi theo ID.
  ///
  /// Trả về null nếu câu hỏi không tồn tại.
  Future<QuizQuestion?> getQuestionById(
    String questionId,
  ) async {
    final String cleanQuestionId = questionId.trim();

    if (cleanQuestionId.isEmpty) {
      throw ArgumentError(
        'ID câu hỏi không được để trống.',
      );
    }

    try {
      final DocumentSnapshot<Map<String, dynamic>>
          document = await _questionsCollection
              .doc(cleanQuestionId)
              .get();

      if (!document.exists) {
        return null;
      }

      return QuizQuestion.fromFirestore(document);
    } on FirebaseException catch (error) {
      throw Exception(
        'Không thể tải câu hỏi: ${error.code}',
      );
    }
  }

  /// Thêm câu hỏi mới vào Firestore.
  ///
  /// Trả về ID của câu hỏi vừa tạo.
  Future<String> addQuestion(
    QuizQuestion question,
  ) async {
    if (!question.isValid) {
      throw ArgumentError(
        'Dữ liệu câu hỏi không hợp lệ.',
      );
    }

    try {
      final DocumentReference<Map<String, dynamic>>
          document = await _questionsCollection.add(
        question.toMap(),
      );

      return document.id;
    } on FirebaseException catch (error) {
      throw Exception(
        'Không thể thêm câu hỏi: ${error.code}',
      );
    }
  }

  /// Cập nhật một câu hỏi.
  Future<void> updateQuestion(
    QuizQuestion question,
  ) async {
    final String cleanQuestionId = question.id.trim();

    if (cleanQuestionId.isEmpty) {
      throw ArgumentError(
        'ID câu hỏi không được để trống.',
      );
    }

    if (!question.isValid) {
      throw ArgumentError(
        'Dữ liệu câu hỏi không hợp lệ.',
      );
    }

    try {
      final Map<String, dynamic> data =
          question.toMap();

      // Không thay đổi thời gian tạo.
      data.remove('createdAt');

      await _questionsCollection
          .doc(cleanQuestionId)
          .update(data);
    } on FirebaseException catch (error) {
      throw Exception(
        'Không thể cập nhật câu hỏi: ${error.code}',
      );
    }
  }

  /// Bật hoặc tắt trạng thái hoạt động của câu hỏi.
  Future<void> updateQuestionStatus({
    required String questionId,
    required bool isActive,
  }) async {
    final String cleanQuestionId = questionId.trim();

    if (cleanQuestionId.isEmpty) {
      throw ArgumentError(
        'ID câu hỏi không được để trống.',
      );
    }

    try {
      await _questionsCollection
          .doc(cleanQuestionId)
          .update(
        <String, dynamic>{
          'isActive': isActive,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );
    } on FirebaseException catch (error) {
      throw Exception(
        'Không thể cập nhật trạng thái câu hỏi: '
        '${error.code}',
      );
    }
  }

  /// Xóa một câu hỏi khỏi Firestore.
  Future<void> deleteQuestion(
    String questionId,
  ) async {
    final String cleanQuestionId = questionId.trim();

    if (cleanQuestionId.isEmpty) {
      throw ArgumentError(
        'ID câu hỏi không được để trống.',
      );
    }

    try {
      await _questionsCollection
          .doc(cleanQuestionId)
          .delete();
    } on FirebaseException catch (error) {
      throw Exception(
        'Không thể xóa câu hỏi: ${error.code}',
      );
    }
  }

  /// Kiểm tra một bài học đã có câu hỏi hay chưa.
  Future<bool> hasQuestions(
    String lessonId,
  ) async {
    final String cleanLessonId = lessonId.trim();

    if (cleanLessonId.isEmpty) {
      return false;
    }

    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot =
          await _questionsCollection
              .where(
                'lessonId',
                isEqualTo: cleanLessonId,
              )
              .limit(1)
              .get();

      return snapshot.docs.isNotEmpty;
    } on FirebaseException catch (error) {
      throw Exception(
        'Không thể kiểm tra dữ liệu câu hỏi: '
        '${error.code}',
      );
    }
  }

  /// Tự tạo câu hỏi mẫu cho một bài học.
  ///
  /// Dữ liệu chỉ được tạo nếu bài học chưa có câu hỏi,
  /// giúp tránh bị trùng khi mở màn hình nhiều lần.
  Future<void> createSampleQuestions(
    Lesson lesson,
  ) async {
    final String lessonId = lesson.id.trim();

    if (lessonId.isEmpty) {
      throw ArgumentError(
        'ID bài học không được để trống.',
      );
    }

    try {
      final bool alreadyHasQuestions =
          await hasQuestions(lessonId);

      if (alreadyHasQuestions) {
        return;
      }

      final List<Map<String, dynamic>> sampleQuestions =
          _getSampleQuestionsForLesson(lesson);

      if (sampleQuestions.isEmpty) {
        return;
      }

      final WriteBatch batch = _firestore.batch();

      for (
        int index = 0;
        index < sampleQuestions.length;
        index++
      ) {
        final DocumentReference<Map<String, dynamic>>
            document = _questionsCollection.doc();

        final Map<String, dynamic> questionData =
            <String, dynamic>{
          ...sampleQuestions[index],
          'lessonId': lessonId,
          'lessonTitle': lesson.title.trim(),
          'order': index + 1,
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };

        batch.set(document, questionData);
      }

      await batch.commit();
    } on FirebaseException catch (error) {
      throw Exception(
        'Không thể tạo câu hỏi mẫu: ${error.code}',
      );
    }
  }

  /// Trả về dữ liệu câu hỏi tương ứng với chủ đề bài học.
  List<Map<String, dynamic>> _getSampleQuestionsForLesson(
    Lesson lesson,
  ) {
    final String normalizedTitle =
        lesson.title.trim().toLowerCase();

    if (normalizedTitle.contains('chào hỏi')) {
      return _greetingQuestions();
    }

    if (normalizedTitle.contains('gia đình')) {
      return _familyQuestions();
    }

    if (normalizedTitle.contains('trường học')) {
      return _schoolQuestions();
    }

    if (normalizedTitle.contains('đồ ăn') ||
        normalizedTitle.contains('thức uống')) {
      return _foodQuestions();
    }

    if (normalizedTitle.contains('hằng ngày') ||
        normalizedTitle.contains('hàng ngày') ||
        normalizedTitle.contains('công việc')) {
      return _dailyRoutineQuestions();
    }

    return _defaultQuestions();
  }

  List<Map<String, dynamic>> _greetingQuestions() {
    return <Map<String, dynamic>>[
      {
        'question': 'Từ “Hello” có nghĩa là gì?',
        'options': <String>[
          'Tạm biệt',
          'Xin chào',
          'Cảm ơn',
          'Xin lỗi',
        ],
        'correctAnswerIndex': 1,
        'explanation':
            '“Hello” là từ được dùng để nói xin chào.',
        'difficulty': 'easy',
      },
      {
        'question':
            'Cụm từ nào được dùng để chào vào buổi sáng?',
        'options': <String>[
          'Good night',
          'Goodbye',
          'Good morning',
          'Good afternoon',
        ],
        'correctAnswerIndex': 2,
        'explanation':
            '“Good morning” có nghĩa là chào buổi sáng.',
        'difficulty': 'easy',
      },
      {
        'question': '“Goodbye” có nghĩa là gì?',
        'options': <String>[
          'Chào mừng',
          'Tạm biệt',
          'Buổi sáng tốt lành',
          'Rất vui gặp bạn',
        ],
        'correctAnswerIndex': 1,
        'explanation':
            '“Goodbye” được dùng khi chào tạm biệt.',
        'difficulty': 'easy',
      },
      {
        'question':
            'Câu nào có nghĩa “Rất vui được gặp bạn”?',
        'options': <String>[
          'Nice to meet you.',
          'See you tomorrow.',
          'How old are you?',
          'Where are you from?',
        ],
        'correctAnswerIndex': 0,
        'explanation':
            '“Nice to meet you” có nghĩa là '
            '“Rất vui được gặp bạn”.',
        'difficulty': 'medium',
      },
      {
        'question':
            'Chọn từ thích hợp: “___ to our English class.”',
        'options': <String>[
          'Goodbye',
          'Morning',
          'Welcome',
          'Introduce',
        ],
        'correctAnswerIndex': 2,
        'explanation':
            'Câu đúng là “Welcome to our English class.”',
        'difficulty': 'medium',
      },
    ];
  }

  List<Map<String, dynamic>> _familyQuestions() {
    return <Map<String, dynamic>>[
      {
        'question': '“Father” có nghĩa là gì?',
        'options': <String>[
          'Mẹ',
          'Bố',
          'Anh trai',
          'Ông',
        ],
        'correctAnswerIndex': 1,
        'explanation':
            '“Father” có nghĩa là cha hoặc bố.',
        'difficulty': 'easy',
      },
      {
        'question': '“Mother” có nghĩa là gì?',
        'options': <String>[
          'Mẹ',
          'Chị gái',
          'Bà',
          'Em gái',
        ],
        'correctAnswerIndex': 0,
        'explanation':
            '“Mother” là từ tiếng Anh có nghĩa là mẹ.',
        'difficulty': 'easy',
      },
      {
        'question':
            'Từ nào có nghĩa là “anh hoặc em trai”?',
        'options': <String>[
          'Sister',
          'Brother',
          'Father',
          'Grandparent',
        ],
        'correctAnswerIndex': 1,
        'explanation':
            '“Brother” có nghĩa là anh trai hoặc em trai.',
        'difficulty': 'easy',
      },
      {
        'question':
            'Câu “My sister likes reading books” có nghĩa là gì?',
        'options': <String>[
          'Em trai tôi thích đọc sách.',
          'Chị hoặc em gái tôi thích đọc sách.',
          'Mẹ tôi thích mua sách.',
          'Bố tôi đang đọc sách.',
        ],
        'correctAnswerIndex': 1,
        'explanation':
            '“Sister” có nghĩa là chị gái hoặc em gái.',
        'difficulty': 'medium',
      },
      {
        'question': '“Grandparents” chỉ những ai?',
        'options': <String>[
          'Cha mẹ',
          'Anh chị em',
          'Ông bà',
          'Con cái',
        ],
        'correctAnswerIndex': 2,
        'explanation':
            '“Grandparents” có nghĩa là ông bà.',
        'difficulty': 'medium',
      },
    ];
  }

  List<Map<String, dynamic>> _schoolQuestions() {
    return <Map<String, dynamic>>[
      {
        'question': '“Teacher” có nghĩa là gì?',
        'options': <String>[
          'Học sinh',
          'Giáo viên',
          'Hiệu trưởng',
          'Bác sĩ',
        ],
        'correctAnswerIndex': 1,
        'explanation':
            '“Teacher” có nghĩa là giáo viên.',
        'difficulty': 'easy',
      },
      {
        'question': '“Student” có nghĩa là gì?',
        'options': <String>[
          'Học sinh hoặc sinh viên',
          'Giáo viên',
          'Nhân viên',
          'Người quản lý',
        ],
        'correctAnswerIndex': 0,
        'explanation':
            '“Student” có nghĩa là học sinh hoặc sinh viên.',
        'difficulty': 'easy',
      },
      {
        'question':
            'Từ tiếng Anh nào có nghĩa là “phòng học”?',
        'options': <String>[
          'Bedroom',
          'Bathroom',
          'Classroom',
          'Meeting room',
        ],
        'correctAnswerIndex': 2,
        'explanation':
            '“Classroom” có nghĩa là phòng học.',
        'difficulty': 'easy',
      },
      {
        'question':
            'Chọn từ thích hợp: “I write new words in my ___.”',
        'options': <String>[
          'notebook',
          'classroom',
          'teacher',
          'homework',
        ],
        'correctAnswerIndex': 0,
        'explanation':
            '“Notebook” là quyển vở dùng để ghi chép.',
        'difficulty': 'medium',
      },
      {
        'question': '“Homework” có nghĩa là gì?',
        'options': <String>[
          'Bài kiểm tra',
          'Bài giảng',
          'Bài tập về nhà',
          'Sách giáo khoa',
        ],
        'correctAnswerIndex': 2,
        'explanation':
            '“Homework” có nghĩa là bài tập về nhà.',
        'difficulty': 'medium',
      },
    ];
  }

  List<Map<String, dynamic>> _foodQuestions() {
    return <Map<String, dynamic>>[
      {
        'question': '“Rice” có nghĩa là gì?',
        'options': <String>[
          'Bánh mì',
          'Cơm hoặc gạo',
          'Nước',
          'Rau củ',
        ],
        'correctAnswerIndex': 1,
        'explanation':
            '“Rice” có nghĩa là cơm hoặc gạo.',
        'difficulty': 'easy',
      },
      {
        'question': '“Bread” có nghĩa là gì?',
        'options': <String>[
          'Bánh mì',
          'Thịt',
          'Sữa',
          'Trái cây',
        ],
        'correctAnswerIndex': 0,
        'explanation':
            '“Bread” có nghĩa là bánh mì.',
        'difficulty': 'easy',
      },
      {
        'question':
            'Chọn từ thích hợp: “Please drink more ___.”',
        'options': <String>[
          'rice',
          'bread',
          'water',
          'vegetable',
        ],
        'correctAnswerIndex': 2,
        'explanation':
            'Câu đúng là “Please drink more water.”',
        'difficulty': 'medium',
      },
      {
        'question': '“Vegetable” có nghĩa là gì?',
        'options': <String>[
          'Thức uống',
          'Rau củ',
          'Thịt',
          'Bánh ngọt',
        ],
        'correctAnswerIndex': 1,
        'explanation':
            '“Vegetable” có nghĩa là rau củ.',
        'difficulty': 'easy',
      },
      {
        'question':
            'Từ “Delicious” dùng để mô tả điều gì?',
        'options': <String>[
          'Món ăn ngon',
          'Món ăn nóng',
          'Món ăn đắt',
          'Món ăn cay',
        ],
        'correctAnswerIndex': 0,
        'explanation':
            '“Delicious” là tính từ có nghĩa là ngon.',
        'difficulty': 'medium',
      },
    ];
  }

  List<Map<String, dynamic>> _dailyRoutineQuestions() {
    return <Map<String, dynamic>>[
      {
        'question': '“Wake up” có nghĩa là gì?',
        'options': <String>[
          'Đi ngủ',
          'Thức dậy',
          'Đi làm',
          'Ăn sáng',
        ],
        'correctAnswerIndex': 1,
        'explanation':
            '“Wake up” có nghĩa là thức dậy.',
        'difficulty': 'easy',
      },
      {
        'question': '“Have breakfast” có nghĩa là gì?',
        'options': <String>[
          'Ăn sáng',
          'Ăn trưa',
          'Ăn tối',
          'Uống nước',
        ],
        'correctAnswerIndex': 0,
        'explanation':
            '“Have breakfast” có nghĩa là ăn sáng.',
        'difficulty': 'easy',
      },
      {
        'question':
            'Chọn câu có nghĩa “Tôi đi làm bằng xe máy”.',
        'options': <String>[
          'I go to school by bus.',
          'I go to work by motorbike.',
          'I walk to the market.',
          'I study English at home.',
        ],
        'correctAnswerIndex': 1,
        'explanation':
            '“I go to work by motorbike” có nghĩa là '
            '“Tôi đi làm bằng xe máy”.',
        'difficulty': 'medium',
      },
      {
        'question':
            'Từ nào có nghĩa là “học tập”?',
        'options': <String>[
          'Sleep',
          'Work',
          'Study',
          'Wake',
        ],
        'correctAnswerIndex': 2,
        'explanation':
            '“Study” là động từ có nghĩa là học tập.',
        'difficulty': 'easy',
      },
      {
        'question': '“Go to bed” có nghĩa là gì?',
        'options': <String>[
          'Rời khỏi nhà',
          'Đi làm',
          'Đi ngủ',
          'Dọn giường',
        ],
        'correctAnswerIndex': 2,
        'explanation':
            '“Go to bed” có nghĩa là đi ngủ.',
        'difficulty': 'medium',
      },
    ];
  }

  List<Map<String, dynamic>> _defaultQuestions() {
    return <Map<String, dynamic>>[
      {
        'question': '“Learn” có nghĩa là gì?',
        'options': <String>[
          'Học',
          'Nói',
          'Viết',
          'Nghe',
        ],
        'correctAnswerIndex': 0,
        'explanation':
            '“Learn” là động từ có nghĩa là học.',
        'difficulty': 'easy',
      },
      {
        'question': '“Practice” có nghĩa là gì?',
        'options': <String>[
          'Quên',
          'Luyện tập',
          'Nghỉ ngơi',
          'Kiểm tra',
        ],
        'correctAnswerIndex': 1,
        'explanation':
            '“Practice” có nghĩa là luyện tập.',
        'difficulty': 'easy',
      },
      {
        'question': '“Remember” có nghĩa là gì?',
        'options': <String>[
          'Ghi nhớ',
          'Phát âm',
          'Giải thích',
          'Lặp lại',
        ],
        'correctAnswerIndex': 0,
        'explanation':
            '“Remember” có nghĩa là ghi nhớ.',
        'difficulty': 'easy',
      },
      {
        'question':
            'Chọn từ thích hợp: “Please ___ English in class.”',
        'options': <String>[
          'sleep',
          'speak',
          'forget',
          'close',
        ],
        'correctAnswerIndex': 1,
        'explanation':
            'Câu đúng là “Please speak English in class.”',
        'difficulty': 'medium',
      },
      {
        'question': '“Understand” có nghĩa là gì?',
        'options': <String>[
          'Hiểu',
          'Đọc',
          'Hỏi',
          'Trả lời',
        ],
        'correctAnswerIndex': 0,
        'explanation':
            '“Understand” có nghĩa là hiểu.',
        'difficulty': 'medium',
      },
    ];
  }
}