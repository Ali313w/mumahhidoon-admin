import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../config/theme.dart';
import '../models/models.dart';
import '../services/alerts.dart';
import '../services/feeds.dart';
import '../services/session.dart';
import '../widgets/common.dart';
import 'account_screen.dart';
import 'books_screen.dart';
import 'categories_screen.dart';
import 'dashboard_screen.dart';
import 'order_details_screen.dart';
import 'orders_screen.dart';
import 'settings_screen.dart';
import 'staff_screen.dart';

enum Dest {
  dashboard('الرئيسية', Icons.space_dashboard_outlined, Icons.space_dashboard_rounded),
  orders('الطلبات', Icons.receipt_long_outlined, Icons.receipt_long_rounded),
  books('الكتب', Icons.menu_book_outlined, Icons.menu_book_rounded),
  categories('الأقسام', Icons.category_outlined, Icons.category_rounded),
  settings('إعدادات المكتبة', Icons.storefront_outlined, Icons.storefront_rounded),
  staff('المديرون', Icons.admin_panel_settings_outlined, Icons.admin_panel_settings_rounded),
  account('حسابي', Icons.person_outline_rounded, Icons.person_rounded);

  const Dest(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// Only the destinations the role may use are shown at all.
List<Dest> destinationsFor(StaffRole role) => [
  if (role.canSeeDashboard) Dest.dashboard,
  Dest.orders,
  if (role.canManageCatalog) Dest.books,
  if (role.canManageCatalog) Dest.categories,
  if (role.isSuper) Dest.settings,
  if (role.isSuper) Dest.staff,
  Dest.account,
];

/// Lets any screen switch tabs (e.g. dashboard "see all orders").
class ShellController extends InheritedWidget {
  const ShellController({super.key, required this.go, required super.child});

  final void Function(Dest) go;

  static ShellController? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<ShellController>();

  @override
  bool updateShouldNotify(ShellController old) => false;
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late final StaffRole _role;
  late final List<Dest> _dests;
  late final OrdersFeed _orders;
  late final CatalogFeed _catalog;
  late final StaffFeed _staff;
  Dest _current = Dest.orders;
  final _visited = <Dest>{};

  @override
  void initState() {
    super.initState();
    final session = context.read<Session>();
    _role = session.role!;
    _dests = destinationsFor(_role);
    _current = _dests.first;
    _visited.add(_current);
    _orders = context.read<OrdersFeed>();
    _catalog = context.read<CatalogFeed>();
    _staff = context.read<StaffFeed>();
    _orders.onNewOrder = _onNewOrder;
    _orders.start();
    _catalog.start();
    if (_role.isSuper) _staff.start();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeWelcome());
  }

  @override
  void dispose() {
    if (_orders.onNewOrder == _onNewOrder) _orders.onNewOrder = null;
    _orders.stop();
    _catalog.stop();
    _staff.stop();
    super.dispose();
  }

  void _onNewOrder(StoreOrder o) => NewOrderAlerts.show(o, _openOrder);

  void _openOrder(StoreOrder o) {
    appNavigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => OrderDetailsScreen(orderId: o.id)));
  }

  Future<void> _maybeWelcome() async {
    final session = context.read<Session>();
    if (!session.welcomeSuperAdmin) return;
    session.clearWelcome();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.verified_user_rounded, size: 44, color: ctx.extra.gold),
        title: Text('أهلاً بك ${session.staff?.displayName ?? ''}'),
        content: const Text(
          'تم إنشاء حسابك كـ«مدير رئيسي» في تطبيق إدارة ممهدون.\n\n'
          'لديك كل الصلاحيات: الكتب والأقسام والطلبات وإعدادات المكتبة وإدارة المديرين. '
          'كل حساب جديد يُنشأ بعد الآن يبقى بانتظار موافقتك، '
          'وتوافق عليه أو ترفضه وتحدد صلاحيته من شاشة «المديرون».',
        ),
        actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('ابدأ'))],
      ),
    );
  }

  void _go(Dest d) {
    if (!_dests.contains(d)) return;
    setState(() {
      _current = d;
      _visited.add(d);
    });
  }

  Widget _page(Dest d) => switch (d) {
    Dest.dashboard => const DashboardScreen(),
    Dest.orders => const OrdersScreen(),
    Dest.books => const BooksScreen(),
    Dest.categories => const CategoriesScreen(),
    Dest.settings => const SettingsScreen(),
    Dest.staff => const StaffScreen(),
    Dest.account => const AccountScreen(),
  };

  int _badge(Dest d, {required int newOrders, required int pending}) => switch (d) {
    Dest.orders => newOrders,
    Dest.staff => pending,
    _ => 0,
  };

  Widget _icon(Dest d, bool selected, int badge) {
    final icon = Icon(selected ? d.selectedIcon : d.icon);
    return badge > 0 ? Badge(label: Text('$badge'), child: icon) : icon;
  }

  @override
  Widget build(BuildContext context) {
    final newOrders = context.select<OrdersFeed, int>((f) => f.countOf(OrderStatus.newOrder));
    final pending = _role.isSuper ? context.select<StaffFeed, int>((f) => f.pendingCount) : 0;
    final wide = MediaQuery.sizeOf(context).width >= 900;

    final body = IndexedStack(
      index: _dests.indexOf(_current),
      children: [for (final d in _dests) _visited.contains(d) ? _page(d) : const SizedBox.shrink()],
    );

    return ShellController(
      go: _go,
      child: wide ? _wideLayout(body, newOrders, pending) : _phoneLayout(body, newOrders, pending),
    );
  }

  Widget _wideLayout(Widget body, int newOrders, int pending) {
    final session = context.watch<Session>();
    return Scaffold(
      body: Row(
        children: [
          Container(
            width: 260,
            color: context.extra.navyBar,
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                    child: Row(
                      children: [
                        const BrandMark(size: 48),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(AppConfig.appName, style: context.text.titleLarge?.copyWith(color: goldLight)),
                              Text(
                                session.role?.label ?? '',
                                style: context.text.bodySmall?.copyWith(color: ivory.withValues(alpha: 0.7)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(color: ivory.withValues(alpha: 0.12), height: 1),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      children: [
                        for (final d in _dests)
                          _SideItem(
                            dest: d,
                            selected: d == _current,
                            badge: _badge(d, newOrders: newOrders, pending: pending),
                            onTap: () => _go(d),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      session.staff?.displayName ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall?.copyWith(color: ivory.withValues(alpha: 0.6)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }

  Widget _phoneLayout(Widget body, int newOrders, int pending) {
    const maxItems = 5;
    final overflow = _dests.length > maxItems;
    final primary = overflow ? _dests.take(maxItems - 1).toList() : _dests;
    final more = overflow ? _dests.skip(maxItems - 1).toList() : <Dest>[];
    final moreBadge = more.fold(0, (s, d) => s + _badge(d, newOrders: newOrders, pending: pending));
    final selectedIndex = primary.contains(_current) ? primary.indexOf(_current) : primary.length;

    return Scaffold(
      body: SafeArea(bottom: false, child: body),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (i) {
          if (i < primary.length) {
            _go(primary[i]);
          } else {
            _showMore(more, newOrders, pending);
          }
        },
        destinations: [
          for (final d in primary)
            NavigationDestination(
              icon: _icon(d, false, _badge(d, newOrders: newOrders, pending: pending)),
              selectedIcon: _icon(d, true, _badge(d, newOrders: newOrders, pending: pending)),
              label: d.label == 'إعدادات المكتبة' ? 'الإعدادات' : d.label,
            ),
          if (overflow)
            NavigationDestination(
              icon: moreBadge > 0
                  ? Badge(label: Text('$moreBadge'), child: const Icon(Icons.more_horiz_rounded))
                  : const Icon(Icons.more_horiz_rounded),
              label: more.contains(_current) ? _current.label.split(' ').first : 'المزيد',
            ),
        ],
      ),
    );
  }

  void _showMore(List<Dest> more, int newOrders, int pending) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final d in more)
              ListTile(
                leading: _icon(d, d == _current, _badge(d, newOrders: newOrders, pending: pending)),
                title: Text(d.label),
                selected: d == _current,
                onTap: () {
                  Navigator.pop(ctx);
                  _go(d);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _SideItem extends StatelessWidget {
  const _SideItem({required this.dest, required this.selected, required this.badge, required this.onTap});

  final Dest dest;
  final bool selected;
  final int badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Material(
      color: selected ? gold.withValues(alpha: 0.16) : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(
                selected ? dest.selectedIcon : dest.icon,
                color: selected ? goldLight : ivory.withValues(alpha: 0.75),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  dest.label,
                  style: context.text.titleSmall?.copyWith(color: selected ? goldLight : ivory.withValues(alpha: 0.85)),
                ),
              ),
              if (badge > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: danger, borderRadius: BorderRadius.circular(10)),
                  child: Text('$badge', style: context.text.labelSmall?.copyWith(color: Colors.white)),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
