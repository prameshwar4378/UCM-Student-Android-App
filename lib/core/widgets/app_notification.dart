import 'package:flutter/material.dart';

enum AppNotificationType { success, error, warning, info }

extension on AppNotificationType {
  Color get color => switch (this) {
    AppNotificationType.success => const Color(0xFF15803D),
    AppNotificationType.error => const Color(0xFFBE123C),
    AppNotificationType.warning => const Color(0xFFD97706),
    AppNotificationType.info => const Color(0xFF1D4ED8),
  };

  Color get softColor => switch (this) {
    AppNotificationType.success => const Color(0xFFDCFCE7),
    AppNotificationType.error => const Color(0xFFFFE4E6),
    AppNotificationType.warning => const Color(0xFFFFF7D6),
    AppNotificationType.info => const Color(0xFFDBEAFE),
  };

  IconData get icon => switch (this) {
    AppNotificationType.success => Icons.check_circle_rounded,
    AppNotificationType.error => Icons.error_rounded,
    AppNotificationType.warning => Icons.warning_amber_rounded,
    AppNotificationType.info => Icons.info_rounded,
  };

  String get defaultTitle => switch (this) {
    AppNotificationType.success => 'Success',
    AppNotificationType.error => 'Something went wrong',
    AppNotificationType.warning => 'Attention',
    AppNotificationType.info => 'Information',
  };
}

void showAppNotification(
  BuildContext context, {
  required String message,
  String? title,
  AppNotificationType type = AppNotificationType.info,
  Duration duration = const Duration(seconds: 4),
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.fromLTRB(14, 12, 14, 104),
        padding: EdgeInsets.zero,
        duration: duration,
        content: _NotificationCard(
          title: title ?? type.defaultTitle,
          message: message,
          type: type,
          onDismiss: messenger.hideCurrentSnackBar,
        ),
      ),
    );
}

Future<void> showAppMessageDialog(
  BuildContext context, {
  required String title,
  required String message,
  AppNotificationType type = AppNotificationType.info,
  String actionLabel = 'Done',
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      backgroundColor: Colors.transparent,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 440),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: type.color.withValues(alpha: 0.18)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x260F172A),
              blurRadius: 36,
              offset: Offset(0, 18),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: type.softColor,
                borderRadius: BorderRadius.circular(21),
              ),
              child: Icon(type.icon, color: type.color, size: 34),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            Flexible(
              child: SingleChildScrollView(
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 14.5,
                    height: 1.55,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: type.color,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(actionLabel),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.title,
    required this.message,
    required this.type,
    required this.onDismiss,
  });

  final String title;
  final String message;
  final AppNotificationType type;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 540),
      padding: const EdgeInsets.fromLTRB(14, 13, 8, 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: type.color.withValues(alpha: 0.22)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x290F172A),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: type.softColor,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(type.icon, color: type.color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF475569),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Dismiss',
            onPressed: onDismiss,
            icon: const Icon(
              Icons.close_rounded,
              size: 20,
              color: Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }
}
