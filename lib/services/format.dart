import '../config/app_config.dart';

/// 12500 → "12,500"
String formatNumber(int value) {
  final digits = value.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }
  return value < 0 ? '-$buf' : buf.toString();
}

/// 12500 → "12,500 د.ع"
String formatPrice(int value) => '${formatNumber(value)} ${AppConfig.currency}';

String _two(int v) => v.toString().padLeft(2, '0');

/// "2026/11/11  07:30 م"
String formatDateTime(DateTime d) {
  final h12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final ampm = d.hour < 12 ? 'ص' : 'م';
  return '${d.year}/${_two(d.month)}/${_two(d.day)}  ${_two(h12)}:${_two(d.minute)} $ampm';
}

String formatDate(DateTime d) => '${d.year}/${_two(d.month)}/${_two(d.day)}';

String formatTime(DateTime d) {
  final h12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '${_two(h12)}:${_two(d.minute)} ${d.hour < 12 ? 'ص' : 'م'}';
}

/// "منذ 5 دقائق" style relative time for lists.
String timeAgo(DateTime d) {
  final diff = DateTime.now().difference(d);
  if (diff.inSeconds < 60) return 'الآن';
  if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} د';
  if (diff.inHours < 24) return 'منذ ${diff.inHours} س';
  if (diff.inDays < 7) return 'منذ ${diff.inDays} يوم';
  return formatDate(d);
}

bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// Converts Arabic-Indic digits to Latin and drops everything that is not a digit.
String digitsOnly(String s) {
  const ar = '٠١٢٣٤٥٦٧٨٩';
  const fa = '۰۱۲۳۴۵۶۷۸۹';
  final b = StringBuffer();
  for (final ch in s.split('')) {
    final i = ar.indexOf(ch);
    final j = fa.indexOf(ch);
    if (i >= 0) {
      b.write(i);
    } else if (j >= 0) {
      b.write(j);
    } else if (RegExp(r'[0-9]').hasMatch(ch)) {
      b.write(ch);
    }
  }
  return b.toString();
}

/// 07700000000 → 9647700000000 (for wa.me links).
String internationalIraqi(String phone) {
  final d = digitsOnly(phone);
  if (d.startsWith('964')) return d;
  if (d.startsWith('0')) return '964${d.substring(1)}';
  return d;
}

/// Wraps text (phone numbers, emails) in a left-to-right isolate so it reads correctly inside Arabic text.
String ltr(String s) => '${String.fromCharCode(0x2066)}$s${String.fromCharCode(0x2069)}';
