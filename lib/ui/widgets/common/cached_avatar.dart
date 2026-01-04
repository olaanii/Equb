import 'package:cached_network_image/cached_network_image.dart';
import 'package:equb/ui/theme/theme_constants.dart';
import 'package:flutter/material.dart';

class CachedAvatar extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final double radius;
  final double fontSize;
  final Color? backgroundColor;
  final Color? textColor;

  const CachedAvatar({
    super.key,
    this.imageUrl,
    required this.name,
    this.radius = 20,
    this.fontSize = 16,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: imageUrl!,
        imageBuilder:
            (context, imageProvider) => CircleAvatar(
              radius: radius,
              backgroundImage: imageProvider,
              backgroundColor: backgroundColor ?? Colors.grey[800],
            ),
        placeholder:
            (context, url) => CircleAvatar(
              radius: radius,
              backgroundColor: backgroundColor ?? Colors.grey[800],
              child: SizedBox(
                width: radius,
                height: radius,
                child: const CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        errorWidget: (context, url, error) => _buildInitials(),
      );
    }

    return _buildInitials();
  }

  Widget _buildInitials() {
    final initials = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?';
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? AppColors.primary,
      child: Text(
        initials,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: textColor ?? Colors.black,
        ),
      ),
    );
  }
}
