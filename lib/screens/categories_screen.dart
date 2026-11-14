import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../models/models.dart';
import '../services/feeds.dart';
import '../widgets/common.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  Future<String?> _nameDialog(BuildContext context, {String initial = '', required String title}) {
    final c = TextEditingController(text: initial);
    final form = GlobalKey<FormState>();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Form(
          key: form,
          child: TextFormField(
            controller: c,
            autofocus: true,
            maxLength: 60,
            decoration: const InputDecoration(labelText: 'اسم القسم', border: OutlineInputBorder()),
            validator: (v) => (v ?? '').trim().isEmpty ? 'اكتب اسم القسم' : null,
            onFieldSubmitted: (_) {
              if (form.currentState!.validate()) Navigator.pop(ctx, c.text.trim());
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(ctx, c.text.trim());
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  Future<void> _add(BuildContext context) async {
    final catalog = context.read<CatalogFeed>();
    final name = await _nameDialog(context, title: 'قسم جديد');
    if (name == null || !context.mounted) return;
    final ok = await runWithProgress(context, () async {
      await catalog.addCategory(name);
      return true;
    });
    if (ok == true && context.mounted) showMessage(context, 'تمت إضافة القسم');
  }

  Future<void> _rename(BuildContext context, Category c) async {
    final catalog = context.read<CatalogFeed>();
    final name = await _nameDialog(context, initial: c.name, title: 'تعديل القسم');
    if (name == null || name == c.name || !context.mounted) return;
    await runWithProgress(context, () => catalog.renameCategory(c.id, name));
  }

  Future<void> _delete(BuildContext context, Category c) async {
    final catalog = context.read<CatalogFeed>();
    final count = catalog.booksIn(c.id);
    if (count > 0) {
      final others = catalog.categories.where((x) => x.id != c.id).toList();
      if (others.isEmpty) {
        showMessage(context, 'هذا القسم فيه $count كتب. أضف قسماً آخر لنقلها إليه أولاً.', error: true);
        return;
      }
      final target = await showDialog<Category>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: Text('القسم «${c.name}» فيه $count كتب'),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                'لا يُحذف القسم إلا بعد نقل كتبه. اختر القسم الذي تُنقل إليه الكتب:',
                style: ctx.text.bodyMedium,
              ),
            ),
            for (final o in others)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, o),
                child: Row(
                  children: [
                    const Icon(Icons.drive_file_move_rounded, size: 20),
                    const SizedBox(width: 10),
                    Text(o.name),
                  ],
                ),
              ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Padding(
                padding: const EdgeInsets.only(left: 12, right: 12),
                child: TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
              ),
            ),
          ],
        ),
      );
      if (target == null || !context.mounted) return;
      final ok = await confirmDialog(
        context,
        title: 'نقل ثم حذف',
        message: 'ستُنقل $count كتب إلى «${target.name}» ثم يُحذف القسم «${c.name}». متابعة؟',
        confirm: 'نقل وحذف',
        destructive: true,
      );
      if (!ok || !context.mounted) return;
      final done = await runWithProgress(context, () async {
        await catalog.moveBooks(c.id, target.id);
        await catalog.deleteCategory(c.id);
        return true;
      });
      if (done == true && context.mounted) showMessage(context, 'تم نقل الكتب وحذف القسم');
      return;
    }
    final ok = await confirmDialog(
      context,
      title: 'حذف القسم',
      message: 'هل تريد حذف القسم «${c.name}»؟',
      confirm: 'حذف',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    final done = await runWithProgress(context, () async {
      await catalog.deleteCategory(c.id);
      return true;
    });
    if (done == true && context.mounted) showMessage(context, 'تم حذف القسم');
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogFeed>();
    final cats = catalog.categories;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('قسم جديد'),
      ),
      body: Column(
        children: [
          const PageHeader(title: 'الأقسام', subtitle: 'اسحب من المقبض لتغيير الترتيب في تطبيق المكتبة'),
          Expanded(
            child: catalog.error != null && cats.isEmpty
                ? ErrorPanel(message: catalog.error!, onRetry: catalog.retry)
                : catalog.loading
                ? const Center(child: CircularProgressIndicator())
                : cats.isEmpty
                ? const EmptyState(
                    icon: Icons.category_rounded,
                    title: 'لا توجد أقسام',
                    message: 'اضغط «قسم جديد» للإضافة.',
                  )
                : MaxWidth(
                    maxWidth: kMaxReadingWidth,
                    child: ReorderableListView.builder(
                      padding: const EdgeInsets.fromLTRB(14, 6, 14, 96),
                      buildDefaultDragHandles: false,
                      itemCount: cats.length,
                      onReorder: (from, to) async {
                        final list = [...cats];
                        if (to > from) to -= 1;
                        list.insert(to, list.removeAt(from));
                        try {
                          await catalog.reorder(list);
                        } catch (e) {
                          if (context.mounted) showError(context, e);
                        }
                      },
                      itemBuilder: (context, i) {
                        final c = cats[i];
                        final n = catalog.booksIn(c.id);
                        return Padding(
                          key: ValueKey(c.id),
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: AppSurface(
                            radius: 16,
                            child: ListTile(
                              leading: ReorderableDragStartListener(
                                index: i,
                                child: const Padding(
                                  padding: EdgeInsets.all(6),
                                  child: Icon(Icons.drag_indicator_rounded),
                                ),
                              ),
                              title: Text(c.name, style: context.text.titleMedium),
                              subtitle: Text('$n كتب'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'تعديل',
                                    onPressed: () => _rename(context, c),
                                    icon: const Icon(Icons.edit_rounded),
                                  ),
                                  IconButton(
                                    tooltip: 'حذف',
                                    onPressed: () => _delete(context, c),
                                    icon: Icon(Icons.delete_outline_rounded, color: context.colors.error),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
