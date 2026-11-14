import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../models/models.dart';
import '../services/feeds.dart';
import '../services/format.dart';
import '../widgets/common.dart';

/// Store settings read by the store app (WhatsApp, delivery fees, about text, announcement bar).
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _form = GlobalKey<FormState>();
  final _whatsapp = TextEditingController();
  final _najaf = TextEditingController();
  final _other = TextEditingController();
  final _about = TextEditingController();
  final _announcement = TextEditingController();
  bool _announcementOn = false;
  bool _filled = false;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_whatsapp, _najaf, _other, _about, _announcement]) {
      c.dispose();
    }
    super.dispose();
  }

  void _fill(StoreSettings s) {
    _whatsapp.text = s.whatsappNumber;
    _najaf.text = '${s.deliveryFeeNajaf}';
    _other.text = '${s.deliveryFeeOther}';
    _about.text = s.aboutText;
    _announcement.text = s.announcement;
    _announcementOn = s.announcementEnabled;
    _filled = true;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await context.read<CatalogFeed>().saveSettings(
        StoreSettings(
          whatsappNumber: digitsOnly(_whatsapp.text),
          deliveryFeeNajaf: int.parse(digitsOnly(_najaf.text)),
          deliveryFeeOther: int.parse(digitsOnly(_other.text)),
          aboutText: _about.text.trim(),
          announcement: _announcement.text.trim(),
          announcementEnabled: _announcementOn && _announcement.text.trim().isNotEmpty,
        ),
      );
      if (mounted) showMessage(context, 'تم حفظ الإعدادات — تظهر في تطبيق المكتبة فوراً');
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _fee(String? v) {
    final n = int.tryParse(digitsOnly(v ?? ''));
    if (n == null) return 'مطلوب';
    if (n < 0 || n > 1000000) return 'قيمة غير صحيحة';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogFeed>();
    if (!catalog.settingsLoaded) {
      if (catalog.error != null) return ErrorPanel(message: catalog.error!, onRetry: catalog.retry);
      return const Center(child: CircularProgressIndicator());
    }
    if (!_filled) _fill(catalog.settings);
    final digits = [FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩]'))];

    return Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          MaxWidth(
            maxWidth: kMaxReadingWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const PageHeader(title: 'إعدادات المكتبة', subtitle: 'تُقرأ مباشرة في تطبيق المكتبة'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SectionTitle('التواصل والتوصيل'),
                      AppSurface(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _whatsapp,
                              keyboardType: TextInputType.phone,
                              textDirection: TextDirection.ltr,
                              inputFormatters: digits,
                              decoration: const InputDecoration(
                                labelText: 'رقم واتساب المكتبة',
                                helperText: 'بالصيغة الدولية بدون + مثل 9647700000000',
                                prefixIcon: Icon(Icons.chat_rounded),
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) {
                                final d = digitsOnly(v ?? '');
                                if (d.length < 10 || d.length > 15) return 'رقم غير صحيح';
                                if (d.startsWith('0')) return 'اكتب الرقم بالصيغة الدولية (يبدأ بـ 964)';
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _najaf,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: digits,
                                    decoration: const InputDecoration(
                                      labelText: 'التوصيل داخل النجف (د.ع)',
                                      border: OutlineInputBorder(),
                                    ),
                                    validator: _fee,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextFormField(
                                    controller: _other,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: digits,
                                    decoration: const InputDecoration(
                                      labelText: 'باقي المحافظات (د.ع)',
                                      border: OutlineInputBorder(),
                                    ),
                                    validator: _fee,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SectionTitle('عن المكتبة'),
                      AppSurface(
                        padding: const EdgeInsets.all(16),
                        child: TextFormField(
                          controller: _about,
                          minLines: 4,
                          maxLines: 10,
                          maxLength: 3000,
                          decoration: const InputDecoration(
                            labelText: 'نبذة «عن المكتبة»',
                            alignLabelWithHint: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SectionTitle('شريط الإعلان'),
                      AppSurface(
                        padding: const EdgeInsets.fromLTRB(8, 8, 16, 16),
                        child: Column(
                          children: [
                            SwitchListTile(
                              value: _announcementOn,
                              onChanged: (v) => setState(() => _announcementOn = v),
                              title: const Text('إظهار شريط الإعلان'),
                              subtitle: const Text('يظهر أعلى الصفحة الرئيسية في تطبيق المكتبة'),
                            ),
                            Padding(
                              padding: const EdgeInsetsDirectional.only(start: 8),
                              child: TextFormField(
                                controller: _announcement,
                                maxLength: 200,
                                decoration: const InputDecoration(
                                  labelText: 'نص الإعلان',
                                  hintText: 'مثال: خصم 20% على كتب الأطفال حتى نهاية الشهر',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (v) => _announcementOn && (v ?? '').trim().isEmpty
                                    ? 'اكتب نص الإعلان أو أطفئ الشريط'
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                        onPressed: _busy ? null : _save,
                        icon: _busy
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4))
                            : const Icon(Icons.save_rounded),
                        label: const Text('حفظ الإعدادات'),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _busy ? null : () => setState(() => _fill(catalog.settings)),
                        child: const Text('تراجع عن التعديلات غير المحفوظة'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
