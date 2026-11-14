import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../config/theme.dart';
import '../models/models.dart';
import '../services/format.dart';

/// The printed receipt — the same layout as the store app's receipt, at the A5 width (420 pt).
/// Always light: pure white paper and a black-on-white logo that saves printer ink.
class ReceiptView extends StatelessWidget {
  const ReceiptView({super.key, required this.order, required this.items, required this.whatsappNumber, this.logo});

  static const width = 420.0;
  static const a5Height = 595.0;

  final StoreOrder order;
  final List<OrderItem> items;
  final String whatsappNumber;

  /// Pre-decoded logo, used when the receipt is rendered off screen for printing.
  final ui.Image? logo;

  static const _navy = Color.fromARGB(255, 15, 30, 61);
  static const _gold = Color.fromARGB(255, 169, 130, 47);
  static const _goldSoft = Color.fromARGB(255, 246, 238, 216);
  static const _ink = Color.fromARGB(255, 27, 34, 54);
  static const _muted = Color.fromARGB(255, 104, 110, 128);
  static const _line = Color.fromARGB(255, 222, 212, 190);
  static const _stripe = Color.fromARGB(255, 250, 245, 233);
  static const _m = 26.0;

  static TextStyle _t(double size, Color color, {bool bold = false, bool display = false}) => TextStyle(
    fontFamily: display ? displayFont : textFont,
    fontWeight: bold || display ? FontWeight.bold : FontWeight.normal,
    fontSize: size,
    color: color,
    height: display ? 1.45 : 1.3,
    decoration: TextDecoration.none,
  );

