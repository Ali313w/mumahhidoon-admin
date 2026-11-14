import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/models.dart';
import 'format.dart';

/// Root navigator, used to show the new-order banner above every screen.
final appNavigatorKey = GlobalKey<NavigatorState>();

/// Short chime + an in-app banner for each new order.
class NewOrderAlerts {
  NewOrderAlerts._();

  static final _player = AudioPlayer();
  static OverlayEntry? _entry;
  static Timer? _timer;
  static final _queue = <StoreOrder>[];

  static Future<void> _chime() async {
    try {
      await _player.stop();
      await _player.play(AssetSource('sounds/new_order.wav'), volume: 1);
    } catch (_) {
      // browsers block audio until the page has been clicked once; the banner still shows
    }
  }

  static void show(StoreOrder order, void Function(StoreOrder) onOpen) {
    _chime();
    _queue.add(order);
    final overlay = appNavigatorKey.currentState?.overlay;
    if (overlay == null) return;
    _entry?.remove();
    _timer?.cancel();
    final count = _queue.length;
    final latest = order;
    _entry = OverlayEntry(
      builder: (context) => _Banner(
        order: latest,
        count: count,
        onOpen: () {
          hide();
          onOpen(latest);
        },
        onClose: hide,
      ),
    );
    overlay.insert(_entry!);
    _timer = Timer(const Duration(seconds: 8), hide);
  }

  static void hide() {
    _timer?.cancel();
    _entry?.remove();
    _entry = null;
    _queue.clear();
  }
}

class _Banner extends StatefulWidget {
  const _Banner({required this.order, required this.count, required this.onOpen, required this.onClose});

  final StoreOrder order;
  final int count;
  final VoidCallback onOpen;
  final VoidCallback onClose;

  @override
  State<_Banner> createState() => _BannerState();
}

class _BannerState extends State<_Banner> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 380))..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, -1.2),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutBack)),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: Material(
                    color: navy,
                    elevation: 10,
                    shadowColor: Colors.black54,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: const BorderSide(color: gold, width: 1.2),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: widget.onOpen,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: const BoxDecoration(color: gold, shape: BoxShape.circle),
                              child: const Icon(Icons.notifications_active_rounded, color: navyDeep),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    widget.count > 1 ? 'وصلت ${widget.count} طلبات جديدة' : 'طلب جديد ${o.number}',
                                    style: const TextStyle(
                                      color: goldLight,
                                      fontFamily: textFont,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  Text(
                                    '${o.customerName} — ${o.governorate} — ${formatPrice(o.grandTotal)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: ivory, fontFamily: textFont, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: widget.onOpen,
                              child: const Text(
                                'فتح',
                                style: TextStyle(color: gold, fontFamily: textFont, fontWeight: FontWeight.bold),
                              ),
                            ),
                            IconButton(
                              onPressed: widget.onClose,
                              icon: const Icon(Icons.close_rounded, color: ivory, size: 20),
                              tooltip: 'إغلاق',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
