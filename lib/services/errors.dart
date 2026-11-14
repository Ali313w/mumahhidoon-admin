import 'package:supabase_flutter/supabase_flutter.dart';

const dbNotSetUpMessage =
    'قاعدة البيانات غير مُعدّة بعد. افتح لوحة Supabase ← SQL Editor وشغّل ملف supabase_setup.sql كاملاً، ثم أعد المحاولة.';

const noConnectionMessage = 'لا يوجد اتصال بالإنترنت أو تعذّر الوصول إلى الخادم. تحقق من الاتصال وأعد المحاولة.';

/// Turns any exception into a short, friendly Arabic message.
String friendlyError(Object error) {
  final raw = error.toString();
  final lower = raw.toLowerCase();

  if (_isNetwork(lower)) return noConnectionMessage;

  if (error is AuthException) {
    final code = (error.code ?? '').toLowerCase();
    final msg = error.message.toLowerCase();
    if (code == 'invalid_credentials' || msg.contains('invalid login credentials')) {
      return 'البريد الإلكتروني أو كلمة المرور غير صحيحة.';
    }
    if (code == 'email_not_confirmed' || msg.contains('email not confirmed')) {
      return 'لم يتم تأكيد البريد الإلكتروني بعد. افتح الرسالة المرسلة إلى بريدك واضغط رابط التأكيد ثم سجّل الدخول.';
    }
    if (code == 'user_already_exists' || code == 'email_exists' || msg.contains('already registered')) {
      return 'هذا البريد الإلكتروني مستخدم بحساب آخر. سجّل الدخول به أو استخدم بريداً غيره.';
    }
    if (code == 'weak_password' || msg.contains('password should') || msg.contains('weak')) {
      return 'كلمة المرور ضعيفة. استخدم 8 أحرف على الأقل تجمع بين الحروف والأرقام.';
    }
    if (code == 'same_password' || msg.contains('different from the old')) {
      return 'كلمة المرور الجديدة يجب أن تختلف عن الحالية.';
    }
    if (code == 'over_email_send_rate_limit' || code == 'over_request_rate_limit' || msg.contains('rate limit')) {
      return 'محاولات كثيرة خلال وقت قصير. انتظر قليلاً ثم أعد المحاولة.';
    }
    if (code == 'email_address_invalid' || msg.contains('invalid format') || msg.contains('email address')) {
      return 'صيغة البريد الإلكتروني غير صحيحة.';
    }
    if (code == 'signup_disabled' || msg.contains('signups not allowed')) {
      return 'إنشاء الحسابات معطّل في إعدادات Supabase (Authentication ← Providers ← Email).';
    }
    if (code == 'session_not_found' || code == 'refresh_token_not_found' || msg.contains('jwt')) {
      return 'انتهت الجلسة. سجّل الدخول من جديد.';
    }
    return 'تعذّر إتمام العملية: ${error.message}';
  }

  if (error is PostgrestException) {
    if (isDbNotSetUp(error)) return dbNotSetUpMessage;
    if (error.code == '42501' || lower.contains('row-level security') || lower.contains('permission denied')) {
      // our own triggers raise readable Arabic messages with this code
      return _hasArabic(error.message) ? error.message : 'لا تملك صلاحية لهذه العملية.';
    }
    if (error.hint == 'last_super_admin') {
      return 'لا يمكن إيقاف أو حذف أو تغيير صلاحية آخر مدير رئيسي فعّال. عيّن مديراً رئيسياً آخر أولاً.';
    }
    if (error.code == 'PGRST116') return 'لا تملك صلاحية لهذه العملية، أو لم يعد هذا العنصر موجوداً.';
    if (error.code == '23514') return 'القيمة المدخلة غير مقبولة (مثلاً تفعيل حساب بلا صلاحية).';
    if (error.code == '23503') {
      return 'لا يمكن إتمام العملية لوجود بيانات مرتبطة (مثلاً قسم فيه كتب). انقل الكتب أولاً.';
    }
    if (error.code == '23505') return 'هذه القيمة موجودة مسبقاً.';
    if (_hasArabic(error.message)) return error.message;
    return 'حدث خطأ في قاعدة البيانات: ${error.message}';
  }

  if (error is StorageException) {
    final m = error.message.toLowerCase();
    if (m.contains('bucket not found')) return dbNotSetUpMessage;
    if (m.contains('row-level security') || error.statusCode == '403' || error.statusCode == '401') {
      return 'لا تملك صلاحية رفع الصور.';
    }
    if (m.contains('payload too large') || m.contains('exceeded') || error.statusCode == '413') {
      return 'حجم الصورة كبير جداً.';
    }
    return 'تعذّر رفع الصورة: ${error.message}';
  }

  if (error is RealtimeSubscribeException || lower.contains('realtime')) {
    return 'انقطع التحديث الفوري. تحقق من الاتصال وسيُعاد الاتصال تلقائياً.';
  }

  if (lower.contains('relation') && lower.contains('does not exist')) return dbNotSetUpMessage;
  if (lower.contains('timeout') || lower.contains('timed out')) return noConnectionMessage;
  return 'حدث خطأ غير متوقع. أعد المحاولة.';
}

bool isDbNotSetUp(Object error) {
  if (error is PostgrestException) {
    const codes = {'42P01', '42883', 'PGRST202', 'PGRST205', 'PGRST200', 'PGRST204', '42703'};
    if (codes.contains(error.code)) return true;
    final m = error.message.toLowerCase();
    return m.contains('could not find the function') ||
        m.contains('could not find the table') ||
        (m.contains('relation') && m.contains('does not exist'));
  }
  final s = error.toString().toLowerCase();
  return s.contains('could not find the table') || s.contains('could not find the function');
}

bool _isNetwork(String lower) =>
    lower.contains('socketexception') ||
    lower.contains('failed host lookup') ||
    lower.contains('clientexception') ||
    lower.contains('xmlhttprequest') ||
    lower.contains('failed to fetch') ||
    lower.contains('network is unreachable') ||
    lower.contains('connection refused') ||
    lower.contains('connection closed') ||
    lower.contains('handshakeexception') ||
    lower.contains('authretryablefetchexception');

bool _hasArabic(String s) => RegExp(r'[؀-ۿ]').hasMatch(s);
