import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../models/models.dart';
import '../services/feeds.dart';
import '../services/format.dart';
import '../services/session.dart';
import '../widgets/common.dart';

/// Super admin only: approve / reject requests, change roles, suspend or delete accounts.
class StaffScreen extends StatelessWidget {
  const StaffScreen({super.key});

  Future<void> _run(BuildContext context, Future<void> Function() task, String done) async {
    final ok = await runWithProgress(context, () async {
      await task();
      return true;
    });
    if (ok == true && context.mounted) showMessage(context, done);
  }

  @override
  Widget build(BuildContext context) {
    final feed = context.watch<StaffFeed>();
    final me = context.select<Session, String?>((s) => s.staff?.userId);

    if (feed.error != null && feed.all.isEmpty) return ErrorPanel(message: feed.error!);
    if (feed.loading) return const Center(child: CircularProgressIndicator());

    final pending = feed.pending;
    final members = feed.members;
    return ListView(
      padding: const EdgeInsets.only(bottom: 40),
      children: [
        MaxWidth(
          maxWidth: kMaxReadingWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const PageHeader(title: 'المديرون', subtitle: 'كل حساب جديد ينتظر موافقتك وتحديد صلاحيته'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (pending.isNotEmpty) ...[
                      SectionTitle('طلبات بانتظار الموافقة (${pending.length})'),
                      for (final s in pending)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _PendingCard(staff: s, run: _run),
                        ),
                    ],
                    SectionTitle('الحسابات (${members.length})'),
                    for (final s in members)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _MemberCard(
                          staff: s,
                          isMe: s.userId == me,
                          isLastSuper:
                              s.role == StaffRole.superAdmin &&
                              s.status == StaffStatus.active &&
                              feed.activeSuperAdmins <= 1,
                          run: _run,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

typedef _Runner = Future<void> Function(BuildContext, Future<void> Function(), String);

class _PendingCard extends StatefulWidget {
  const _PendingCard({required this.staff, required this.run});

  final Staff staff;
  final _Runner run;

  @override
  State<_PendingCard> createState() => _PendingCardState();
}

class _PendingCardState extends State<_PendingCard> {
  StaffRole _role = StaffRole.ordersClerk;

  @override
  Widget build(BuildContext context) {
    final s = widget.staff;
    final feed = context.read<StaffFeed>();
    return AppSurface(
      padding: const EdgeInsets.all(14),
      border: BorderSide(color: context.extra.gold.withValues(alpha: 0.5)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(
            staff: s,
            trailing: const Pill('بانتظار الموافقة', icon: Icons.hourglass_top_rounded),
          ),
          const SizedBox(height: 12),
          Text('الصلاحية عند الموافقة:', style: context.text.labelMedium),
          const SizedBox(height: 6),
          SegmentedButton<StaffRole>(
            segments: [for (final r in StaffRole.values) ButtonSegment(value: r, label: Text(r.label))],
            selected: {_role},
            showSelectedIcon: false,
            onSelectionChanged: (v) => setState(() => _role = v.first),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => widget.run(
                    context,
                    () => feed.approve(s.userId, _role),
                    'تمت الموافقة على ${s.displayName} (${_role.label})',
                  ),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('موافقة'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: context.colors.error),
                  onPressed: () async {
                    final ok = await confirmDialog(
                      context,
                      title: 'رفض الطلب',
                      message: 'رفض طلب ${s.displayName}؟ سيبقى حسابه موقوفاً ولن يرى أي شيء.',
                      confirm: 'رفض',
                      destructive: true,
                    );
                    if (ok && context.mounted) await widget.run(context, () => feed.reject(s.userId), 'تم رفض الطلب');
                  },
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('رفض'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({required this.staff, required this.isMe, required this.isLastSuper, required this.run});

  final Staff staff;
  final bool isMe;
  final bool isLastSuper;
  final _Runner run;

  @override
  Widget build(BuildContext context) {
    final s = staff;
    final feed = context.read<StaffFeed>();
    final suspended = s.status == StaffStatus.suspended;
    final locked = isMe || isLastSuper;
    return AppSurface(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(
            staff: s,
            trailing: suspended
                ? Pill('موقوف', color: context.colors.error, icon: Icons.block_rounded)
                : Pill(s.role?.label ?? '—', icon: Icons.verified_user_rounded),
            me: isMe,
          ),
          if (locked) ...[
            const SizedBox(height: 8),
            Text(
              isMe
                  ? 'لا يمكنك تغيير صلاحيتك أو إيقاف حسابك بنفسك.'
                  : 'آخر مدير رئيسي فعّال: لا يمكن إيقافه أو تغيير صلاحيته أو حذفه.',
              style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
            ),
          ] else ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (!suspended)
                  PopupMenuButton<StaffRole>(
                    tooltip: 'تغيير الصلاحية',
                    onSelected: (r) {
                      if (r != s.role) {
                        run(context, () => feed.setRole(s.userId, r), 'أصبحت صلاحية ${s.displayName}: ${r.label}');
                      }
                    },
                    itemBuilder: (_) => [
                      for (final r in StaffRole.values)
                        CheckedPopupMenuItem(value: r, checked: r == s.role, child: Text(r.label)),
                    ],
                    child: const Chip(
                      avatar: Icon(Icons.manage_accounts_rounded, size: 18),
                      label: Text('تغيير الصلاحية'),
                    ),
                  ),
                if (suspended)
                  ActionChip(
                    avatar: const Icon(Icons.play_circle_outline_rounded, size: 18),
                    label: Text('إعادة التفعيل (${(s.role ?? StaffRole.ordersClerk).label})'),
                    onPressed: () => run(context, () => feed.activate(s), 'تم تفعيل الحساب'),
                  )
                else
                  ActionChip(
                    avatar: Icon(Icons.pause_circle_outline_rounded, size: 18, color: context.colors.error),
                    label: const Text('إيقاف الحساب'),
                    onPressed: () async {
                      final ok = await confirmDialog(
                        context,
                        title: 'إيقاف الحساب',
                        message: 'إيقاف حساب ${s.displayName}؟ لن يستطيع استخدام التطبيق حتى تعيد تفعيله.',
                        confirm: 'إيقاف',
                        destructive: true,
                      );
                      if (ok && context.mounted) await run(context, () => feed.suspend(s.userId), 'تم إيقاف الحساب');
                    },
                  ),
                ActionChip(
                  avatar: Icon(Icons.delete_outline_rounded, size: 18, color: context.colors.error),
                  label: const Text('حذف'),
                  onPressed: () async {
                    final ok = await confirmDialog(
                      context,
                      title: 'حذف الحساب',
                      message:
                          'حذف ${s.displayName} من المديرين؟ إن سجّل الدخول لاحقاً سيظهر طلبه من جديد بانتظار الموافقة.',
                      confirm: 'حذف',
                      destructive: true,
                    );
                    if (ok && context.mounted) await run(context, () => feed.remove(s.userId), 'تم حذف الحساب');
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.staff, required this.trailing, this.me = false});

  final Staff staff;
  final Widget trailing;
  final bool me;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      CircleAvatar(
        backgroundColor: context.extra.goldSoft,
        child: Text(
          staff.displayName.isEmpty ? '?' : staff.displayName.characters.first,
          style: context.text.titleMedium?.copyWith(color: context.extra.gold),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(me ? '${staff.displayName} (أنت)' : staff.displayName, style: context.text.titleMedium),
            Text(
              '${ltr(staff.email)}  •  ${formatDate(staff.createdAt)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
      trailing,
    ],
  );
}
