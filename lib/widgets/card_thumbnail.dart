import 'package:flutter/material.dart';

/// Khung ảnh minh họa đồng nhất cho các thẻ trong lưới (`GridView`).
///
/// Luôn giữ đúng [aspectRatio] bất kể chiều rộng cột thay đổi theo
/// màn hình (responsive), nên mọi thẻ trong cùng 1 lưới có khung ảnh
/// cùng tỉ lệ, cùng cách căn — không còn thẻ nào bị lệch/méo khác
/// thẻ khác. Hiện cùng 1 placeholder khi chưa có URL, đang tải, hoặc
/// tải lỗi, để tránh layout nhảy giữa các trạng thái.
class CardThumbnail extends StatelessWidget {
  const CardThumbnail({
    super.key,
    required this.imageUrl,
    required this.placeholderIcon,
    required this.placeholderColor,
    this.aspectRatio = 16 / 9,
    this.fit = BoxFit.cover,
    this.backgroundColor,
  });

  /// URL ảnh; chuỗi rỗng hiển thị placeholder ngay (không cần chờ
  /// tải mạng).
  final String imageUrl;

  final IconData placeholderIcon;
  final Color placeholderColor;

  /// Tỉ lệ khung ảnh, mặc định 16:9 (chuẩn cho ảnh thumbnail).
  final double aspectRatio;

  /// Cách ảnh lấp đầy khung. Dùng [BoxFit.cover] cho ảnh
  /// thumbnail/ảnh chụp thông thường; dùng [BoxFit.contain] (kèm
  /// [backgroundColor] trắng) cho ảnh biểu đồ/số liệu cần giữ
  /// nguyên vẹn, không bị cắt mất chi tiết.
  final BoxFit fit;

  /// Màu nền phía sau ảnh khi dùng [BoxFit.contain] (ảnh không lấp
  /// đầy hết khung). Bỏ trống nếu dùng [BoxFit.cover].
  final Color? backgroundColor;

  Widget _buildPlaceholder() {
    return Container(
      color: placeholderColor.withValues(alpha: 0.12),
      alignment: Alignment.center,
      child: Icon(
        placeholderIcon,
        color: placeholderColor,
        size: 36,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String cleanUrl = imageUrl.trim();

    return AspectRatio(
      aspectRatio: aspectRatio,
      child: cleanUrl.isEmpty
          ? _buildPlaceholder()
          : ColoredBox(
              color: backgroundColor ?? Colors.transparent,
              child: Image.network(
                cleanUrl,
                fit: fit,
                alignment: Alignment.center,
                errorBuilder: (
                  BuildContext context,
                  Object error,
                  StackTrace? stackTrace,
                ) {
                  return _buildPlaceholder();
                },
                loadingBuilder: (
                  BuildContext context,
                  Widget child,
                  ImageChunkEvent? loadingProgress,
                ) {
                  if (loadingProgress == null) {
                    return child;
                  }

                  return _buildPlaceholder();
                },
              ),
            ),
    );
  }
}
