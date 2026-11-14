import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../models/models.dart';
import '../services/feeds.dart';
import '../services/format.dart';
import '../widgets/book_cover.dart';
import '../widgets/common.dart';
import 'book_edit_screen.dart';

enum _BookFilter {
  all('الكل'),
  available('متوفر'),
  unavailable('غير متوفر'),
  featured('مميز'),
  isNew('وصل حديثاً'),
  bestSeller('الأكثر طلباً'),
  offer('عرض خاص');

  const _BookFilter(this.label);

  final String label;

  bool test(Book b) => switch (this) {
    all => true,
    available => b.available,
    unavailable => !b.available,
    featured => b.featured,
    isNew => b.isNew,
    bestSeller => b.bestSeller,
    offer => b.specialOffer,
  };
}

class BooksScreen extends StatefulWidget {
  const BooksScreen({super.key});

  @override
  State<BooksScreen> createState() => _BooksScreenState();
}

class _BooksScreenState extends State<BooksScreen> {
  final _search = TextEditingController();
  String? _category;
  _BookFilter _filter = _BookFilter.all;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _open([Book? book]) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => BookEditScreen(book: book)));

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogFeed>();
    final q = _search.text.trim().toLowerCase();
    final list = catalog.books.where((b) {
      if (_category != null && b.categoryId != _category) return false;
      if (!_filter.test(b)) return false;
      return q.isEmpty || b.title.toLowerCase().contains(q) || b.author.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('إضافة كتاب'),
      ),
      body: Column(
        children: [
          PageHeader(
            title: 'الكتب',
            subtitle: '${catalog.books.length} كتاباً — التغييرات تظهر في تطبيق المكتبة فوراً',
          ),
          MaxWidth(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 380),
                    child: TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'بحث بالعنوان أو المؤلف',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _search.text.isEmpty
                            ? null
                            : IconButton(
                                onPressed: () => setState(_search.clear),
                                icon: const Icon(Icons.close_rounded),
                              ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'القسم',
                    onSelected: (v) => setState(() => _category = v.isEmpty ? null : v),
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: '', child: Text('كل الأقسام')),
                      for (final c in catalog.categories) PopupMenuItem(value: c.id, child: Text(c.name)),
                    ],
                    child: Chip(
                      avatar: const Icon(Icons.category_rounded, size: 18),
                      label: Text(_category == null ? 'كل الأقسام' : catalog.categoryName(_category)),
                      onDeleted: _category == null ? null : () => setState(() => _category = null),
                    ),
                  ),
                  PopupMenuButton<_BookFilter>(
                    tooltip: 'الحالة',
                    onSelected: (v) => setState(() => _filter = v),
                    itemBuilder: (_) => [
                      for (final f in _BookFilter.values) PopupMenuItem(value: f, child: Text(f.label)),
                    ],
                    child: Chip(
                      avatar: const Icon(Icons.filter_list_rounded, size: 18),
                      label: Text(_filter == _BookFilter.all ? 'كل الحالات' : _filter.label),
                      onDeleted: _filter == _BookFilter.all ? null : () => setState(() => _filter = _BookFilter.all),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(child: _body(catalog, list)),
        ],
      ),
    );
  }

  Widget _body(CatalogFeed catalog, List<Book> list) {
    if (catalog.error != null && catalog.books.isEmpty) {
      return ErrorPanel(message: catalog.error!, onRetry: catalog.retry);
    }
    if (catalog.loading) return const Center(child: CircularProgressIndicator());
    if (list.isEmpty) {
      return EmptyState(
        icon: Icons.menu_book_rounded,
        title: catalog.books.isEmpty ? 'لا توجد كتب بعد' : 'لا توجد نتائج',
        message: catalog.books.isEmpty ? 'اضغط «إضافة كتاب» لإضافة أول كتاب.' : 'جرّب تغيير البحث أو التصفية.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(0, 6, 0, 96),
      itemCount: list.length,
      itemBuilder: (context, i) => MaxWidth(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          child: _BookRow(
            book: list[i],
            categoryName: catalog.categoryName(list[i].categoryId),
            onTap: () => _open(list[i]),
          ),
        ),
      ),
    );
  }
}

class _BookRow extends StatelessWidget {
  const _BookRow({required this.book, required this.categoryName, required this.onTap});

  final Book book;
  final String categoryName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final b = book;
    return AppSurface(
      radius: 16,
      onTap: onTap,
      child: Opacity(
        opacity: b.available ? 1 : 0.62,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
          child: Row(
            children: [
              BookCover(book: b, width: 54, elevation: 3, corner: 4),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(b.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleMedium),
                    Text(
                      '${b.author.isEmpty ? '—' : b.author}  •  $categoryName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(formatPrice(b.price), style: context.text.titleSmall?.copyWith(color: context.extra.gold)),
                        if (b.hasDiscount)
                          Text(
                            formatNumber(b.oldPrice!),
                            style: context.text.bodySmall?.copyWith(
                              decoration: TextDecoration.lineThrough,
                              color: context.colors.onSurfaceVariant,
                            ),
                          ),
                        if (b.featured) const Pill('مميز', icon: Icons.star_rounded),
                        if (b.isNew) const Pill('جديد', color: Color(0xFF2C7BB0)),
                        if (b.bestSeller) const Pill('الأكثر طلباً', color: success),
                        if (b.specialOffer) const Pill('عرض', color: danger),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Switch(
                    value: b.available,
                    onChanged: (v) async {
                      try {
                        await context.read<CatalogFeed>().setAvailable(b, v);
                        if (context.mounted) {
                          showMessage(context, v ? 'أصبح «${b.title}» متوفراً' : 'أصبح «${b.title}» غير متوفر');
                        }
                      } catch (e) {
                        if (context.mounted) showError(context, e);
                      }
                    },
                  ),
                  Text(
                    b.available ? 'متوفر' : 'غير متوفر',
                    style: context.text.labelSmall?.copyWith(color: b.available ? null : context.colors.error),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
