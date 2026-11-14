import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../config/theme.dart';
import '../services/errors.dart';
import '../services/session.dart';
import '../widgets/common.dart';

enum _Mode { login, signup, confirmEmail }

/// Login, create account, and the "confirm your email" step.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  _Mode _mode = _Mode.login;
  bool _busy = false;
  bool _hide = true;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _email, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  void _switch(_Mode m) => setState(() {
    _mode = m;
    _error = null;
    _form.currentState?.reset();
  });

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final session = context.read<Session>();
    try {
      if (_mode == _Mode.login) {
        await session.signIn(_email.text, _password.text);
      } else {
        final needsConfirm = await session.signUp(name: _name.text, email: _email.text, password: _password.text);
        if (needsConfirm && mounted) setState(() => _mode = _Mode.confirmEmail);
      }
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [context.extra.navyBar, context.colors.surface],
            stops: const [0, 0.55],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  children: [
                    const BrandMark(size: 96),
                    const SizedBox(height: 12),
                    Text(AppConfig.appName, style: context.text.headlineMedium?.copyWith(color: goldLight)),
                    Text(
                      'لوحة إدارة ${AppConfig.storeName}',
                      style: context.text.bodyMedium?.copyWith(color: ivory.withValues(alpha: 0.8)),
                    ),
                    const SizedBox(height: 24),
                    AppSurface(
                      elevation: 6,
                      padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
                      child: _mode == _Mode.confirmEmail ? _confirmView() : _formView(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _confirmView() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.mark_email_unread_rounded, size: 56, color: context.extra.gold),
      const SizedBox(height: 12),
      Text('أكّد بريدك الإلكتروني', style: context.text.headlineSmall),
      const SizedBox(height: 10),
      Text(
        'أرسلنا رسالة تأكيد إلى:\n${_email.text.trim()}\n\n'
        'افتح الرسالة واضغط رابط التأكيد، ثم ارجع إلى هنا وسجّل الدخول بالبريد وكلمة المرور. '
        'إن لم تجد الرسالة فابحث في مجلد الرسائل غير المرغوب فيها (Spam).',
        textAlign: TextAlign.center,
        style: context.text.bodyLarge?.copyWith(color: context.colors.onSurfaceVariant),
      ),
      const SizedBox(height: 20),
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: () => _switch(_Mode.login),
          icon: const Icon(Icons.login_rounded),
          label: const Text('الذهاب إلى تسجيل الدخول'),
        ),
      ),
    ],
  );

  Widget _formView() {
    final signup = _mode == _Mode.signup;
    return Form(
      key: _form,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              signup ? 'إنشاء حساب جديد' : 'تسجيل الدخول',
              textAlign: TextAlign.center,
              style: context.text.headlineSmall,
            ),
            const SizedBox(height: 18),
            if (signup) ...[
              TextFormField(
                controller: _name,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                decoration: const InputDecoration(
                  labelText: 'الاسم الكامل',
                  prefixIcon: Icon(Icons.person_rounded),
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v ?? '').trim().length < 2 ? 'اكتب اسمك' : null,
              ),
              const SizedBox(height: 12),
            ],
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textDirection: TextDirection.ltr,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(
                labelText: 'البريد الإلكتروني',
                prefixIcon: Icon(Icons.alternate_email_rounded),
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                final s = (v ?? '').trim();
                if (s.isEmpty) return 'اكتب البريد الإلكتروني';
                if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s)) return 'صيغة البريد غير صحيحة';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _password,
              obscureText: _hide,
              textDirection: TextDirection.ltr,
              textInputAction: signup ? TextInputAction.next : TextInputAction.done,
              autofillHints: [signup ? AutofillHints.newPassword : AutofillHints.password],
              onFieldSubmitted: signup ? null : (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'كلمة المرور',
                prefixIcon: const Icon(Icons.lock_rounded),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _hide = !_hide),
                  icon: Icon(_hide ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                ),
              ),
              validator: (v) {
                if ((v ?? '').isEmpty) return 'اكتب كلمة المرور';
                if (signup && v!.length < 8) return 'كلمة المرور 8 أحرف على الأقل';
                return null;
              },
            ),
            if (signup) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirm,
                obscureText: _hide,
                textDirection: TextDirection.ltr,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                decoration: const InputDecoration(
                  labelText: 'تأكيد كلمة المرور',
                  prefixIcon: Icon(Icons.lock_outline_rounded),
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v != _password.text ? 'كلمتا المرور غير متطابقتين' : null,
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.colors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.error_outline_rounded, color: context.colors.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_error!, style: TextStyle(color: context.colors.error)),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4))
                  : Text(signup ? 'إنشاء الحساب' : 'دخول'),
            ),
            const SizedBox(height: 10),
            if (!signup)
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                onPressed: _busy ? null : () => _switch(_Mode.signup),
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('إنشاء حساب جديد'),
              )
            else
              TextButton(
                onPressed: _busy ? null : () => _switch(_Mode.login),
                child: const Text('لديك حساب؟ تسجيل الدخول'),
              ),
          ],
        ),
      ),
    );
  }
}
