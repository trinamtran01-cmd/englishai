import 'package:flutter/material.dart';

/// Lưới thẻ tự co giãn số cột theo chiều rộng khả dụng: màn hình
/// rộng (web) nhiều cột hơn, hẹp (mobile) ít cột hơn.
///
/// Có 2 cách tính chiều cao thẻ, chọn 1 trong 2:
/// - [cardHeight]: chiều cao cố định (dùng cho thẻ chỉ có khối
///   icon/màu nền, không phụ thuộc chiều rộng cột).
/// - [thumbnailAspectRatio] + [contentHeight]: dùng khi thẻ có ảnh
///   thật cần giữ đúng tỉ lệ khung (ví dụ 16:9) - chiều cao ảnh khi
///   đó phụ thuộc chiều rộng cột, nên chiều cao thẻ được tính lại
///   theo đúng chiều rộng cột hiện tại (`columnWidth / aspectRatio +
///   contentHeight`) để phần nội dung bên dưới luôn đủ chỗ, không bị
///   tràn (overflow) khi cột giãn rộng ra ở màn hình lớn.
class ResponsiveCardGrid extends StatelessWidget {
  const ResponsiveCardGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.cardHeight,
    this.thumbnailAspectRatio,
    this.contentHeight,
    this.spacing = 14,
    this.wideBreakpoint = 700,
    this.padding = const EdgeInsets.fromLTRB(20, 20, 20, 32),
    this.physics,
  }) : assert(
         cardHeight != null ||
             (thumbnailAspectRatio != null && contentHeight != null),
         'Truyền cardHeight, hoặc cả thumbnailAspectRatio và contentHeight.',
       );

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final double? cardHeight;
  final double? thumbnailAspectRatio;
  final double? contentHeight;
  final double spacing;
  final double wideBreakpoint;
  final EdgeInsets padding;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double availableWidth = constraints.maxWidth;
        final int crossAxisCount = availableWidth >= wideBreakpoint ? 3 : 2;

        final double columnWidth =
            (availableWidth - spacing * (crossAxisCount - 1)) /
                crossAxisCount;

        final double resolvedCardHeight = thumbnailAspectRatio != null
            ? (columnWidth / thumbnailAspectRatio!) + contentHeight!
            : cardHeight!;

        final double childAspectRatio = columnWidth / resolvedCardHeight;

        return GridView.builder(
          padding: padding,
          physics: physics,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: spacing,
            crossAxisSpacing: spacing,
            childAspectRatio: childAspectRatio,
          ),
          itemCount: itemCount,
          itemBuilder: itemBuilder,
        );
      },
    );
  }
}
