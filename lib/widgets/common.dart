import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/models.dart';
import '../services/errors.dart';

// ───────────────── Layout ─────────────────

/// Keeps content at a comfortable width in the middle of wide screens.
class MaxWidth extends StatelessWidget {
  const MaxWidth({super.key, this.maxWidth = kMaxContentWidth, required this.child});

  final double maxWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    // take only the child's height, so it also works in bottom bars and other loose slots
    heightFactor: 1,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}

/// Rounded, softly shadowed surface with an ink ripple (same as the store app).
class AppSurface extends StatelessWidget {
  const AppSurface({
    super.key,
    required this.child,
    this.onTap,
    this.radius = 20,
    this.color,
    this.elevation = 2,
    this.border,
    this.padding,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double radius;
  final Color? color;
  final double elevation;
  final BorderSide? border;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final content = padding == null ? child : Padding(padding: padding!, child: child);
    return Material(
      color: color ?? context.extra.card,
      surfaceTintColor: Colors.transparent,
      elevation: elevation,
      shadowColor: Colors.black.withValues(alpha: context.extra.isDark ? 0.6 : 0.25),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius), side: border ?? BorderSide.none),
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
  }
}

/// Gold-accented section title.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
    child: Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(color: context.extra.gold, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(title, style: context.text.titleLarge)),
        ?trailing,
      ],
    ),
  );
}

/// Screen title row used at the top of each tab.
class PageHeader extends StatelessWidget {
  const PageHeader({super.key, required this.title, this.subtitle, this.actions = const []});

  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 14, 12, 6),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: context.text.headlineSmall),
              if (subtitle != null)
                Text(subtitle!, style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant)),
            ],
          ),
        ),
        ...actions,
      ],
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.message, this.action});

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(color: context.extra.goldSoft, shape: BoxShape.circle),
            child: Icon(icon, size: 40, color: context.extra.gold),
          ),
          const SizedBox(height: 16),
          Text(title, textAlign: TextAlign.center, style: context.text.titleLarge),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
            ),
          ],
          if (action != null) ...[const SizedBox(height: 18), action!],
        ],
      ),
    ),
  );
}

/// Full error panel with a retry button; highlights the "run supabase_setup.sql" case.
class ErrorPanel extends StatelessWidget {
  const ErrorPanel({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => EmptyState(
    icon: message == dbNotSetUpMessage
        ? Icons.storage_rounded
        : message == noConnectionMessage
        ? Icons.wifi_off_rounded
        : Icons.error_outline_rounded,
    title: message == dbNotSetUpMessage ? 'قاعدة البيانات غير مُعدّة' : 'تعذّر التحميل',
    message: message,
    action: onRetry == null
        ? null
        : FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('إعادة المحاولة'),
          ),
  );
}

// ───────────────── Status ─────────────────

Color statusColor(BuildContext context, OrderStatus s) {
  final dark = context.extra.isDark;
  return switch (s) {
    OrderStatus.newOrder => dark ? const Color(0xFFE2C27A) : goldDeep,
    OrderStatus.preparing => dark ? const Color(0xFF8DB4F0) : const Color(0xFF2C5BA8),
    OrderStatus.shipped => dark ? const Color(0xFFC4A3F0) : const Color(0xFF6A3FB0),
    OrderStatus.delivered => dark ? const Color(0xFF7FCFA4) : success,
    OrderStatus.cancelled => dark ? const Color(0xFFE38A7A) : danger,
  };
}

IconData statusIcon(OrderStatus s) => switch (s) {
  OrderStatus.newOrder => Icons.fiber_new_rounded,
  OrderStatus.preparing => Icons.inventory_2_rounded,
  OrderStatus.shipped => Icons.local_shipping_rounded,
  OrderStatus.delivered => Icons.task_alt_rounded,
  OrderStatus.cancelled => Icons.cancel_rounded,
};

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key, this.dense = false});

  final OrderStatus status;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final c = statusColor(context, status);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 10, vertical: dense ? 2 : 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon(status), size: dense ? 13 : 15, color: c),
          const SizedBox(width: 4),
          Text(status.label, style: (dense ? context.text.labelSmall : context.text.labelMedium)?.copyWith(color: c)),
        ],
      ),
    );
  }
}

class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.color, this.icon});

  final String text;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.extra.gold;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 12, color: c), const SizedBox(width: 3)],
          Text(text, style: context.text.labelSmall?.copyWith(color: c)),
        ],
      ),
    );
  }
}

// ───────────────── Feedback ─────────────────

void showMessage(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              error ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
              color: error ? const Color(0xFFFFB4A6) : goldLight,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        duration: Duration(seconds: error ? 6 : 3),
      ),
    );
}

void showError(BuildContext context, Object error) => showMessage(context, friendlyError(error), error: true);

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirm = 'تأكيد',
  bool destructive = false,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: ctx.colors.error, foregroundColor: ctx.colors.onError)
              : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirm),
        ),
      ],
    ),
  );
  return ok == true;
}

/// Runs [task] with a blocking progress dialog; shows the friendly error on failure.
Future<T?> runWithProgress<T>(BuildContext context, Future<T> Function() task, {String label = 'جارٍ التنفيذ…'}) async {
  final nav = Navigator.of(context, rootNavigator: true);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3)),
            const SizedBox(width: 18),
            Expanded(child: Text(label)),
          ],
        ),
      ),
    ),
  );
  try {
    final r = await task();
    nav.pop();
    return r;
  } catch (e) {
    nav.pop();
    if (context.mounted) showError(context, e);
    return null;
  }
}

/// The store logo on a dark rounded tile (the logo is white on transparent).
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 44});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    padding: EdgeInsets.all(size * 0.1),
    decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(size * 0.28)),
    child: Image.asset('assets/branding/logo_mark.png', fit: BoxFit.contain),
  );
}
