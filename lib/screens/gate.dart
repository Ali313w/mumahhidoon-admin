import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../config/theme.dart';
import '../services/alerts.dart';
import '../services/session.dart';
import '../widgets/common.dart';
import 'auth_screen.dart';
import 'shell.dart';

/// Routes by staff status on every start and after login:
/// no row → register, pending → waiting, suspended → blocked, active → the app.
class Gate extends StatefulWidget {
  const Gate({super.key});

  @override
  State<Gate> createState() => _GateState();
}

class _GateState extends State<Gate> {
  GateState? _last;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final state = session.state;
    if (_last == GateState.active && state != GateState.active) {
      // leaving the app (logout / suspended): close any open detail screens
      WidgetsBinding.instance.addPostFrameCallback((_) {
        appNavigatorKey.currentState?.popUntil((r) => r.isFirst);
        NewOrderAlerts.hide();
      });
    }
    _last = state;

    final Widget child = switch (state) {
      GateState.loading || GateState.registering => const SplashView(),
      GateState.signedOut => const AuthScreen(),
      GateState.pending => const _StatusScreen(
        icon: Icons.hourglass_top_rounded,
        title: 'طلبك بانتظار الموافقة',
        message:
            'تم إنشاء حسابك بنجاح، وهو بانتظار موافقة المدير الرئيسي للمكتبة. '
            'لن تظهر لك أي بيانات حتى يوافق على طلبك ويحدد صلاحيتك. '
            'اضغط «تحديث» للتحقق من حالة طلبك.',
      ),
      GateState.suspended => const _StatusScreen(
        icon: Icons.block_rounded,
        title: 'الحساب موقوف',
        message: 'تم إيقاف هذا الحساب أو رفض طلب الانضمام. تواصل مع المدير الرئيسي للمكتبة إن كان هذا خطأ.',
        danger: true,
      ),
      GateState.error => _StatusScreen(
        icon: session.dbMissing ? Icons.storage_rounded : Icons.wifi_off_rounded,
        title: session.dbMissing ? 'قاعدة البيانات غير مُعدّة' : 'تعذّر الاتصال',
        message: session.error ?? '',
        danger: true,
      ),
      GateState.active => AppShell(key: ValueKey('shell-${session.staff?.userId}-${session.role?.code}')),
    };
    return child;
  }
}

/// Black splash with the store logo, like the store app.
class SplashView extends StatelessWidget {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Colors.black,
    child: LayoutBuilder(
      builder: (context, c) => Stack(
        children: [
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: c.maxWidth * 0.6, maxHeight: c.maxHeight * 0.5),
              child: Image.asset('assets/branding/splash_logo.png', fit: BoxFit.contain),
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 48,
            child: Center(
              child: SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.5, color: gold)),
            ),
          ),
        ],
      ),
    ),
  );
}

class _StatusScreen extends StatefulWidget {
  const _StatusScreen({required this.icon, required this.title, required this.message, this.danger = false});

  final IconData icon;
  final String title;
  final String message;
  final bool danger;

  @override
  State<_StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends State<_StatusScreen> {
  bool _busy = false;

  Future<void> _refresh() async {
    setState(() => _busy = true);
    await context.read<Session>().refresh();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final session = context.read<Session>();
    final email = session.user?.email ?? '';
    final color = widget.danger ? context.colors.error : context.extra.gold;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: AppSurface(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const BrandMark(size: 64),
                    const SizedBox(height: 8),
                    Text(AppConfig.appName, style: context.text.titleMedium?.copyWith(color: context.extra.gold)),
                    const SizedBox(height: 22),
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(color: color.withValues(alpha: 0.13), shape: BoxShape.circle),
                      child: Icon(widget.icon, size: 38, color: color),
                    ),
                    const SizedBox(height: 16),
                    Text(widget.title, textAlign: TextAlign.center, style: context.text.headlineSmall),
                    const SizedBox(height: 10),
                    Text(
                      widget.message,
                      textAlign: TextAlign.center,
                      style: context.text.bodyLarge?.copyWith(color: context.colors.onSurfaceVariant),
                    ),
                    if (email.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Pill(email, icon: Icons.alternate_email_rounded),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _busy ? null : _refresh,
                        icon: _busy
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.refresh_rounded),
                        label: const Text('تحديث'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : session.signOut,
                        icon: const Icon(Icons.logout_rounded),
                        label: const Text('تسجيل الخروج'),
                      ),
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
}
