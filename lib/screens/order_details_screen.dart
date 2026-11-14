import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../models/models.dart';
import '../services/feeds.dart';
import '../services/format.dart';
import '../services/launch.dart';
import '../services/receipt_pdf.dart';
import '../widgets/common.dart';
import '../widgets/receipt_view.dart';
import 'orders_screen.dart';

class OrderDetailsScreen extends StatefulWidget {
  const OrderDetailsScreen({super.key, required this.orderId});

  final String orderId;

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  late Future<List<OrderItem>> _items = OrdersFeed.items(widget.orderId);
  late Future<List<StatusChange>> _history = OrdersFeed.history(widget.orderId);
  final _note = TextEditingController();
  bool _noteLoaded = false;
  bool _savingNote = false;
  bool _changing = false;
  OrderStatus? _lastStatus;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _setStatus(StoreOrder o, OrderStatus s) async {
    if (s == o.status || _changing) return;
    if (s == OrderStatus.cancelled &&
        !await confirmDialog(
          context,
          title: 'إلغاء الطلب',
          message: 'هل تريد تغيير حالة الطلب ${o.number} إلى «ملغي»؟',
          confirm: 'نعم، إلغاء',
          destructive: true,
        )) {
      return;
    }
    if (!mounted) return;
    setState(() => _changing = true);
    try {
      await context.read<OrdersFeed>().setStatus(o.id, s);
      if (mounted) {
        setState(() => _history = OrdersFeed.history(o.id));
        showMessage(context, 'تم تغيير الحالة إلى «${s.label}»');
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _changing = false);
    }
  }

