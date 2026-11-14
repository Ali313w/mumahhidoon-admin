import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide Session;

import 'config/app_config.dart';
import 'config/supabase_config.dart';
import 'config/theme.dart';
import 'screens/gate.dart';
import 'services/alerts.dart';
import 'services/feeds.dart';
import 'services/session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: SupabaseConfig.url, publishableKey: SupabaseConfig.publishableKey);
  final prefs = await SharedPreferences.getInstance();
  await _loadFonts();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => Session(prefs)..start()),
        ChangeNotifierProvider(create: (_) => OrdersFeed()),
        ChangeNotifierProvider(create: (_) => CatalogFeed()),
        ChangeNotifierProvider(create: (_) => StaffFeed()),
      ],
      child: const AdminApp(),
    ),
  );
}

/// Loads the bundled fonts up front so receipts rendered off screen (and on the web) use them.
Future<void> _loadFonts() async {
  try {
    final amiri = FontLoader('Amiri')
      ..addFont(rootBundle.load('assets/fonts/amiri_regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/amiri_bold.ttf'));
    final tajawal = FontLoader('Tajawal')
      ..addFont(rootBundle.load('assets/fonts/tajawal_regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/tajawal_medium.ttf'))
      ..addFont(rootBundle.load('assets/fonts/tajawal_bold.ttf'));
    await Future.wait([amiri.load(), tajawal.load()]);
  } catch (_) {
    // the engine still loads them lazily
  }
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    final mode = context.select<Session, ThemeMode>((s) => s.themeMode);
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      navigatorKey: appNavigatorKey,
      theme: buildTheme(dark: false),
      darkTheme: buildTheme(dark: true),
      themeMode: mode,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        final dark = Theme.of(context).brightness == Brightness.dark;
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
              statusBarBrightness: dark ? Brightness.dark : Brightness.light,
            ),
            child: ColoredBox(color: Theme.of(context).colorScheme.surface, child: child),
          ),
        );
      },
      home: const Gate(),
    );
  }
}
