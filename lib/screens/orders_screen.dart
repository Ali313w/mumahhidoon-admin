import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../config/theme.dart';
import '../models/models.dart';
import '../services/feeds.dart';
import '../services/format.dart';
import '../services/receipt_pdf.dart';
import '../widgets/common.dart';
import 'order_details_screen.dart';

/// Fetches items + settings and opens the print dialog with one A5 page per order.
Future<void> printReceipts(BuildContext context, List<StoreOrder> orders) async {
  if (orders.isEmpty) return;
  final catalog = context.read<CatalogFeed>();
  await runWithProgress(context, () async {
    final settings = await catalog.loadSettings();
    final items = await OrdersFeed.itemsFor([for (final o in orders) o.id]);
    if (!context.mounted) return;
    await ReceiptPdf.printOrders(context, [
      for (final o in orders) (o, items[o.id] ?? const <OrderItem>[]),
    ], settings.whatsappNumber);
  }, label: orders.length == 1 ? 'جارٍ تجهيز الوصل للطباعة…' : 'جارٍ تجهيز ${orders.length} وصولات للطباعة…');
}

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final _search = TextEditingController();
  OrderStatus _tab = OrderStatus.newOrder;
  String? _governorate;
  DateTimeRange? _range;
  final _selected = <String>{};

  bool get _selecting => _selected.isNotEmpty;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<StoreOrder> _filter(List<StoreOrder> all) {
    final q = _search.text.trim().toLowerCase();
    final qDigits = digitsOnly(q);
    return all.where((o) {
      if (o.status != _tab) return false;
      if (_governorate != null && o.governorate != _governorate) return false;
      if (_range != null) {
        final d = DateTime(o.createdAt.year, o.createdAt.month, o.createdAt.day);
        if (d.isBefore(_range!.start) || d.isAfter(_range!.end)) return false;
      }
      if (q.isEmpty) return true;
      return o.number.toLowerCase().contains(q) ||
          o.customerName.toLowerCase().contains(q) ||
          (qDigits.length >= 3 && (o.phone.contains(qDigits) || o.number.replaceAll('-', '').contains(qDigits)));
    }).toList();
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year, now.month, now.day),
      initialDateRange: _range,
      helpText: 'اختر الفترة',
      saveText: 'تم',
    );
    if (r != null) setState(() => _range = r);
  }

  @override
  Widget build(BuildContext context) {
    final feed = context.watch<OrdersFeed>();
    final list = _filter(feed.orders);
    _selected.removeWhere((id) => feed.byId(id) == null);

    return Column(
      children: [
        if (_selecting)
          _selectionBar(list, feed)
        else
          PageHeader(
            title: 'الطلبات',
            subtitle: feed.loading ? 'جارٍ التحميل…' : 'تصل الطلبات الجديدة فوراً',
            actions: [
              IconButton(
                tooltip: 'تحديد عدة طلبات للطباعة',
                onPressed: list.isEmpty ? null : () => setState(() => _selected.add(list.first.id)),
                icon: const Icon(Icons.checklist_rounded),
              ),
            ],
          ),
        // ── Tabs by status ──
        SizedBox(
          height: 46,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            children: [
              for (final s in OrderStatus.values)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: ChoiceChip(
                    selected: _tab == s,
                    onSelected: (_) => setState(() {
                      _tab = s;
                      _selected.clear();
                    }),
                    avatar: Icon(statusIcon(s), size: 18, color: statusColor(context, s)),
                    label: Text('${s.label} (${feed.countOf(s)})'),
                  ),
                ),
            ],
          ),
        ),
        // ── Search + filters ──
        MaxWidth(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'بحث برقم الطلب أو الاسم أو الهاتف',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _search.text.isEmpty
                          ? null
                          : IconButton(onPressed: () => setState(_search.clear), icon: const Icon(Icons.close_rounded)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                PopupMenuButton<String?>(
                  tooltip: 'المحافظة',
                  onSelected: (g) => setState(() => _governorate = g == '' ? null : g),
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: '', child: Text('كل المحافظات')),
                    for (final g in governorates) PopupMenuItem(value: g, child: Text(g)),
                  ],
                  child: Chip(
                    avatar: const Icon(Icons.place_rounded, size: 18),
                    label: Text(_governorate ?? 'كل المحافظات'),
                    onDeleted: _governorate == null ? null : () => setState(() => _governorate = null),
                  ),
                ),
                InputChip(
                  avatar: const Icon(Icons.date_range_rounded, size: 18),
                  label: Text(
                    _range == null ? 'كل التواريخ' : '${formatDate(_range!.start)} — ${formatDate(_range!.end)}',
                  ),
                  onPressed: _pickRange,
                  onDeleted: _range == null ? null : () => setState(() => _range = null),
                ),
              ],
            ),
          ),
        ),
        Expanded(child: _list(feed, list)),
      ],
    );
  }

  Widget _selectionBar(List<StoreOrder> list, OrdersFeed feed) {
    final allSelected = list.isNotEmpty && list.every((o) => _selected.contains(o.id));
    return Container(
      color: context.extra.goldSoft,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => setState(_selected.clear),
            icon: const Icon(Icons.close_rounded),
            tooltip: 'إلغاء التحديد',
          ),
          Expanded(child: Text('تم تحديد ${_selected.length}', style: context.text.titleMedium)),
          TextButton(
            onPressed: () => setState(() {
              if (allSelected) {
                _selected.clear();
              } else {
                _selected.addAll(list.map((o) => o.id));
              }
            }),
            child: Text(allSelected ? 'إلغاء الكل' : 'تحديد الكل'),
          ),
          const SizedBox(width: 4),
          FilledButton.icon(
            onPressed: () {
              final chosen = feed.orders.where((o) => _selected.contains(o.id)).toList()
                ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
              printReceipts(context, chosen);
            },
            icon: const Icon(Icons.print_rounded),
            label: const Text('طباعة الوصولات'),
          ),
        ],
      ),
    );
  }

  Widget _list(OrdersFeed feed, List<StoreOrder> list) {
    if (feed.loading) return const Center(child: CircularProgressIndicator());
    if (feed.error != null && feed.orders.isEmpty) return ErrorPanel(message: feed.error!, onRetry: feed.retry);
    if (list.isEmpty) {
      final filtered = _search.text.isNotEmpty || _governorate != null || _range != null;
      return EmptyState(
        icon: filtered ? Icons.search_off_rounded : statusIcon(_tab),
        title: filtered ? 'لا توجد نتائج' : 'لا توجد طلبات «${_tab.label}»',
        message: filtered ? 'جرّب تغيير البحث أو التصفية.' : null,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(0, 6, 0, 24),
      itemCount: list.length,
      itemBuilder: (context, i) {
        final o = list[i];
        return MaxWidth(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            child: AppSurface(
              radius: 16,
              child: OrderTile(
                order: o,
                selecting: _selecting,
                selected: _selected.contains(o.id),
                onTap: _selecting
                    ? () => setState(() => _selected.contains(o.id) ? _selected.remove(o.id) : _selected.add(o.id))
                    : () => Navigator.of(
                        context,
                      ).push(MaterialPageRoute(builder: (_) => OrderDetailsScreen(orderId: o.id))),
                onLongPress: () => setState(() => _selected.add(o.id)),
              ),
            ),
          ),
        );
      },
    );
  }
}

class OrderTile extends StatelessWidget {
  const OrderTile({
    super.key,
    required this.order,
    this.onTap,
    this.onLongPress,
    this.selecting = false,
    this.selected = false,
  });

  final StoreOrder order;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool selecting;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final o = order;
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: [
            if (selecting) ...[
              Checkbox(value: selected, onChanged: (_) => onTap?.call()),
              const SizedBox(width: 4),
            ] else ...[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: statusColor(context, o.status).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(statusIcon(o.status), color: statusColor(context, o.status)),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          o.customerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.titleMedium,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        timeAgo(o.createdAt),
                        style: context.text.labelSmall?.copyWith(color: context.colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${o.number}  •  ${o.governorate}  •  ${o.itemCount} نسخة',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(formatPrice(o.grandTotal), style: context.text.titleSmall?.copyWith(color: context.extra.gold)),
                const SizedBox(height: 4),
                StatusChip(o.status, dense: true),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