  Future<void> _saveNote(StoreOrder o) async {
    setState(() => _savingNote = true);
    try {
      await context.read<OrdersFeed>().setNote(o.id, _note.text.trim());
      if (mounted) showMessage(context, 'تم حفظ الملاحظة');
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _savingNote = false);
    }
  }

  Future<void> _share(StoreOrder o) async {
    final catalog = context.read<CatalogFeed>();
    await runWithProgress(context, () async {
      final settings = await catalog.loadSettings();
      final items = await _items;
      if (!mounted) return;
      await ReceiptPdf.share(context, [(o, items)], settings.whatsappNumber);
    }, label: 'جارٍ تجهيز ملف الوصل…');
  }

  @override
  Widget build(BuildContext context) {
    final feed = context.watch<OrdersFeed>();
    final o = feed.byId(widget.orderId);
    if (o == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('تفاصيل الطلب')),
        body: feed.loading
            ? const Center(child: CircularProgressIndicator())
            : const EmptyState(icon: Icons.search_off_rounded, title: 'الطلب غير موجود'),
      );
    }
    if (!_noteLoaded) {
      _note.text = o.internalNote;
      _noteLoaded = true;
    }
    if (_lastStatus != null && _lastStatus != o.status) {
      // status changed elsewhere (realtime): refresh the history
      _history = OrdersFeed.history(o.id);
    }
    _lastStatus = o.status;
    final whatsapp = context.select<CatalogFeed, String>((c) => c.settings.whatsappNumber);

    return Scaffold(
      appBar: AppBar(
        title: Text('طلب ${o.number}'),
        actions: [
          IconButton(
            tooltip: 'مشاركة الوصل PDF',
            onPressed: () => _share(o),
            icon: const Icon(Icons.ios_share_rounded),
          ),
          IconButton(
            tooltip: 'طباعة الوصل',
            onPressed: () => printReceipts(context, [o]),
            icon: const Icon(Icons.print_rounded),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= 980;
          final info = _infoColumn(o);
          final receipt = _receiptPreview(o, whatsapp);
          if (wide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SingleChildScrollView(padding: const EdgeInsets.all(18), child: info),
                ),
                SizedBox(
                  width: 470,
                  child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(0, 18, 18, 18), child: receipt),
                ),
              ],
            );
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 30),
            child: MaxWidth(
              maxWidth: kMaxReadingWidth,
              child: Column(children: [info, const SizedBox(height: 8), receipt]),
            ),
          );
        },
      ),
    );
  }

  Widget _infoColumn(StoreOrder o) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      // ── Status ──
      AppSurface(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('حالة الطلب', style: context.text.titleMedium)),
                if (_changing) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 8),
                StatusChip(o.status),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in OrderStatus.values)
                  ChoiceChip(
                    selected: o.status == s,
                    onSelected: _changing ? null : (_) => _setStatus(o, s),
                    avatar: Icon(statusIcon(s), size: 18, color: statusColor(context, s)),
                    label: Text(s.label),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'تاريخ الطلب: ${formatDateTime(o.createdAt)}',
              style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
      const SectionTitle('المشتري'),
      AppSurface(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _row('الاسم', o.customerName),
            _row('الهاتف', o.phone, isLtr: true),
            _row('المحافظة', o.governorate),
            _row('العنوان', o.address),
            _row('أقرب نقطة دالة', o.landmark.isEmpty ? '—' : o.landmark),
            if (o.notes.trim().isNotEmpty) _row('ملاحظات المشتري', o.notes),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: () => Contact.call(context, o.phone),
                  icon: const Icon(Icons.call_rounded),
                  label: const Text('اتصال'),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1FA855),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => Contact.whatsapp(
                    context,
                    o.phone,
                    message: 'مرحباً ${o.customerName}، معك مكتبة ممهدون بخصوص طلبك رقم ${o.number}.',
                  ),
                  icon: const Icon(Icons.chat_rounded),
                  label: const Text('واتساب'),
                ),
              ],
            ),
          ],
        ),
      ),
      const SectionTitle('الكتب'),
      AppSurface(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: FutureBuilder<List<OrderItem>>(
          future: _items,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snap.hasError) {
              return ErrorPanel(
                message: 'تعذّر تحميل الكتب',
                onRetry: () => setState(() => _items = OrdersFeed.items(o.id)),
              );
            }
            final items = snap.data!;
            return Column(
              children: [
                for (final it in items)
                  ListTile(
                    dense: true,
                    title: Text(it.title, style: context.text.titleSmall),
                    subtitle: Text('${it.quantity} × ${formatPrice(it.unitPrice)}'),
                    trailing: Text(formatPrice(it.lineTotal), style: context.text.titleSmall),
                  ),
                const Divider(),
                _total('مجموع الكتب (${o.itemCount} نسخة)', formatPrice(o.booksTotal)),
                _total('أجرة التوصيل — ${o.governorate}', formatPrice(o.deliveryFee)),
                _total('المبلغ المطلوب استلامه', formatPrice(o.grandTotal), strong: true),
              ],
            );
          },
        ),
      ),
      const SectionTitle('ملاحظة داخلية'),
      AppSurface(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            TextField(
              controller: _note,
              minLines: 2,
              maxLines: 5,
              maxLength: 2000,
              decoration: const InputDecoration(
                hintText: 'تظهر للموظفين فقط ولا تُطبع على الوصل',
                border: OutlineInputBorder(),
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: _savingNote ? null : () => _saveNote(o),
              icon: const Icon(Icons.save_rounded),
              label: Text(_savingNote ? 'جارٍ الحفظ…' : 'حفظ الملاحظة'),
            ),
          ],
        ),
      ),
      const SectionTitle('سجل الحالات'),
      AppSurface(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: FutureBuilder<List<StatusChange>>(
          future: _history,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final list = snap.data ?? const [];
            if (list.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: Text('لا يوجد سجل بعد')),
              );
            }
            return Column(
              children: [
                for (final h in list)
                  ListTile(
                    dense: true,
                    leading: Icon(
                      statusIcon(OrderStatus.fromCode(h.toStatus)),
                      color: statusColor(context, OrderStatus.fromCode(h.toStatus)),
                    ),
                    title: Text(
                      h.fromStatus == null
                          ? 'أُنشئ الطلب (${OrderStatus.labelOf(h.toStatus)})'
                          : '${OrderStatus.labelOf(h.fromStatus)} ← ${OrderStatus.labelOf(h.toStatus)}',
                    ),
                    subtitle: Text(
                      '${h.changedByName.isEmpty ? '—' : h.changedByName}  •  ${formatDateTime(h.changedAt)}',
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    ],
  );

  Widget _receiptPreview(StoreOrder o, String whatsapp) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SectionTitle(
        'الوصل',
        trailing: FilledButton.icon(
          onPressed: () => printReceipts(context, [o]),
          icon: const Icon(Icons.print_rounded),
          label: const Text('طباعة'),
        ),
      ),
      FutureBuilder<List<OrderItem>>(
        future: _items,
        builder: (context, snap) {
          if (!snap.hasData) return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()));
          return Center(
            child: Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 14, offset: const Offset(0, 4)),
                ],
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: ReceiptView(order: o, items: snap.data!, whatsappNumber: whatsapp),
              ),
            ),
          );
        },
      ),
    ],
  );

  Widget _row(String label, String value, {bool isLtr = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(label, style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant)),
        ),
        Expanded(
          child: SelectableText(
            isLtr ? ltr(value) : value,
            style: context.text.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    ),
  );

  Widget _total(String label, String value, {bool strong = false}) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    child: Row(
      children: [
        Expanded(child: Text(label, style: strong ? context.text.titleMedium : context.text.bodyMedium)),
        Text(
          value,
          style: (strong ? context.text.titleLarge : context.text.titleSmall)?.copyWith(
            color: strong ? context.extra.gold : null,
          ),
        ),
      ],
    ),
  );
}
