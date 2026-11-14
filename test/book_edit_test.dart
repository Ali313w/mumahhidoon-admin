import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idara/config/theme.dart';
import 'package:idara/screens/book_edit_screen.dart';
import 'package:idara/services/feeds.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('add-book form is visible above the save bar', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => CatalogFeed(),
        child: MaterialApp(
          theme: buildTheme(dark: false),
          home: const Directionality(textDirection: TextDirection.rtl, child: BookEditScreen()),
        ),
      ),
    );
    await tester.pump();

    final title = find.text('عنوان الكتاب *');
    expect(title, findsOneWidget);
    final titleBox = tester.getRect(title);
    final saveBox = tester.getRect(find.text('إضافة الكتاب'));
    // the form must be on screen and the save button must sit at the bottom
    expect(titleBox.top, lessThan(780 / 2));
    expect(saveBox.top, greaterThan(780 * 0.8));
    expect(tester.takeException(), isNull);
  });
}