  @override
  Widget build(BuildContext context) {
    final o = order;
    final rows = <(String, String)>[
      ('الاسم', o.customerName),
      ('الهاتف', o.phone),
      ('المحافظة', o.governorate),
      ('العنوان', o.address),
      ('أقرب نقطة دالة', o.landmark),
      if (o.notes.trim().isNotEmpty) ('الملاحظات', o.notes),
    ];
    final booksTotal = o.booksTotal;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        width: width,
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(_m, 18, _m, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header: black-on-white logo (ink friendly), name and a thin gold rule ──
            Center(
              child: logo != null
                  ? RawImage(image: logo, height: 82, filterQuality: FilterQuality.high)
                  : Image.asset('assets/branding/logo_receipt.png', height: 82, filterQuality: FilterQuality.high),
            ),
            const SizedBox(height: 6),
            Text(AppConfig.storeName, textAlign: TextAlign.center, style: _t(19, Colors.black, display: true)),
            Text(AppConfig.storeTagline, textAlign: TextAlign.center, style: _t(9, _muted)),
            const SizedBox(height: 8),
            Container(height: 1.2, color: _gold),
            const SizedBox(height: 1.8),
            Container(height: 0.5, color: _gold),
            const SizedBox(height: 16),

            // ── Title + order info ──
            Text('وصل طلب', textAlign: TextAlign.center, style: _t(17, _navy, display: true)),
            const SizedBox(height: 6),
            Container(
              height: 44,
              decoration: BoxDecoration(color: _goldSoft, borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              child: Row(
                children: [
                  Expanded(child: _info('رقم الطلب', o.number, 11.5)),
                  Expanded(child: _info('التاريخ والوقت', formatDateTime(o.createdAt), 11)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Customer ──
            _section('معلومات الزبون'),
            for (final (label, value) in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 92, child: Text(label, style: _t(10, _muted))),
                    const SizedBox(width: 6),
                    Expanded(child: Text(value, style: _t(10.5, _ink, bold: true))),
                  ],
                ),
              ),
            const SizedBox(height: 8),

            // ── Books table ──
            _section('الكتب المطلوبة'),
            Container(
              height: 24,
              decoration: BoxDecoration(color: _navy, borderRadius: BorderRadius.circular(6)),
              child: Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(start: 8),
                      child: Text('العنوان', style: _t(9.5, Colors.white, bold: true)),
                    ),
                  ),
                  _cell('الكمية', 40, _t(9.5, Colors.white, bold: true)),
                  _cell('سعر النسخة', 70, _t(9.5, Colors.white, bold: true)),
                  _cell('المجموع', 78, _t(9.5, Colors.white, bold: true)),
                ],
              ),
            ),
            for (var i = 0; i < items.length; i++)
              Container(
                decoration: BoxDecoration(
                  color: i.isOdd ? _stripe : Colors.white,
                  border: const Border(bottom: BorderSide(color: _line, width: 0.6)),
                ),
                padding: const EdgeInsets.symmetric(vertical: 6),
                constraints: const BoxConstraints(minHeight: 26),
                child: Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsetsDirectional.only(start: 8, end: 2),
                        child: Text(items[i].title, style: _t(10, _ink, bold: true)),
                      ),
                    ),
                    _cell('${items[i].quantity}', 40, _t(10, _ink)),
                    _cell(formatNumber(items[i].unitPrice), 70, _t(10, _ink)),
                    _cell(formatNumber(items[i].lineTotal), 78, _t(10, _navy, bold: true)),
                  ],
                ),
              ),
            const SizedBox(height: 14),

            // ── Totals ──
            _total('مجموع الكتب (${o.itemCount} نسخة)', formatPrice(booksTotal)),
            _total('أجرة التوصيل — ${o.governorate}', formatPrice(o.deliveryFee)),
            const SizedBox(height: 8),
            const CustomPaint(size: Size(double.infinity, 1.2), painter: _DashedLine(_line)),
            const SizedBox(height: 12),

            // big amount box
            Container(
              height: 70,
              decoration: BoxDecoration(color: _navy, borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.all(4),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: _gold, width: 1.4),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('المبلغ المطلوب استلامه من الزبون', style: _t(10, const Color.fromARGB(255, 226, 194, 122))),
                    Text(formatPrice(o.grandTotal), style: _t(25, Colors.white, bold: true).copyWith(height: 1.15)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // payment stamp
            Center(
              child: Container(
                width: 230,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: _gold, width: 1.6),
                ),
                child: Text(AppConfig.paymentMethod, style: _t(11.5, _gold, bold: true)),
              ),
            ),
            const SizedBox(height: 16),

            // footer
            Text(
              'شكراً لاختياركم ${AppConfig.storeName}',
              textAlign: TextAlign.center,
              style: _t(12, _navy, display: true),
            ),
            const SizedBox(height: 2),
            Text('واتساب المكتبة: ${ltr("+$whatsappNumber")}', textAlign: TextAlign.center, style: _t(9, _muted)),
          ],
        ),
      ),
    );
  }

  Widget _info(String label, String value, double size) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Text(label, style: _t(8.5, _muted).copyWith(height: 1.2)),
      Text(value, maxLines: 1, style: _t(size, _navy, bold: true).copyWith(height: 1.2)),
    ],
  );

  Widget _cell(String text, double width, TextStyle style) => SizedBox(
    width: width,
    child: Text(text, textAlign: TextAlign.center, style: style),
  );

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Container(
      padding: const EdgeInsets.only(bottom: 3),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _line, width: 0.8)),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(color: _gold, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 6),
          Expanded(child: Text(title, style: _t(13, _navy, display: true))),
        ],
      ),
    ),
  );

  Widget _total(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        Expanded(child: Text(label, style: _t(11, _muted))),
        Text(value, style: _t(11.5, _ink, bold: true)),
      ],
    ),
  );
}

class _DashedLine extends CustomPainter {
  const _DashedLine(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = size.height;
    final y = size.height / 2;
    for (double x = 0; x < size.width; x += 9) {
      canvas.drawLine(Offset(x, y), Offset((x + 5).clamp(0, size.width), y), p);
    }
  }

  @override
  bool shouldRepaint(_DashedLine old) => old.color != color;
}
