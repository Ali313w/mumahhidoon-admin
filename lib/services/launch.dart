import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'format.dart';

/// Phone call and WhatsApp chat with a buyer.
class Contact {
  Contact._();

  static Future<void> call(BuildContext context, String phone) =>
      _open(context, Uri(scheme: 'tel', path: digitsOnly(phone)), 'تعذّر فتح تطبيق الاتصال على هذا الجهاز.');

  static Future<void> whatsapp(BuildContext context, String phone, {String message = ''}) {
    final number = internationalIraqi(phone);
    final uri = Uri.parse('https://wa.me/$number${message.isEmpty ? '' : '?text=${Uri.encodeComponent(message)}'}');
    return _open(context, uri, 'تعذّر فتح واتساب على هذا الجهاز.');
  }

  static Future<void> _open(BuildContext context, Uri uri, String failMessage) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    var ok = false;
    try {
      ok = kIsWeb
          ? await launchUrl(uri, webOnlyWindowName: '_blank')
          : await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      ok = false;
    }
    if (!ok) messenger?.showSnackBar(SnackBar(content: Text(failMessage)));
  }
}
