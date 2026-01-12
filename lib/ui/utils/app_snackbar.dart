import 'package:equb/ui/theme/theme_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class AppSnackbar {
  static final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  static void showError(String message) {
    _show(message, isError: true);
  }

  static void showInfo(String message) {
    _show(message, isError: false);
  }

  static void _show(String message, {required bool isError}) {
    final trimmed = message.trim();
    if (trimmed.isEmpty) return;

    final safe = _truncate(trimmed, 260);

    void present() {
      final messenger = messengerKey.currentState;
      if (messenger == null) return;

      final context = messenger.context;
      final scheme = Theme.of(context).colorScheme;

      try {
        messenger
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              margin: AppSpacing.pagePaddingMobile,
              backgroundColor: isError ? scheme.error : scheme.surface,
              content: Text(
                safe,
                style: TextStyle(
                  color: isError ? scheme.onError : scheme.onSurface,
                ),
              ),
            ),
          );
      } catch (_) {
        // If called during an unsafe frame phase or while the tree is rebuilding,
        // ignore instead of crashing the app.
      }
    }

    final phase = SchedulerBinding.instance.schedulerPhase;
    final isSafeNow =
        phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks;

    if (isSafeNow) {
      present();
      return;
    }

    SchedulerBinding.instance.addPostFrameCallback((_) => present());
  }

  static String _truncate(String value, int maxLen) {
    if (value.length <= maxLen) return value;
    return '${value.substring(0, maxLen - 1)}…';
  }
}
