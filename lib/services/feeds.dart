import 'dart:async';

import 'package:flutter/foundation.dart' hide Category;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import 'errors.dart';
import 'session.dart';

/// Live list of orders (realtime). Notifies [onNewOrder] for every order inserted after the first load.
class OrdersFeed extends ChangeNotifier {
  static const _limit = 2000;

  List<StoreOrder> _orders = const [];
  bool _loading = true;
  String? _error;
  StreamSubscription<List<Map<String, dynamic>>>? _sub;
  Set<String>? _known;

  void Function(StoreOrder order)? onNewOrder;

  List<StoreOrder> get orders => _orders;
  bool get loading => _loading;
  String? get error => _error;
  bool get started => _sub != null;

  int countOf(OrderStatus s) => _orders.where((o) => o.status == s).length;

  StoreOrder? byId(String id) {
    for (final o in _orders) {
      if (o.id == id) return o;
    }
    return null;
  }

  int _users = 0;

  void start() {
    _users++;
    _open();
  }

  void _open() {
    if (_sub != null) return;
    _loading = true;
    _error = null;
    _known = null;
    _sub = db
        .from('orders')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .limit(_limit)
        .listen(
          _onRows,
          onError: (Object e) {
            _error = friendlyError(e);
            _loading = false;
            notifyListeners();
          },
        );
  }

  void _onRows(List<Map<String, dynamic>> rows) {
    final list = rows.map(StoreOrder.fromMap).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final known = _known;
    if (known != null && onNewOrder != null) {
      for (final o in list) {
        if (!known.contains(o.id) && o.status == OrderStatus.newOrder) onNewOrder!(o);
      }
    }
    _known = {for (final o in list) o.id};
    _orders = list;
    _loading = false;
    _error = null;
    notifyListeners();
  }

  void retry() {
    _close();
    _open();
  }

  void stop() {
    if (_users > 0) _users--;
    if (_users > 0) return;
    _close();
  }

  void _close() {
    _sub?.cancel();
    _sub = null;
    _orders = const [];
    _known = null;
    _loading = true;
  }

  Future<void> setStatus(String orderId, OrderStatus status) =>
      db.from('orders').update({'status': status.code}).eq('id', orderId);

  Future<void> setNote(String orderId, String note) =>
      db.from('orders').update({'internal_note': note}).eq('id', orderId);

  static Future<List<OrderItem>> items(String orderId) async {
    final rows = await db.from('order_items').select().eq('order_id', orderId).order('id');
    return rows.map(OrderItem.fromMap).toList();
  }

  static Future<Map<String, List<OrderItem>>> itemsFor(List<String> orderIds) async {
    final out = <String, List<OrderItem>>{for (final id in orderIds) id: []};
    for (var i = 0; i < orderIds.length; i += 100) {
      final chunk = orderIds.sublist(i, (i + 100).clamp(0, orderIds.length));
      final rows = await db.from('order_items').select().inFilter('order_id', chunk).order('id');
      for (final r in rows) {
        final item = OrderItem.fromMap(r);
        out[item.orderId]?.add(item);
      }
    }
    return out;
  }

  static Future<List<StatusChange>> history(String orderId) async {
    final rows = await db
        .from('order_status_history')
        .select()
        .eq('order_id', orderId)
        .order('changed_at', ascending: false);
    return rows.map(StatusChange.fromMap).toList();
  }

