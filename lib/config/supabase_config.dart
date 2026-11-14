import 'local_config.dart';

/// Supabase project used by both the store app and this admin app.
/// Only the public (publishable) key belongs here — never a secret / service_role key.
class SupabaseConfig {
  SupabaseConfig._();

  static const url = LocalConfig.supabaseUrl;
  static const publishableKey = LocalConfig.supabasePublishableKey;

  /// Storage bucket for book covers.
  static const coversBucket = 'covers';
}
