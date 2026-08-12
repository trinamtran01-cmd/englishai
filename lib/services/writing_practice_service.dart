import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/writing_attempt.dart';

/// Ghi nhận lần nộp bài của học viên cho một đề Luyện Viết AI.
///
/// Collection sử dụng: writing_attempts
class WritingPracticeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _attemptsCollection {
    return _firestore.collection('writing_attempts');
  }

  /// Lấy tài khoản hiện đang đăng nhập.
  User _requireCurrentUser() {
    final User? user = _auth.currentUser;

    if (user == null) {
      throw StateError(
        'Bạn cần đăng nhập để nộp bài Luyện Viết.',
      );
    }

    return user;
  }

  /// Đếm số từ trong bài viết, tách theo khoảng trắng.
  int _countWords(String text) {
    final Iterable<RegExpMatch> matches =
        RegExp(r'\S+').allMatches(text.trim());

    return matches.length;
  }

  /// Lưu lần nộp bài của học viên vào Firestore.
  ///
  /// Trả về đối tượng WritingAttempt vừa được lưu.
  Future<WritingAttempt> submitAttempt(
    String taskId,
    String userText,
  ) async {
    final User user = _requireCurrentUser();

    final String cleanTaskId = taskId.trim();

    if (cleanTaskId.isEmpty) {
      throw ArgumentError('ID đề bài không được để trống.');
    }

    if (userText.trim().isEmpty) {
      throw ArgumentError('Bài viết không được để trống.');
    }

    final WritingAttempt attempt = WritingAttempt(
      id: '',
      userId: user.uid,
      taskId: cleanTaskId,
      userText: userText,
      wordCount: _countWords(userText),
      createdAt: DateTime.now(),
    );

    try {
      final DocumentReference<Map<String, dynamic>> document =
          await _attemptsCollection.add(attempt.toMap());

      final DocumentSnapshot<Map<String, dynamic>>
          savedDocument = await document.get();

      return WritingAttempt.fromFirestore(savedDocument);
    } on FirebaseException catch (error) {
      throw Exception(
        'Không thể lưu bài làm: ${error.code}',
      );
    }
  }
}
