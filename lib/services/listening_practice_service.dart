import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/listening_attempt.dart';

/// Quản lý kết quả bước nghe & điền từ trên Firebase Firestore.
///
/// Collection sử dụng: listening_attempts
class ListeningPracticeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>>
      get _attemptsCollection {
    return _firestore.collection('listening_attempts');
  }

  /// Lấy tài khoản hiện đang đăng nhập.
  User _requireCurrentUser() {
    final User? user = _auth.currentUser;

    if (user == null) {
      throw StateError(
        'Bạn cần đăng nhập để luyện nghe & điền từ.',
      );
    }

    return user;
  }

  /// So khớp các từ người dùng đã gõ với transcript, tính điểm và
  /// lưu kết quả vào Firestore.
  ///
  /// Một từ được tính đúng khi (sau khi chuẩn hóa lowercase và trim)
  /// trùng với một từ có trong [transcriptWords].
  Future<ListeningAttempt> submitAttempt(
    String videoId,
    List<String> typedWords,
    List<String> transcriptWords,
  ) async {
    final User user = _requireCurrentUser();

    final String cleanVideoId = videoId.trim();

    if (cleanVideoId.isEmpty) {
      throw ArgumentError(
        'ID bài luyện nghe không được để trống.',
      );
    }

    final Set<String> normalizedTranscript = transcriptWords
        .map((String word) => word.trim().toLowerCase())
        .where((String word) => word.isNotEmpty)
        .toSet();

    final List<String> normalizedTypedWords = typedWords
        .map((String word) => word.trim().toLowerCase())
        .where((String word) => word.isNotEmpty)
        .toList();

    int correctCount = 0;
    int incorrectCount = 0;

    for (final String word in normalizedTypedWords) {
      if (normalizedTranscript.contains(word)) {
        correctCount++;
      } else {
        incorrectCount++;
      }
    }

    final int totalTyped = normalizedTypedWords.length;

    final double score = totalTyped == 0
        ? 0
        : (correctCount / totalTyped) * 100;

    final ListeningAttempt attempt = ListeningAttempt(
      id: '',
      userId: user.uid,
      videoId: cleanVideoId,
      typedWords: normalizedTypedWords,
      correctCount: correctCount,
      incorrectCount: incorrectCount,
      score: score,
      createdAt: DateTime.now(),
    );

    try {
      final DocumentReference<Map<String, dynamic>> document =
          await _attemptsCollection.add(attempt.toMap());

      final DocumentSnapshot<Map<String, dynamic>>
          savedDocument = await document.get();

      return ListeningAttempt.fromFirestore(savedDocument);
    } on FirebaseException catch (error) {
      throw Exception(
        'Không thể lưu kết quả luyện nghe: ${error.code}',
      );
    }
  }

  /// Theo dõi lịch sử luyện nghe của người dùng hiện tại.
  ///
  /// Sắp xếp mới nhất trước, thực hiện trong Flutter để không
  /// yêu cầu composite index trên Firebase.
  Stream<List<ListeningAttempt>> getCurrentUserAttempts() {
    final User? user = _auth.currentUser;

    if (user == null) {
      return Stream<List<ListeningAttempt>>.value(
        <ListeningAttempt>[],
      );
    }

    return _attemptsCollection
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .map(
      (QuerySnapshot<Map<String, dynamic>> snapshot) {
        final List<ListeningAttempt> attempts = snapshot.docs
            .map(ListeningAttempt.fromFirestore)
            .toList();

        attempts.sort(
          (
            ListeningAttempt first,
            ListeningAttempt second,
          ) {
            final DateTime firstDate = first.createdAt ??
                DateTime.fromMillisecondsSinceEpoch(0);

            final DateTime secondDate = second.createdAt ??
                DateTime.fromMillisecondsSinceEpoch(0);

            return secondDate.compareTo(firstDate);
          },
        );

        return attempts;
      },
    );
  }
}
