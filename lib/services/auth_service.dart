import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Quản lý các chức năng:
/// - Đăng ký
/// - Đăng nhập
/// - Đăng xuất
/// - Theo dõi trạng thái đăng nhập
/// - Lưu thông tin người dùng vào Firestore
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Theo dõi trạng thái đăng nhập của người dùng.
  ///
  /// Khi người dùng đăng nhập hoặc đăng xuất,
  /// stream này sẽ tự động gửi trạng thái mới.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Lấy người dùng hiện đang đăng nhập.
  ///
  /// Nếu chưa đăng nhập thì kết quả là null.
  User? get currentUser => _auth.currentUser;

  /// Đăng ký tài khoản mới bằng email và mật khẩu.
  ///
  /// Trả về:
  /// - null: đăng ký thành công.
  /// - String: nội dung lỗi nếu đăng ký thất bại.
  Future<String?> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final String cleanName = name.trim();
      final String cleanEmail = email.trim().toLowerCase();

      final UserCredential result =
          await _auth.createUserWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );

      final User? user = result.user;

      if (user == null) {
        return 'Không thể tạo tài khoản. Vui lòng thử lại.';
      }

      // Lưu tên hiển thị vào Firebase Authentication.
      await user.updateDisplayName(cleanName);

      // Lưu thông tin người dùng vào Firestore.
      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'name': cleanName,
        'email': cleanEmail,
        'role': 'student',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return null;
    } on FirebaseAuthException catch (e) {
      return _mapErrorMessage(e.code);
    } on FirebaseException catch (e) {
      return 'Không thể lưu thông tin người dùng (${e.code}).';
    } catch (e) {
      return 'Đã có lỗi xảy ra. Vui lòng thử lại.';
    }
  }

  /// Đăng nhập bằng email và mật khẩu.
  ///
  /// Trả về:
  /// - null: đăng nhập thành công.
  /// - String: nội dung lỗi nếu đăng nhập thất bại.
  Future<String?> login({
    required String email,
    required String password,
  }) async {
    try {
      final String cleanEmail = email.trim().toLowerCase();

      await _auth.signInWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );

      return null;
    } on FirebaseAuthException catch (e) {
      return _mapErrorMessage(e.code);
    } catch (e) {
      return 'Đã có lỗi xảy ra. Vui lòng thử lại.';
    }
  }

  /// Đăng xuất tài khoản hiện tại.
  Future<void> logout() async {
    await _auth.signOut();
  }

  /// Chuyển mã lỗi Firebase thành thông báo tiếng Việt.
  String _mapErrorMessage(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'Email này đã được đăng ký.';

      case 'invalid-email':
        return 'Địa chỉ email không hợp lệ.';

      case 'weak-password':
        return 'Mật khẩu quá yếu. Mật khẩu cần ít nhất 6 ký tự.';

      case 'user-disabled':
        return 'Tài khoản này đã bị vô hiệu hóa.';

      case 'user-not-found':
        return 'Không tìm thấy tài khoản với email này.';

      case 'wrong-password':
        return 'Mật khẩu không chính xác.';

      case 'invalid-credential':
        return 'Email hoặc mật khẩu không đúng.';

      case 'too-many-requests':
        return 'Bạn đã thử quá nhiều lần. Vui lòng thử lại sau.';

      case 'operation-not-allowed':
        return 'Phương thức đăng nhập Email/Password chưa được bật.';

      case 'network-request-failed':
        return 'Không có kết nối mạng. Vui lòng kiểm tra lại Internet.';

      case 'account-exists-with-different-credential':
        return 'Email này đã được đăng ký bằng phương thức khác.';

      default:
        return 'Đã xảy ra lỗi Firebase. Mã lỗi: $code';
    }
  }
}