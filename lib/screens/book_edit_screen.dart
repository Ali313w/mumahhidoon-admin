import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../models/models.dart';
import '../services/cover_service.dart';
import '../services/feeds.dart';
import '../services/format.dart';
import '../widgets/book_cover.dart';
import '../widgets/common.dart';

/// Add or edit a book (with cover upload). Pass null to add.
class BookEditScreen extends StatefulWidget {
  const BookEditScreen({super.key, this.book});

  final Book? book;

  @override
  State<BookEditScreen> createState() => _BookEditScreenState();
}

class _BookEditScreenState extends State<BookEditScreen> {
  final _form = GlobalKey<FormState>();
  late final Book? _b = widget.book;
  late final _title = TextEditingController(text: _b?.title ?? '');
  late final _author = TextEditingController(text: _b?.author ?? '');
  late final _price = TextEditingController(text: _b == null ? '' : '${_b.price}');
  late final _oldPrice = TextEditingController(text: _b?.oldPrice == null ? '' : '${_b!.oldPrice}');
  late final _pages = TextEditingController(text: _b == null || _b.pages == 0 ? '' : '${_b.pages}');
  late final _description = TextEditingController(text: _b?.description ?? '');
  late String? _category = _b?.categoryId;
  late bool _available = _b?.available ?? true;
  late bool _featured = _b?.featured ?? false;
  late bool _isNew = _b?.isNew ?? (widget.book == null);
  late bool _bestSeller = _b?.bestSeller ?? false;
  late bool _offer = _b?.specialOffer ?? false;

  Uint8List? _newCover;
  bool _removeCover = false;
  bool _busy = false;
  bool _processing = false;

  bool get _isEdit => widget.book != null;

  @override
  void dispose() {
    for (final c in [_title, _author, _price, _oldPrice, _pages, _description]) {
      c.dispose();
    }
    super.dispose();
  }

  Book get _preview => Book(
    id: _b?.id ?? 'new',
    title: _title.text.trim().isEmpty ? 'عنوان الكتاب' : _title.text.trim(),
    author: _author.text.trim(),
    categoryId: _category,
    price: 0,
    coverUrl: _removeCover ? null : _b?.coverUrl,
  );

