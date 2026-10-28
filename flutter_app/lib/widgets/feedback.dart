// Status chips, banners, empty states and loading blocks.

import 'package:flutter/material.dart';

import '../core/labels.dart';
import '../theme/palette.dart';
import 'inputs.dart';

/// A small status pill: a tinted fill and hairline border in the tone colour (the web app's status badges).
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, required this.tone});

  final String label;
  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    final Color color = p.toneColor(tone);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 3),
        child: Text(
          label,
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

enum NoticeKind { info, success, warning, error }

/// A message box with an icon, used for errors, confirmations and hints (rounded 16, tinted fill and border).
class NoticeBanner extends StatelessWidget {
  const NoticeBanner({
    super.key,
    required this.message,
    this.kind = NoticeKind.info,
    this.onRetry,
    this.onDismiss,
    this.retryLabel = 'إعادة المحاولة',
  });

  final String message;
  final NoticeKind kind;
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    final Color color;
    final Color ink;
    final IconData icon;
    switch (kind) {
      case NoticeKind.success:
        color = p.ok;
        ink = p.ok;
        icon = Icons.check_circle_outline_rounded;
      case NoticeKind.warning:
        color = p.warn;
        ink = p.warn;
        icon = Icons.warning_amber_rounded;
      case NoticeKind.error:
        color = p.err;
        ink = p.errText;
        icon = Icons.error_outline_rounded;
      case NoticeKind.info:
        color = p.accent;
        ink = p.text.withValues(alpha: 0.85);
        icon = Icons.info_outline_rounded;
    }
    final VoidCallback? retry = onRetry;
    final VoidCallback? dismiss = onDismiss;
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 6, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(icon, color: kind == NoticeKind.info ? p.primary : ink, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    message,
                    style: TextStyle(color: ink, fontSize: 14, height: 1.5),
                  ),
                ),
              ),
              if (retry != null)
                TextButton(
                  onPressed: retry,
                  child: Text(retryLabel, style: TextStyle(color: ink, fontWeight: FontWeight.w700)),
                ),
              if (dismiss != null)
                IconButton(
                  onPressed: dismiss,
                  tooltip: 'إغلاق',
                  icon: Icon(Icons.close_rounded, color: p.muted, size: 20),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown when a list has nothing to display. The action (if any) tells the user what to do next.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    final String? text = message;
    final String? label = actionLabel;
    final VoidCallback? action = onAction;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: p.accent.withValues(alpha: 0.12),
              border: Border.all(color: p.accent.withValues(alpha: 0.25)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Icon(icon, size: 34, color: p.primary),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(color: p.text, fontSize: 17, fontWeight: FontWeight.w700),
          ),
          if (text != null) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(color: p.muted, fontSize: 14, height: 1.55),
            ),
          ],
          if (label != null && action != null) ...<Widget>[
            const SizedBox(height: 18),
            PrimaryButton(label: label, onPressed: action, compact: true),
          ],
        ],
      ),
    );
  }
}

/// A centred spinner with a short explanation (the web app's blue ring spinner and caption).
class LoadingBlock extends StatelessWidget {
  const LoadingBlock({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          const SizedBox(height: 14),
          Text(message, style: TextStyle(color: p.muted, fontSize: 13)),
        ],
      ),
    );
  }
}