  /// Copies ordered per book, excluding cancelled orders.
  static Future<List<(String, int)>> topBooks({int count = 5}) async {
    final rows = await db
        .from('order_items')
        .select('title, quantity, orders!inner(status)')
        .neq('orders.status', 'cancelled')
        .limit(10000);
    final totals = <String, int>{};
    for (final r in rows) {
      final t = '${r['title']}';
      totals[t] = (totals[t] ?? 0) + ((r['quantity'] as num?)?.toInt() ?? 0);
    }
    final list = totals.entries.map((e) => (e.key, e.value)).toList()..sort((a, b) => b.$2.compareTo(a.$2));
    return list.take(count).toList();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

/// Books, categories and settings, all live.
class CatalogFeed extends ChangeNotifier {
  List<Book> _books = const [];
  List<Category> _categories = const [];
  StoreSettings? _settings;
  bool _booksLoaded = false;
  bool _categoriesLoaded = false;
  String? _error;
  final _subs = <StreamSubscription<List<Map<String, dynamic>>>>[];

  List<Book> get books => _books;
  List<Category> get categories => _categories;
  StoreSettings get settings => _settings ?? const StoreSettings();
  bool get settingsLoaded => _settings != null;
  bool get loading => !_booksLoaded || !_categoriesLoaded;
  String? get error => _error;

  String categoryName(String? id) {
    for (final c in _categories) {
      if (c.id == id) return c.name;
    }
    return 'بلا قسم';
  }

  int booksIn(String categoryId) => _books.where((b) => b.categoryId == categoryId).length;

  int _users = 0;

  void start() {
    _users++;
    _open();
  }

  void _open() {
    if (_subs.isNotEmpty) return;
    _error = null;
    void onError(Object e) {
      _error = friendlyError(e);
      notifyListeners();
    }

    _subs.add(
      db.from('books').stream(primaryKey: ['id']).order('created_at').listen((rows) {
        _books = rows.map(Book.fromMap).toList()..sort((a, b) => a.title.compareTo(b.title));
        _booksLoaded = true;
        _error = null;
        notifyListeners();
      }, onError: onError),
    );
    _subs.add(
      db.from('categories').stream(primaryKey: ['id']).order('sort_order').listen((rows) {
        _categories = rows.map(Category.fromMap).toList()..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        _categoriesLoaded = true;
        notifyListeners();
      }, onError: onError),
    );
    _subs.add(
      db.from('settings').stream(primaryKey: ['id']).eq('id', 1).listen((rows) {
        if (rows.isNotEmpty) _settings = StoreSettings.fromMap(rows.first);
        notifyListeners();
      }, onError: onError),
    );
  }

  void retry() {
    _close();
    _open();
  }

  void stop() {
    if (_users > 0) _users--;
    if (_users > 0) return;
    _close();
  }

  void _close() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    _booksLoaded = false;
    _categoriesLoaded = false;
  }

  // ── Books ──
  Future<Map<String, dynamic>> saveBook(String? id, Map<String, dynamic> data) async {
    if (id == null) {
      return db.from('books').insert(data).select().single();
    }
    return db.from('books').update(data).eq('id', id).select().single();
  }

  Future<void> setAvailable(Book b, bool available) async {
    _books = [
      for (final x in _books) x.id == b.id ? Book.fromMap({..._bookMap(x), 'available': available}) : x,
    ];
    notifyListeners();
    await db.from('books').update({'available': available}).eq('id', b.id);
  }

  Future<void> deleteBook(String id) => db.from('books').delete().eq('id', id);

  // ── Categories ──
  Future<void> addCategory(String name) async {
    final next = _categories.isEmpty ? 1 : _categories.map((c) => c.sortOrder).reduce((a, b) => a > b ? a : b) + 1;
    await db.from('categories').insert({'name': name.trim(), 'sort_order': next});
  }

  Future<void> renameCategory(String id, String name) =>
      db.from('categories').update({'name': name.trim()}).eq('id', id);

  Future<void> deleteCategory(String id) => db.from('categories').delete().eq('id', id);

  Future<void> moveBooks(String fromCategory, String toCategory) =>
      db.from('books').update({'category_id': toCategory}).eq('category_id', fromCategory);

  Future<void> reorder(List<Category> ordered) async {
    _categories = [
      for (var i = 0; i < ordered.length; i++) Category(id: ordered[i].id, name: ordered[i].name, sortOrder: i + 1),
    ];
    notifyListeners();
    await Future.wait([
      for (final c in _categories) db.from('categories').update({'sort_order': c.sortOrder}).eq('id', c.id),
    ]);
  }

  // ── Settings ──
  Future<void> saveSettings(StoreSettings s) async {
    final row = await db.from('settings').update(s.toMap()).eq('id', 1).select().maybeSingle();
    if (row == null) {
      throw const PostgrestException(message: 'لا تملك صلاحية تعديل الإعدادات أو لم يُنشأ صف الإعدادات بعد.');
    }
    _settings = StoreSettings.fromMap(row);
    notifyListeners();
  }

  /// Fetches settings once (used for printing when the feed has not loaded yet).
  Future<StoreSettings> loadSettings() async {
    if (_settings != null) return _settings!;
    final row = await db.from('settings').select().eq('id', 1).maybeSingle();
    if (row != null) _settings = StoreSettings.fromMap(row);
    return settings;
  }

  static Map<String, dynamic> _bookMap(Book b) => {
    'id': b.id,
    'title': b.title,
    'author': b.author,
    'category_id': b.categoryId,
    'price': b.price,
    'old_price': b.oldPrice,
    'pages': b.pages,
    'description': b.description,
    'cover_url': b.coverUrl,
    'cover_path': b.coverPath,
    'cover_image': b.coverImage,
    'available': b.available,
    'featured': b.featured,
    'is_new': b.isNew,
    'best_seller': b.bestSeller,
    'special_offer': b.specialOffer,
    'popularity': b.popularity,
    'added_on': b.addedOn,
  };

  @override
  void dispose() {
    _close();
    super.dispose();
  }
}

/// All staff rows (super admin only), live — drives the pending badge.
class StaffFeed extends ChangeNotifier {
  List<Staff> _all = const [];
  bool _loading = true;
  String? _error;
  StreamSubscription<List<Map<String, dynamic>>>? _sub;

