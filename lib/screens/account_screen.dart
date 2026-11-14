import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../config/theme.dart';
import '../services/errors.dart';
import '../services/format.dart';
import '../services/session.dart';
import '../widgets/common.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  Future<void> _editName(BuildContext context) async {
    final session = context.read<Session>();
    final c = TextEditingController(text: session.staff?.fullName ?? '');
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تغيير الاسم'),
        content: TextField(
          controller: c,
          autofocus: true,
          maxLength: 80,
          decoration: const InputDecoration(labelText: 'الاسم', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('حفظ')),
        ],
      ),
    );
    if (name == null || name.length < 2 || !context.mounted) return;
    final ok = await runWithProgress(context, () async {
      await session.updateName(name);
      return true;
    });
    if (ok == true && context.mounted) showMessage(context, 'تم تغيير الاسم');
  }

  Future<void> _changePassword(BuildContext context) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => const _PasswordDialog());
    if (ok == true && context.mounted) showMessage(context, 'تم تغيير كلمة المرور');
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final s = session.staff;
    return ListView(
      padding: const EdgeInsets.only(bottom: 40),
      children: [
        MaxWidth(
          maxWidth: kMaxReadingWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const PageHeader(title: 'حسابي'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppSurface(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: context.extra.goldSoft,
                            child: Text(
                              (s?.displayName.isNotEmpty ?? false) ? s!.displayName.characters.first : '?',
                              style: context.text.headlineSmall?.copyWith(color: context.extra.gold),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s?.displayName ?? '', style: context.text.titleLarge),
                                Text(
                                  ltr(s?.email ?? ''),
                                  style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
                                ),
                                const SizedBox(height: 6),
                                Pill(s?.role?.label ?? '—', icon: Icons.verified_user_rounded),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SectionTitle('الحساب'),
                    AppSurface(
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.badge_rounded),
                            title: const Text('الاسم'),
                            subtitle: Text(s?.fullName ?? ''),
                            trailing: const Icon(Icons.edit_rounded),
                            onTap: () => _editName(context),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(Icons.alternate_email_rounded),
                            title: const Text('البريد الإلكتروني'),
                            subtitle: Text(ltr(s?.email ?? '')),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(Icons.verified_user_rounded),
                            title: const Text('الصلاحية'),
                            subtitle: Text(s?.role?.label ?? '—'),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(Icons.lock_reset_rounded),
                            title: const Text('تغيير كلمة المرور'),
                            trailing: const Icon(Icons.chevron_left_rounded),
                            onTap: () => _changePassword(context),
                          ),
                        ],
                      ),
                    ),
                    const SectionTitle('المظهر'),
                    AppSurface(
                      child: Column(
                        children: [
                          SwitchListTile(
                            secondary: const Icon(Icons.dark_mode_rounded),
                            title: const Text('الوضع الليلي'),
                            subtitle: Text(session.themeMode == ThemeMode.system ? 'يتبع إعدادات الجهاز حالياً' : ''),
                            value:
                                session.themeMode == ThemeMode.dark ||
                                (session.themeMode == ThemeMode.system &&
                                    Theme.of(context).brightness == Brightness.dark),
                            onChanged: (v) => session.setThemeMode(v ? ThemeMode.dark : ThemeMode.light),
                          ),
                          if (session.themeMode != ThemeMode.system)
                            ListTile(
                              leading: const Icon(Icons.brightness_auto_rounded),
                              title: const Text('اتباع إعدادات الجهاز'),
                              onTap: () => session.setThemeMode(ThemeMode.system),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        foregroundColor: context.colors.error,
                        side: BorderSide(color: context.colors.error.withValues(alpha: 0.6)),
                      ),
                      onPressed: () async {
                        final ok = await confirmDialog(
                          context,
                          title: 'تسجيل الخروج',
                          message: 'هل تريد تسجيل الخروج من هذا الجهاز؟',
                          confirm: 'خروج',
                        );
                        if (ok) await session.signOut();
                      },
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('تسجيل الخروج'),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Text(
                        '${AppConfig.appName} — ${AppConfig.storeName}',
                        style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
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

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog();

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<Session>().changePassword(_current.text, _next.text);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = friendlyAuthError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('تغيير كلمة المرور'),
    content: Form(
      key: _form,
      child: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _current,
              obscureText: true,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(labelText: 'كلمة المرور الحالية', border: OutlineInputBorder()),
              validator: (v) => (v ?? '').isEmpty ? 'مطلوبة' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _next,
              obscureText: true,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(labelText: 'كلمة المرور الجديدة', border: OutlineInputBorder()),
              validator: (v) => (v ?? '').length < 8 ? '8 أحرف على الأقل' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _confirm,
              obscureText: true,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(labelText: 'تأكيد كلمة المرور الجديدة', border: OutlineInputBorder()),
              validator: (v) => v != _next.text ? 'غير متطابقة' : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: TextStyle(color: context.colors.error)),
            ],
          ],
        ),
      ),
    ),
    actions: [
      TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('إلغاء')),
      FilledButton(
        onPressed: _busy ? null : _submit,
        child: _busy
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : const Text('حفظ'),
      ),
    ],
  );
}

String friendlyAuthError(Object e) {
  final m = friendlyError(e);
  return m.startsWith('البريد الإلكتروني أو كلمة المرور') ? 'كلمة المرور الحالية غير صحيحة.' : m;
}
