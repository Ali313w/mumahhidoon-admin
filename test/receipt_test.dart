import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idara/models/models.dart';
import 'package:idara/services/receipt_pdf.dart';

StoreOrder _order(String n) => StoreOrder(
      id: n,
      number: 'MM-261111-000$n',
      customerName: 'زبون تجريبي',
      phone: '07700000000',
      governorate: 'النجف',
      address: 'عنوان تجريبي',
      landmark: 'قرب الجامع',
      notes: '',
      booksTotal: 21000,
      deliveryFee: 3000,
      grandTotal: 24000,
      itemCount: 2,
      status: OrderStatus.newOrder,
      internalNote: '',
      createdAt: DateTime(2026, 11, 11, 19, 30),
    );

const _items = [
  OrderItem(orderId: '1', bookId: 'b01', title: 'ضفاف الوعي', unitPrice: 12000, quantity: 1, lineTotal: 12000),
  OrderItem(orderId: '1', bookId: 'b02', title: 'مدن الكلمات', unitPrice: 9000, quantity: 1, lineTotal: 9000),
];

void main() {
  testWidgets('bulk receipts render off screen into one multi-page A5 PDF', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(Builder(builder: (c) {
      ctx = c;
      return const SizedBox();
    }));
    final bytes = await tester.runAsync(
      () => ReceiptPdf.build(ctx, [(_order('1'), _items), (_order('2'), _items)], '9647700000000'),
    );
    expect(bytes, isNotNull);
    final text = String.fromCharCodes(bytes!);
    expect(text.startsWith('%PDF'), isTrue);
    expect(RegExp(r'/Type\s*/Page[^s]').allMatches(text).length, 2);
  });
}
