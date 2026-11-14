import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../models/models.dart';
import '../services/feeds.dart';
import '../services/format.dart';
import '../services/session.dart';
import '../widgets/common.dart';
import 'order_details_screen.dart';
import 'orders_screen.dart';
import 'shell.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Future<List<(String, int)>>? _top;
  int _topForCount = -1;

  void _loadTop(int orderCount) {
    if (_topForCount == orderCount && _top != null) return;
    _topForCount = orderCount;
    _top = OrdersFeed.topBooks();
  }

  @override
  Widget build(BuildContext context) {
    final feed = context.watch<OrdersFeed>();
    final catalog = context.watch<CatalogFeed>();
    final name = context.select<Session, String>((s) => s.staff?.displayName ?? '');

    if (feed.error != null && feed.orders.isEmpty) {
      return ErrorPanel(message: feed.error!, onRetry: feed.retry);
    }
    if (!feed.loading) _loadTop(feed.orders.length);

    final now = DateTime.now();
    final valid = feed.orders.where((o) => o.status != OrderStatus.cancelled);
    final today = feed.orders.where((o) => sameDay(o.createdAt, now)).toList();
    final todaySales = valid.where((o) => sameDay(o.createdAt, now)).fold(0, (s, o) => s + o.booksTotal);
    final monthSales = valid
        .where((o) => o.createdAt.year == now.year && o.createdAt.month == now.month)
        .fold(0, (s, o) => s + o.booksTotal);
    final unavailable = catalog.books.where((b) => !b.available).length;

    // last 30 days, oldest → newest
    final start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 29));
    final days = List<int>.filled(30, 0);
    for (final o in valid) {
      final d = DateTime(o.createdAt.year, o.createdAt.month, o.createdAt.day).difference(start).inDays;
      if (d >= 0 && d < 30) days[d] += o.booksTotal;
    }

    final cards = [
      _Stat(
        'الطلبات الجديدة',
        '${feed.countOf(OrderStatus.newOrder)}',
        Icons.fiber_new_rounded,
        goldDeep,
        onTap: () => ShellController.of(context)?.go(Dest.orders),
      ),
      _Stat('طلبات اليوم', '${today.length}', Icons.today_rounded, const Color(0xFF2C5BA8)),
      _Stat('مبيعات اليوم', formatPrice(todaySales), Icons.payments_rounded, success),
      _Stat('مبيعات الشهر', formatPrice(monthSales), Icons.calendar_month_rounded, const Color(0xFF6A3FB0)),
      _Stat(
        'عدد الكتب',
        '${catalog.books.length}',
        Icons.menu_book_rounded,
        navySoft,
        onTap: () => ShellController.of(context)?.go(Dest.books),
      ),
      _Stat(
        'الكتب غير المتوفرة',
        '$unavailable',
        Icons.remove_shopping_cart_rounded,
        danger,
        onTap: () => ShellController.of(context)?.go(Dest.books),
      ),
    ];

    return RefreshIndicator(
      onRefresh: () async {
        feed.retry();
        setState(() => _top = OrdersFeed.topBooks());
      },
      child: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          MaxWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PageHeader(title: 'أهلاً $name', subtitle: 'ملخص المكتبة — ${formatDate(now)}'),
                if (feed.loading)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        LayoutBuilder(
                          builder: (context, c) {
                            final cols = c.maxWidth >= 900 ? 3 : 2;
                            const gap = 12.0;
                            final w = (c.maxWidth - gap * (cols - 1)) / cols;
                            return Wrap(
                              spacing: gap,
                              runSpacing: gap,
                              children: [for (final s in cards) SizedBox(width: w, child: _StatCard(s))],
                            );
                          },
                        ),
                        SectionTitle('مبيعات آخر ثلاثين يوماً'),
                        AppSurface(
                          padding: const EdgeInsets.fromLTRB(12, 16, 12, 10),
                          child: SizedBox(
                            height: 190,
                            child: _SalesChart(days: days, start: start),
                          ),
                        ),
                        LayoutBuilder(
                          builder: (context, c) {
                            final recent = _recent(context, feed.orders.take(6).toList());
                            final top = _topBooks(context);
                            if (c.maxWidth < 760) return Column(children: [recent, top]);
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 3, child: recent),
                                const SizedBox(width: 16),
                                Expanded(flex: 2, child: top),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _recent(BuildContext context, List<StoreOrder> orders) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SectionTitle(
        'آخر الطلبات',
        trailing: TextButton(
          onPressed: () => ShellController.of(context)?.go(Dest.orders),
          child: const Text('عرض الكل'),
        ),
      ),
      if (orders.isEmpty)
        const AppSurface(
          padding: EdgeInsets.all(24),
          child: Center(child: Text('لا توجد طلبات بعد')),
        )
      else
        AppSurface(
          child: Column(
            children: [
              for (var i = 0; i < orders.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                OrderTile(
                  order: orders[i],
                  onTap: () => Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => OrderDetailsScreen(orderId: orders[i].id))),
                ),
              ],
            ],
          ),
        ),
    ],
  );

  Widget _topBooks(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SectionTitle('أكثر الكتب طلباً'),
      AppSurface(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: FutureBuilder<List<(String, int)>>(
          future: _top,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final list = snap.data ?? const [];
            if (snap.hasError || list.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Center(child: Text(snap.hasError ? 'تعذّر التحميل' : 'لا توجد بيانات بعد')),
              );
            }
            final maxQ = list.first.$2;
            return Column(
              children: [
                for (var i = 0; i < list.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: context.extra.goldSoft,
                          child: Text('${i + 1}', style: context.text.labelMedium?.copyWith(color: context.extra.gold)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                list[i].$1,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.text.titleSmall,
                              ),
                              const SizedBox(height: 4),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: maxQ == 0 ? 0 : list[i].$2 / maxQ,
                                  minHeight: 6,
                                  color: context.extra.gold,
                                  backgroundColor: context.extra.goldSoft,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text('${list[i].$2} نسخة', style: context.text.labelMedium),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    ],
  );
}

class _Stat {
  const _Stat(this.label, this.value, this.icon, this.color, {this.onTap});

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
}

class _StatCard extends StatelessWidget {
  const _StatCard(this.s);

  final _Stat s;

  @override
  Widget build(BuildContext context) {
    final c = context.extra.isDark ? Color.lerp(s.color, Colors.white, 0.35)! : s.color;
    return AppSurface(
      onTap: s.onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: c.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
            child: Icon(s.icon, color: c),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(s.value, style: context.text.titleLarge?.copyWith(height: 1.2)),
                ),
                Text(
                  s.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Simple bar chart of daily sales (books total, without delivery).
class _SalesChart extends StatefulWidget {
  const _SalesChart({required this.days, required this.start});

  final List<int> days;
  final DateTime start;

  @override
  State<_SalesChart> createState() => _SalesChartState();
}

class _SalesChartState extends State<_SalesChart> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final total = widget.days.fold(0, (a, b) => a + b);
    final sel = _selected;
    final caption = sel == null
        ? 'المجموع: ${formatPrice(total)} (بدون أجرة التوصيل)'
        : '${formatDate(widget.start.add(Duration(days: sel)))}: ${formatPrice(widget.days[sel])}';
    return Column(
      children: [
        Text(caption, style: context.text.labelMedium?.copyWith(color: context.colors.onSurfaceVariant)),
        const SizedBox(height: 8),
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => _pick(d.localPosition.dx, c.maxWidth),
              onHorizontalDragUpdate: (d) => _pick(d.localPosition.dx, c.maxWidth),
              // the chart reads oldest → newest from left to right, like a timeline
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: CustomPaint(
                  size: Size(c.maxWidth, c.maxHeight),
                  painter: _BarsPainter(
                    values: widget.days,
                    selected: _selected,
                    bar: context.extra.gold,
                    faded: context.extra.goldSoft,
                    grid: context.colors.outlineVariant,
                    label: context.colors.onSurfaceVariant,
                    start: widget.start,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _pick(double x, double width) {
    final i = (x / width * widget.days.length).floor().clamp(0, widget.days.length - 1);
    setState(() => _selected = _selected == i ? null : i);
  }
}

class _BarsPainter extends CustomPainter {
  _BarsPainter({
    required this.values,
    required this.selected,
    required this.bar,
    required this.faded,
    required this.grid,
    required this.label,
    required this.start,
  });

  final List<int> values;
  final int? selected;
  final Color bar;
  final Color faded;
  final Color grid;
  final Color label;
  final DateTime start;

  @override
  void paint(Canvas canvas, Size size) {
    const bottomPad = 18.0;
    final h = size.height - bottomPad;
    final maxV = math.max(1, values.fold(0, math.max));
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = h - h * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    final slot = size.width / values.length;
    final w = math.max(2.0, slot * 0.62);
    for (var i = 0; i < values.length; i++) {
      final v = values[i];
      final bh = v == 0 ? 2.0 : math.max(3.0, h * v / maxV);
      final x = i * slot + (slot - w) / 2;
      final r = RRect.fromRectAndCorners(
        Rect.fromLTWH(x, h - bh, w, bh),
        topLeft: const Radius.circular(3),
        topRight: const Radius.circular(3),
      );
      final color = selected == null || selected == i ? bar : bar.withValues(alpha: 0.35);
      canvas.drawRRect(r, Paint()..color = v == 0 ? faded : color);
    }
    // a date label every 7 days
    for (var i = 0; i < values.length; i += 7) {
      final d = start.add(Duration(days: i));
      final tp = TextPainter(
        text: TextSpan(
          text: '${d.day}/${d.month}',
          style: TextStyle(color: label, fontSize: 10, fontFamily: textFont),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset((i * slot + slot / 2 - tp.width / 2).clamp(0, size.width - tp.width), h + 4));
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) =>
      old.values != values || old.selected != selected || old.bar != bar || old.grid != grid;
}
