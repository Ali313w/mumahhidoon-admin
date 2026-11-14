import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import 'session.dart';

/// Picks, shrinks and uploads book covers to the "covers" bucket.
class CoverService {
  CoverService._();

  static const maxSide = 1000;
  static const targetBytes = 200 * 1024;

  /// Opens the gallery or the camera; returns compressed JPEG bytes or null if cancelled.
  static Future<Uint8List?> pick(ImageSource source) async {
    final file = await ImagePicker().pickImage(source: source, maxWidth: 1600, maxHeight: 1600, imageQuality: 92);
    if (file == null) return null;
    final raw = await file.readAsBytes();
    return kIsWeb ? _compress(raw) : compute(_compress, raw);
  }

  /// Resizes to [maxSide] on the long side and lowers JPEG quality until ≤ ~200 KB.
  static Uint8List _compress(Uint8List raw) {
    final decoded = img.decodeImage(raw);
    if (decoded == null) throw const FormatException('صيغة الصورة غير مدعومة');
    var image = img.bakeOrientation(decoded);
    final long = max(image.width, image.height);
    if (long > maxSide) {
      image = image.width >= image.height
          ? img.copyResize(image, width: maxSide, interpolation: img.Interpolation.average)
          : img.copyResize(image, height: maxSide, interpolation: img.Interpolation.average);
    }
    var quality = 85;
    var out = img.encodeJpg(image, quality: quality);
    while (out.length > targetBytes && quality > 40) {
      quality -= 8;
      out = img.encodeJpg(image, quality: quality);
    }
    // still large (very detailed image): shrink further
    while (out.length > targetBytes && image.width > 400) {
      image = img.copyResize(image, width: (image.width * 0.85).round(), interpolation: img.Interpolation.average);
      out = img.encodeJpg(image, quality: quality);
    }
    return out;
  }

  /// Uploads with a unique name; returns (path, publicUrl).
  static Future<(String, String)> upload(Uint8List bytes) async {
    final rnd = Random.secure().nextInt(1 << 32).toRadixString(36);
    final path = 'books/${DateTime.now().millisecondsSinceEpoch}_$rnd.jpg';
    final bucket = db.storage.from(SupabaseConfig.coversBucket);
    await bucket.uploadBinary(
      path,
      bytes,
      fileOptions: const FileOptions(contentType: 'image/jpeg', cacheControl: '31536000', upsert: false),
    );
    return (path, bucket.getPublicUrl(path));
  }

  /// Best-effort removal of an old cover file.
  static Future<void> remove(String? path) async {
    if (path == null || path.trim().isEmpty) return;
    try {
      await db.storage.from(SupabaseConfig.coversBucket).remove([path]);
    } catch (_) {
      // a leftover file is harmless; never block the user on it
    }
  }
}