  List<Staff> get all => _all;
  List<Staff> get pending => _all.where((s) => s.status == StaffStatus.pending).toList();
  List<Staff> get members => _all.where((s) => s.status != StaffStatus.pending).toList();
  int get pendingCount => _all.where((s) => s.status == StaffStatus.pending).length;
  bool get loading => _loading;
  String? get error => _error;

  int get activeSuperAdmins =>
      _all.where((s) => s.role == StaffRole.superAdmin && s.status == StaffStatus.active).length;

  int _users = 0;

  void start() {
    _users++;
    _open();
  }

  void _open() {
    if (_sub != null) return;
    _loading = true;
    _sub = db
        .from('staff')
        .stream(primaryKey: ['user_id'])
        .order('created_at')
        .listen(
          (rows) {
            _all = rows.map(Staff.fromMap).toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt));
            _loading = false;
            _error = null;
            notifyListeners();
          },
          onError: (Object e) {
            _error = friendlyError(e);
            _loading = false;
            notifyListeners();
          },
        );
  }

  void stop() {
    if (_users > 0) _users--;
    if (_users > 0) return;
    _close();
  }

  void _close() {
    _sub?.cancel();
    _sub = null;
    _all = const [];
    _loading = true;
  }

  Future<void> _update(String uid, Map<String, dynamic> data) async {
    final rows = await db.from('staff').update(data).eq('user_id', uid).select();
    if (rows.isEmpty) throw const PostgrestException(message: 'لا تملك صلاحية لهذه العملية.', code: '42501');
  }

  Future<void> approve(String uid, StaffRole role) => _update(uid, {'role': role.code, 'status': 'active'});
  Future<void> reject(String uid) => _update(uid, {'status': 'suspended', 'role': null});
  Future<void> setRole(String uid, StaffRole role) => _update(uid, {'role': role.code});
  Future<void> suspend(String uid) => _update(uid, {'status': 'suspended'});

  Future<void> activate(Staff s) =>
      _update(s.userId, {'status': 'active', 'role': (s.role ?? StaffRole.ordersClerk).code});

  Future<void> remove(String uid) async {
    final rows = await db.from('staff').delete().eq('user_id', uid).select();
    if (rows.isEmpty) throw const PostgrestException(message: 'لا تملك صلاحية لهذه العملية.', code: '42501');
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
