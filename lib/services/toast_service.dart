import 'package:equb/ui/theme/theme_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

enum ToastType { success, error, warning, info }

class ToastService {
  static void show(
    BuildContext context,
    String message, {
    ToastType type = ToastType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    if (!context.mounted) return;

    void present() {
      if (!context.mounted) return;

      final scaffoldMessenger = ScaffoldMessenger.maybeOf(context);
      if (scaffoldMessenger == null) return;

      final isDark = Theme.of(context).brightness == Brightness.dark;

      // Clear previous snackbars immediately
      scaffoldMessenger.removeCurrentSnackBar();

    Color backgroundColor;
    IconData icon;
    Color iconColor;
    Color textColor = Colors.white;

    switch (type) {
      case ToastType.success:
        backgroundColor = AppColors.primary;
        icon = Icons.check_circle_outline;
        iconColor = Colors.black;
        textColor = Colors.black;
        break;
      case ToastType.error:
        backgroundColor = AppColors.error;
        icon = Icons.error_outline;
        iconColor = Colors.white;
        textColor = Colors.white;
        break;
      case ToastType.warning:
        backgroundColor = AppColors.warning;
        icon = Icons.warning_amber_outlined;
        iconColor = Colors.black;
        textColor = Colors.black;
        break;
      case ToastType.info:
        backgroundColor = isDark ? AppColors.surfaceBrightDark : Colors.black;
        icon = Icons.info_outline;
        iconColor = AppColors.primary;
        textColor = Colors.white;
        break;
    }

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icon, color: iconColor, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: backgroundColor,
          behavior: SnackBarBehavior.floating,
          duration: duration,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
          elevation: 6,
        ),
      );
    }

    final phase = SchedulerBinding.instance.schedulerPhase;
    final isSafeNow =
        phase == SchedulerPhase.idle || phase == SchedulerPhase.postFrameCallbacks;

    if (isSafeNow) {
      present();
      return;
    }

    SchedulerBinding.instance.addPostFrameCallback((_) => present());
  }

  static void success(BuildContext context, String message) =>
      show(context, message, type: ToastType.success);

  static void error(BuildContext context, String message) =>
      show(context, message, type: ToastType.error);

  static void warning(BuildContext context, String message) =>
      show(context, message, type: ToastType.warning);

  static void info(BuildContext context, String message) =>
      show(context, message, type: ToastType.info);
}
