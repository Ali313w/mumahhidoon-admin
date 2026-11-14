// مثال لملف الإعدادات المحلية. انسخه إلى local_config.dart في المجلد نفسه
// واملأ القيم من لوحة Supabase ← Project Settings ← API.
// local_config.dart مستثنى من git ولا يُرفع أبداً.

/// Service configuration that stays on this machine.
/// Only the public (publishable) key belongs here — never a secret / service_role key.
class LocalConfig {
  LocalConfig._();

  /// Supabase project URL, e.g. https://YOUR-PROJECT-REF.supabase.co
  static const supabaseUrl = 'https://YOUR-PROJECT-REF.supabase.co';

  /// Supabase publishable (anon) key, starts with sb_publishable_
  static const supabasePublishableKey = 'sb_publishable_YOUR_KEY';

  /// Store WhatsApp number in international format without + (fallback until settings load).
  static const whatsappNumber = '9647XXXXXXXXX';
}