  Future<void> _pick(ImageSource source) async {
    setState(() => _processing = true);
    try {
      final bytes = await CoverService.pick(source);
      if (bytes != null && mounted) {
        setState(() {
          _newCover = bytes;
          _removeCover = false;
        });
      }
    } catch (e) {
      if (mounted) {
        showMessage(
          context,
          e is FormatException ? 'تعذّر قراءة الصورة. اختر صورة JPG أو PNG.' : 'تعذّر فتح الصورة.',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  void _coverMenu() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('اختيار من المعرض'),
              onTap: () {
                Navigator.pop(ctx);
                _pick(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: Text(kIsWeb ? 'التقاط بالكاميرا (إن توفرت)' : 'التقاط بالكاميرا'),
              onTap: () {
                Navigator.pop(ctx);
                _pick(ImageSource.camera);
              },
            ),
            if (_newCover != null || (_b?.hasUploadedCover ?? false) && !_removeCover)
              ListTile(
                leading: Icon(Icons.delete_outline_rounded, color: ctx.colors.error),
                title: Text('إزالة الصورة (استخدام الغلاف المرسوم)', style: TextStyle(color: ctx.colors.error)),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _newCover = null;
                    _removeCover = true;
                  });
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final catalog = context.read<CatalogFeed>();
    String? uploadedPath;
    try {
      String? coverUrl = _b?.coverUrl;
      String? coverPath = _b?.coverPath;
      if (_newCover != null) {
        final (path, url) = await CoverService.upload(_newCover!);
        uploadedPath = path;
        coverUrl = url;
        coverPath = path;
      } else if (_removeCover) {
        coverUrl = null;
        coverPath = null;
      }
      final oldPrice = int.tryParse(digitsOnly(_oldPrice.text));
      final data = <String, dynamic>{
        'title': _title.text.trim(),
        'author': _author.text.trim(),
        'category_id': _category,
        'price': int.parse(digitsOnly(_price.text)),
        'old_price': oldPrice == null || oldPrice == 0 ? null : oldPrice,
        'pages': int.tryParse(digitsOnly(_pages.text)) ?? 0,
        'description': _description.text.trim(),
        'cover_url': coverUrl,
        'cover_path': coverPath,
        'available': _available,
        'featured': _featured,
        'is_new': _isNew,
        'best_seller': _bestSeller,
        'special_offer': _offer,
      };
      await catalog.saveBook(_b?.id, data);
      // the old file is no longer used
      final oldPath = _b?.coverPath;
      if (oldPath != null && oldPath != coverPath) await CoverService.remove(oldPath);
      if (!mounted) return;
      showMessage(context, _isEdit ? 'تم حفظ التعديلات' : 'تمت إضافة الكتاب');
      Navigator.pop(context);
    } catch (e) {
      if (uploadedPath != null) await CoverService.remove(uploadedPath);
      if (mounted) {
        setState(() => _busy = false);
        showError(context, e);
      }
    }
  }

  Future<void> _delete() async {
    final b = _b!;
    final ok = await confirmDialog(
      context,
      title: 'حذف الكتاب',
      message: 'هل تريد حذف «${b.title}» نهائياً؟ سيختفي من تطبيق المكتبة فوراً. الطلبات السابقة تبقى كما هي.',
      confirm: 'حذف',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final catalog = context.read<CatalogFeed>();
    final done = await runWithProgress(context, () async {
      await catalog.deleteBook(b.id);
      await CoverService.remove(b.coverPath);
      return true;
    }, label: 'جارٍ الحذف…');
    if (done == true && mounted) {
      showMessage(context, 'تم حذف الكتاب');
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<CatalogFeed>().categories;
    if (_category != null && !categories.any((c) => c.id == _category)) {
      // category deleted meanwhile
      _category = categories.isEmpty ? null : _category;
    }
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEdit ? 'تعديل كتاب' : 'إضافة كتاب'),
          actions: [
            if (_isEdit)
              IconButton(
                tooltip: 'حذف الكتاب',
                onPressed: _busy ? null : _delete,
                icon: Icon(Icons.delete_outline_rounded, color: context.colors.error),
              ),
          ],
        ),
        body: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
            children: [
              MaxWidth(
                maxWidth: kMaxReadingWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _coverSection(),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _title,
                      onChanged: (_) => setState(() {}),
                      maxLength: 150,
                      decoration: const InputDecoration(labelText: 'عنوان الكتاب *', border: OutlineInputBorder()),
                      validator: (v) => (v ?? '').trim().isEmpty ? 'العنوان مطلوب' : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _author,
                      onChanged: (_) => setState(() {}),
                      maxLength: 120,
                      decoration: const InputDecoration(labelText: 'المؤلف', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: categories.any((c) => c.id == _category) ? _category : null,
                      items: [for (final c in categories) DropdownMenuItem(value: c.id, child: Text(c.name))],
                      onChanged: (v) => setState(() => _category = v),
                      decoration: const InputDecoration(labelText: 'القسم *', border: OutlineInputBorder()),
                      validator: (v) =>
                          v == null ? (categories.isEmpty ? 'أضف قسماً أولاً من شاشة الأقسام' : 'اختر القسم') : null,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _price,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩]'))],
                            decoration: const InputDecoration(labelText: 'السعر (د.ع) *', border: OutlineInputBorder()),
                            validator: (v) {
                              final n = int.tryParse(digitsOnly(v ?? ''));
                              if (n == null) return 'السعر مطلوب';
                              if (n <= 0 || n > 10000000) return 'سعر غير صحيح';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _oldPrice,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩]'))],
                            decoration: const InputDecoration(
                              labelText: 'السعر قبل الخصم',
                              helperText: 'اختياري',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) {
                              final old = int.tryParse(digitsOnly(v ?? ''));
                              final price = int.tryParse(digitsOnly(_price.text));
                              if (old == null || old == 0) return null;
                              if (price != null && old <= price) return 'يجب أن يكون أكبر من السعر';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _pages,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩]'))],
                      decoration: const InputDecoration(labelText: 'عدد الصفحات', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _description,
                      minLines: 3,
                      maxLines: 8,
                      maxLength: 3000,
                      decoration: const InputDecoration(
                        labelText: 'النبذة',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SectionTitle('الحالة والعلامات'),
                    AppSurface(
                      child: Column(
                        children: [
                          _switch(
                            'متوفر',
                            'يظهر للمشترين ويمكن طلبه',
                            Icons.inventory_rounded,
                            _available,
                            (v) => _available = v,
                          ),
                          _switch(
                            'مميز',
                            'يظهر في قسم الكتب المميزة',
                            Icons.star_rounded,
                            _featured,
                            (v) => _featured = v,
                          ),
                          _switch(
                            'وصل حديثاً',
                            'يظهر في قسم الإصدارات الجديدة',
                            Icons.fiber_new_rounded,
                            _isNew,
                            (v) => _isNew = v,
                          ),
                          _switch(
                            'الأكثر طلباً',
                            'يظهر في قسم الأكثر طلباً',
                            Icons.trending_up_rounded,
                            _bestSeller,
                            (v) => _bestSeller = v,
                          ),
                          _switch('عرض خاص', 'يظهر ضمن العروض', Icons.local_offer_rounded, _offer, (v) => _offer = v),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: MaxWidth(
              maxWidth: kMaxReadingWidth,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                onPressed: _busy || _processing ? null : _save,
                icon: _busy
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4))
                    : const Icon(Icons.save_rounded),
                label: Text(_busy ? 'جارٍ الحفظ…' : (_isEdit ? 'حفظ التعديلات' : 'إضافة الكتاب')),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _coverSection() => AppSurface(
    padding: const EdgeInsets.all(16),
    child: Row(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            BookCover(book: _preview, width: 110, imageBytes: _newCover),
            if (_processing)
              Container(
                width: 110,
                height: 110 * 1.48,
                color: Colors.black45,
                alignment: Alignment.center,
                child: const CircularProgressIndicator(color: gold),
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('صورة الغلاف', style: context.text.titleMedium),
              const SizedBox(height: 4),
              Text(
                _newCover != null
                    ? 'صورة جديدة (${(_newCover!.length / 1024).round()} ك.ب) — تُرفع عند الحفظ'
                    : (_b?.hasUploadedCover ?? false) && !_removeCover
                    ? 'صورة مرفوعة'
                    : 'بلا صورة: يظهر الغلاف المرسوم كما في تطبيق المكتبة',
                style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _processing || _busy ? null : _coverMenu,
                icon: const Icon(Icons.add_photo_alternate_rounded),
                label: const Text('تغيير الصورة'),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _switch(String title, String subtitle, IconData icon, bool value, void Function(bool) set) => SwitchListTile(
    secondary: Icon(icon, color: context.extra.gold),
    title: Text(title),
    subtitle: Text(subtitle),
    value: value,
    onChanged: (v) => setState(() => set(v)),
  );
}
