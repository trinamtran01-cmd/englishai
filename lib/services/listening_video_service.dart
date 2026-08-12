import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/listening_video.dart';

/// Quản lý dữ liệu bài luyện nghe & nói trên Firebase Firestore.
///
/// Collection sử dụng: listening_videos
class ListeningVideoService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>>
      get _videosCollection {
    return _firestore.collection('listening_videos');
  }

  /// Theo dõi danh sách bài luyện nghe.
  ///
  /// Sắp xếp mới nhất trước, thực hiện trong Flutter để không
  /// yêu cầu composite index trên Firebase.
  Stream<List<ListeningVideo>> getAllVideos() {
    return _videosCollection.snapshots().map(
      (QuerySnapshot<Map<String, dynamic>> snapshot) {
        final List<ListeningVideo> videos = snapshot.docs
            .map(ListeningVideo.fromFirestore)
            .toList();

        videos.sort(
          (ListeningVideo first, ListeningVideo second) {
            final DateTime firstDate = first.createdAt ??
                DateTime.fromMillisecondsSinceEpoch(0);

            final DateTime secondDate = second.createdAt ??
                DateTime.fromMillisecondsSinceEpoch(0);

            return secondDate.compareTo(firstDate);
          },
        );

        return videos;
      },
    );
  }

  /// Lấy toàn bộ danh sách bài luyện nghe một lần.
  ///
  /// Dùng cho màn hình quản trị (tải lại thủ công sau khi
  /// thêm/sửa/xóa) thay vì lắng nghe stream liên tục, để tránh màn
  /// hình phía sau tự rebuild trong lúc dialog thêm/sửa đang đóng.
  Future<List<ListeningVideo>> getAllVideosOnce() async {
    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot =
          await _videosCollection.get();

      final List<ListeningVideo> videos = snapshot.docs
          .map(ListeningVideo.fromFirestore)
          .toList();

      videos.sort(
        (ListeningVideo first, ListeningVideo second) {
          final DateTime firstDate = first.createdAt ??
              DateTime.fromMillisecondsSinceEpoch(0);

          final DateTime secondDate = second.createdAt ??
              DateTime.fromMillisecondsSinceEpoch(0);

          return secondDate.compareTo(firstDate);
        },
      );

      return videos;
    } on FirebaseException catch (error) {
      throw Exception(
        'Không thể tải danh sách bài luyện nghe: ${error.code}',
      );
    }
  }

  /// Lấy thông tin một bài luyện nghe theo ID.
  ///
  /// Trả về null nếu bài luyện nghe không tồn tại.
  Future<ListeningVideo?> getVideoById(String id) async {
    final String cleanId = id.trim();

    if (cleanId.isEmpty) {
      throw ArgumentError(
        'ID bài luyện nghe không được để trống.',
      );
    }

    try {
      final DocumentSnapshot<Map<String, dynamic>> document =
          await _videosCollection.doc(cleanId).get();

      if (!document.exists) {
        return null;
      }

      return ListeningVideo.fromFirestore(document);
    } on FirebaseException catch (error) {
      throw Exception(
        'Không thể tải thông tin bài luyện nghe: '
        '${error.code}',
      );
    }
  }

  /// Thêm một bài luyện nghe mới.
  ///
  /// Trả về ID của bài luyện nghe vừa được tạo.
  Future<String> addVideo(ListeningVideo video) async {
    if (!video.isValid) {
      throw ArgumentError(
        'Bài luyện nghe phải có title và youtubeVideoId.',
      );
    }

    try {
      final DocumentReference<Map<String, dynamic>> document =
          await _videosCollection.add(video.toMap());

      return document.id;
    } on FirebaseException catch (error) {
      throw Exception(
        'Không thể thêm bài luyện nghe: ${error.code}',
      );
    }
  }

  /// Cập nhật thông tin một bài luyện nghe.
  Future<void> updateVideo(ListeningVideo video) async {
    final String cleanId = video.id.trim();

    if (cleanId.isEmpty) {
      throw ArgumentError(
        'ID bài luyện nghe không được để trống.',
      );
    }

    if (!video.isValid) {
      throw ArgumentError(
        'Bài luyện nghe phải có title và youtubeVideoId.',
      );
    }

    try {
      final Map<String, dynamic> data = video.toMap();

      // Không thay đổi thời gian tạo khi cập nhật.
      data.remove('createdAt');

      await _videosCollection.doc(cleanId).update(data);
    } on FirebaseException catch (error) {
      throw Exception(
        'Không thể cập nhật bài luyện nghe: ${error.code}',
      );
    }
  }

  /// Kiểm tra collection đã có bài luyện nghe nào chưa.
  Future<bool> hasVideos() async {
    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot =
          await _videosCollection.limit(1).get();

      return snapshot.docs.isNotEmpty;
    } on FirebaseException catch (error) {
      throw Exception(
        'Không thể kiểm tra dữ liệu bài luyện nghe: '
        '${error.code}',
      );
    }
  }

  /// Xóa một bài luyện nghe khỏi Firestore.
  Future<void> deleteVideo(String id) async {
    final String cleanId = id.trim();

    if (cleanId.isEmpty) {
      throw ArgumentError(
        'ID bài luyện nghe không được để trống.',
      );
    }

    try {
      await _videosCollection.doc(cleanId).delete();
    } on FirebaseException catch (error) {
      throw Exception(
        'Không thể xóa bài luyện nghe: ${error.code}',
      );
    }
  }
}
