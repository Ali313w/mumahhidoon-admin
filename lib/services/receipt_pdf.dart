import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../config/app_config.dart';
import '../models/models.dart';
import '../widgets/receipt_view.dart';

/// Builds A5 receipt PDFs. Each receipt widget is rendered off screen by Flutter and embedded as a
/// high-resolution image, so Arabic shaping and RTL are exactly what Flutter draws. Works on web too.
class ReceiptPdf {
  ReceiptPdf._();

  /// 4× the A5 width in points ≈ 290 dpi when printed.
  static const _pixelRatio = 4.0;

  static ui.Image? _logo;

  static Future<ui.Image> _loadLogo() async {
    if (_logo != null) return _logo!;
    final data = await rootBundle.load('assets/branding/logo_receipt.png');
    _logo = await decodeImageFromList(data.buffer.asUint8List());
    return _logo!;
  }

  /// One page per order, in the given order.
  static Future<Uint8List> build(
    BuildContext context,
    List<(StoreOrder, List<OrderItem>)> orders,
    String whatsappNumber,
  ) async {
    final view = View.of(context);
    final logo = await _loadLogo();
    final doc = pw.Document(
      title: orders.length == 1 ? 'وصل طلب ${orders.first.$1.number}' : 'وصولات الطلبات',
      author: AppConfig.storeName,
    );
    for (final (order, items) in orders) {
      final png = await _render(
        ReceiptView(order: order, items: items, whatsappNumber: whatsappNumber, logo: logo),
        view,
      );
      final image = pw.MemoryImage(png);
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a5,
          margin: pw.EdgeInsets.zero,
          build: (_) => pw.Container(
            color: PdfColors.white,
            alignment: pw.Alignment.topCenter,
            // long orders are scaled down so the whole receipt fits on one A5 page
            child: pw.Image(image, fit: pw.BoxFit.contain, alignment: pw.Alignment.topCenter),
          ),
        ),
      );
    }
    return doc.save();
  }

  /// Opens the system print dialog (the browser's print dialog on the web).
  static Future<void> printOrders(
    BuildContext context,
    List<(StoreOrder, List<OrderItem>)> orders,
    String whatsappNumber,
  ) async {
    final bytes = await build(context, orders, whatsappNumber);
    await Printing.layoutPdf(
      name: orders.length == 1 ? 'وصل ${orders.first.$1.number}' : 'وصولات (${orders.length})',
      format: PdfPageFormat.a5,
      usePrinterSettings: false,
      onLayout: (_) async => bytes,
    );
  }

  static Future<void> share(
    BuildContext context,
    List<(StoreOrder, List<OrderItem>)> orders,
    String whatsappNumber,
  ) async {
    final bytes = await build(context, orders, whatsappNumber);
    final name = orders.length == 1 ? 'receipt-${orders.first.$1.number}.pdf' : 'receipts-${orders.length}.pdf';
    await Printing.sharePdf(bytes: bytes, filename: name);
  }

  /// Lays out and paints [widget] in its own pipeline (not attached to the screen) and returns a PNG.
  static Future<Uint8List> _render(Widget widget, ui.FlutterView view) async {
    final boundary = RenderRepaintBoundary();
    final renderView = RenderView(
      view: view,
      child: boundary,
      configuration: const ViewConfiguration(
        logicalConstraints: BoxConstraints(minWidth: ReceiptView.width, maxWidth: ReceiptView.width, maxHeight: 20000),
        physicalConstraints: BoxConstraints(minWidth: ReceiptView.width, maxWidth: ReceiptView.width, maxHeight: 20000),
        devicePixelRatio: 1,
      ),
    );
    final pipelineOwner = PipelineOwner()..rootNode = renderView;
    renderView.prepareInitialFrame();
    final focusManager = FocusManager();
    final buildOwner = BuildOwner(focusManager: focusManager);
    final root = RenderObjectToWidgetAdapter<RenderBox>(
      container: boundary,
      child: MediaQuery(
        data: const MediaQueryData(),
        child: Directionality(textDirection: TextDirection.rtl, child: widget),
      ),
    ).attachToRenderTree(buildOwner);
    buildOwner
      ..buildScope(root)
      ..finalizeTree();
    pipelineOwner
      ..flushLayout()
      ..flushCompositingBits()
      ..flushPaint();
    final image = await boundary.toImage(pixelRatio: _pixelRatio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    focusManager.dispose();
    return data!.buffer.asUint8List();
  }
}
