import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import 'errors.dart';

SupabaseClient get db => Supabase.instance.client;

enum GateState { loading, signedOut, registering, pending, suspended, active, error }

/// Signed-in user + their staff row. Decides which screen the app shows.
class Session extends ChangeNotifier {
  Session(this._prefs) : _themeMode = _readTheme(_prefs);

  final SharedPreferences _prefs;

  GateState _state = GateState.loading;
  Staff? _staff;
  String? _error;
  bool _dbMissing = false;
  bool _welcomeSuperAdmin = false;
  ThemeMode _themeMode;

  StreamSubscription<AuthState>? _authSub;
  StreamSubscription<List<Map<String, dynamic>>>? _staffSub;
  Future<void>? _refreshing;
  String? _watchedUser;

  GateState get state => _state;
  Staff? get staff => _staff;
  StaffRole? get role => _staff?.isActive == true ? _staff!.role : null;
  String? get error => _error;
  bool get dbMissing => _dbMissing;
  ThemeMode get themeMode => _themeMode;
  User? get user => db.auth.currentUser;

  /// True once, right after the very first account became the super admin.
  bool get welcomeSuperAdmin => _welcomeSuperAdmin;
  void clearWelcome() => _welcomeSuperAdmin = false;

  void start() {
    _authSub = db.auth.onAuthStateChange.listen(
      (s) {
        switch (s.event) {
          case AuthChangeEvent.initialSession:
          case AuthChangeEvent.signedIn:
          case AuthChangeEvent.userUpdated:
            refresh();
          case AuthChangeEvent.signedOut:
            _setSignedOut();
          default:
            break;
        }
      },
      onError: (Object e) {
        // a stored session that can no longer be refreshed → back to the login screen
        _setSignedOut();
      },
    );
    if (db.auth.currentSession == null) _setSignedOut();
  }

  // ───────────────── Routing ─────────────────

  /// Reads the staff row and routes: no row → register; pending; suspended; active.
  Future<void> refresh() => _refreshing ??= _refresh().whenComplete(() => _refreshing = null);

  Future<void> _refresh() async {
    final u = db.auth.currentUser;
    if (u == null) {
      _setSignedOut();
      return;
    }
    if (_state == GateState.error || _state == GateState.signedOut) {
      _state = GateState.loading;
      notifyListeners();
    }
    try {
      var row = await db.from('staff').select().eq('user_id', u.id).maybeSingle();
      if (row == null) {
        _state = GateState.registering;
        notifyListeners();
        row = await _register(u);
      }
      _applyStaff(Staff.fromMap(row));
      _watchOwnRow(u.id);
    } catch (e) {
      _dbMissing = isDbNotSetUp(e);
      _error = friendlyError(e);
      _state = GateState.error;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> _register(User u) async {
    final name = (u.userMetadata?['full_name'] as String?)?.trim() ?? '';
    final res = await db.rpc('register_staff', params: {'full_name': name});
    final row = Map<String, dynamic>.from(res is List ? res.first as Map : res as Map);
    final created = DateTime.tryParse('${row['created_at']}');
    if (row['role'] == 'super_admin' &&
        created != null &&
        DateTime.now().toUtc().difference(created.toUtc()).inMinutes.abs() < 10) {
      _welcomeSuperAdmin = true;
    }
    return row;
  }

  void _applyStaff(Staff s) {
    _staff = s;
    _error = null;
    _dbMissing = false;
    _state = switch (s.status) {
      StaffStatus.pending => GateState.pending,
      StaffStatus.suspended => GateState.suspended,
      StaffStatus.active => s.role == null ? GateState.pending : GateState.active,
    };
    notifyListeners();
  }

  /// Live updates of the user's own row: approval, role change or suspension apply immediately.
  void _watchOwnRow(String uid) {
    if (_watchedUser == uid && _staffSub != null) return;
    _staffSub?.cancel();
    _watchedUser = uid;
    _staffSub = db.from('staff').stream(primaryKey: ['user_id']).eq('user_id', uid).listen((rows) {
      if (db.auth.currentUser?.id != uid) return;
      if (rows.isEmpty) {
        // the row was deleted by the super admin
        if (_staff != null) {
          _staff = null;
          refresh();
        }
        return;
      }
      final s = Staff.fromMap(rows.first);
      final old = _staff;
      if (old == null || old.role != s.role || old.status != s.status || old.fullName != s.fullName) {
        _applyStaff(s);
      }
    }, onError: (_) {});
  }

  void _setSignedOut() {
    _staffSub?.cancel();
    _staffSub = null;
    _watchedUser = null;
    _staff = null;
    _error = null;
    _state = GateState.signedOut;
    notifyListeners();
  }

  // ───────────────── Auth actions ─────────────────

  Future<void> signIn(String email, String password) async {
    await db.auth.signInWithPassword(email: email.trim(), password: password);
    await refresh();
  }

  /// Returns true when the project requires email confirmation (no session yet).
  Future<bool> signUp({required String name, required String email, required String password}) async {
    final res = await db.auth.signUp(email: email.trim(), password: password, data: {'full_name': name.trim()});
    // with email confirmation on, an existing address returns a user with no identities
    if (res.user != null && (res.user!.identities?.isEmpty ?? false)) {
      throw const AuthException('User already registered', code: 'user_already_exists');
    }
    if (res.session == null) return true;
    await refresh(); // calls register_staff because there is no row yet
    return false;
  }

  Future<void> signOut() async {
    try {
      await db.auth.signOut();
    } catch (_) {
      // offline: the local session is cleared anyway
    }
    _setSignedOut();
  }

  Future<void> updateName(String name) async {
    final uid = db.auth.currentUser!.id;
    final row = await db.from('staff').update({'full_name': name.trim()}).eq('user_id', uid).select().single();
    try {
      await db.auth.updateUser(UserAttributes(data: {'full_name': name.trim()}));
    } catch (_) {}
    _applyStaff(Staff.fromMap(row));
  }

  /// Verifies the current password first, then sets the new one.
  Future<void> changePassword(String current, String next) async {
    final email = db.auth.currentUser?.email;
    if (email == null) throw const AuthException('session_not_found', code: 'session_not_found');
    await db.auth.signInWithPassword(email: email, password: current);
    await db.auth.updateUser(UserAttributes(password: next));
  }

  // ───────────────── Theme ─────────────────

  static ThemeMode _readTheme(SharedPreferences p) => switch (p.getString('theme')) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    _prefs.setString('theme', mode.name);
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _staffSub?.cancel();
    super.dispose();
  }
}
