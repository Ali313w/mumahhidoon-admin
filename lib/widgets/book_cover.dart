import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/models.dart';

/// Cover color pairs (top → bottom) plus an ornament tint.
class _CoverPalette {
  const _CoverPalette(this.top, this.bottom, this.ornament);

  final Color top;
  final Color bottom;
  final Color ornament;
}

const _palettes = [
  _CoverPalette(Color(0xFF1B2D5A), Color(0xFF0B1630), Color(0xFFE2C27A)),
  _CoverPalette(Color(0xFF6B1E2E), Color(0xFF3A0E18), Color(0xFFE9C989)),
  _CoverPalette(Color(0xFF1F5247), Color(0xFF0D2924), Color(0xFFDCC07F)),
  _CoverPalette(Color(0xFF5A3A1E), Color(0xFF2C1B0D), Color(0xFFF0D9A0)),
  _CoverPalette(Color(0xFF3B2A5E), Color(0xFF1B1232), Color(0xFFE5C886)),
  _CoverPalette(Color(0xFF2C4A6E), Color(0xFF13253C), Color(0xFFF3DDA6)),
  _CoverPalette(Color(0xFF8A5A2B), Color(0xFF4A2C12), Color(0xFFFBE7B8)),
  _CoverPalette(Color(0xFF2F3B2A), Color(0xFF151C12), Color(0xFFD9BE7C)),
  _CoverPalette(Color(0xFF7A2F4F), Color(0xFF3D1427), Color(0xFFF1D29A)),
  _CoverPalette(Color(0xFF225A6B), Color(0xFF0E2C36), Color(0xFFE8CF95)),
  _CoverPalette(Color(0xFF4E4A7A), Color(0xFF221F42), Color(0xFFEAD3A0)),
  _CoverPalette(Color(0xFF9C6B30), Color(0xFF5A3912), Color(0xFFFFF0C8)),
];

/// Same value as Java/Kotlin String.hashCode, so every book keeps the colors it had in the original app.
int _javaHash(String s) {
  var h = 0;
  for (final c in s.codeUnits) {
    h = (31 * h + c).toSigned(32);
  }
  return h;
}

_CoverPalette _paletteFor(Book book) {
  final hash = ((_javaHash(book.id) * 31).toSigned(32) + _javaHash(book.title)).toSigned(32).abs();
  return _palettes[hash % _palettes.length];
}

/// The book cover: the uploaded image (Supabase Storage) when [Book.coverUrl] is set,
/// otherwise a cover drawn in code (gradient, ornament, title, author, spine).
class BookCover extends StatelessWidget {
  const BookCover({
    super.key,
    required this.book,
    this.width = 120,
    this.elevation = 8,
    this.corner = 6,
    this.heroTag,
    this.imageBytes,
  });

  final Book book;
  final double width;
  final double elevation;
  final double corner;

  /// Shared-element tag for the cover transition between a list and the details screen.
  final String? heroTag;

  /// A freshly picked image that is not uploaded yet (book form preview).
  final Uint8List? imageBytes;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadiusDirectional.only(
      topStart: Radius.circular(corner / 2),
      bottomStart: Radius.circular(corner / 2),
      topEnd: Radius.circular(corner),
      bottomEnd: Radius.circular(corner),
    ).resolve(TextDirection.rtl);
    final height = width * 1.48;
    final drawn = _DrawnCover(book: book, width: width);
    Widget cover = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: elevation <= 0
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  blurRadius: elevation * 1.1,
                  offset: Offset(0, elevation * 0.45),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: elevation * 0.4,
                  offset: Offset(0, elevation * 0.12),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: imageBytes == null && !book.hasUploadedCover
            ? drawn
            : Stack(
                fit: StackFit.expand,
                children: [
                  if (imageBytes != null)
                    Image.memory(imageBytes!, fit: BoxFit.cover, errorBuilder: (context, error, stack) => drawn)
                  else
                    Image.network(book.coverUrl!, fit: BoxFit.cover, errorBuilder: (context, error, stack) => drawn),
                  const CustomPaint(painter: _SpinePainter(spineOnly: true)),
                ],
              ),
      ),
    );
    if (heroTag != null) {
      cover = Hero(tag: 'cover-$heroTag', child: cover);
    }
    return cover;
  }
}

class _DrawnCover extends StatelessWidget {
  const _DrawnCover({required this.book, required this.width});

  final Book book;
  final double width;

  @override
  Widget build(BuildContext context) {
    final palette = _paletteFor(book);
    final w = width;
    final titleSize = w * 0.13;
    final authorSize = w * 0.075;
    return Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(painter: _CoverPainter(palette)),
        // tiny thumbnails show only the drawing; the text would be unreadable anyway
        if (w >= 50)
          // the spine is on the physical right, so use absolute padding
          Padding(
            padding: EdgeInsets.only(left: w * 0.09, right: w * 0.17, top: w * 0.16, bottom: w * 0.12),
            child: Column(
              children: [
                SizedBox(height: w * 0.42),
                Text(
                  book.title,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: creamText,
                    fontFamily: displayFont,
                    fontWeight: FontWeight.bold,
                    fontSize: titleSize,
                    height: 1.35,
                  ),
                ),
                const Spacer(),
                Container(width: w * 0.22, height: 1, color: palette.ornament.withValues(alpha: 0.8)),
                SizedBox(height: w * 0.04),
                Text(
                  book.author,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.ornament,
                    fontFamily: textFont,
                    fontWeight: FontWeight.w500,
                    fontSize: authorSize,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _CoverPainter extends CustomPainter {
  const _CoverPainter(this.palette);

  final _CoverPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [palette.top, palette.bottom],
        ).createShader(rect),
    );
    // soft light on the upper area
    final lightCenter = Offset(size.width * 0.35, size.height * 0.18);
    final lightR = size.width * 0.9;
    canvas.drawCircle(
      lightCenter,
      lightR,
      Paint()
        ..shader = RadialGradient(
          colors: [Colors.white.withValues(alpha: 0.16), Colors.transparent],
        ).createShader(Rect.fromCircle(center: lightCenter, radius: lightR)),
    );
    _drawOrnament(canvas, size, palette.ornament);
    _SpinePainter.drawSpine(canvas, size, spineOnly: false);
  }

  /// Gold frame and an eight-point star rosette near the top of the cover.
  void _drawOrnament(Canvas canvas, Size size, Color color) {
    final w = size.width;
    final h = size.height;
    final stroke = math.max(w * 0.012, 1.0);
    final inset = w * 0.06;
    final spine = w * 0.09;
    Paint strokePaint(double alpha, double width) => Paint()
      ..color = color.withValues(alpha: alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;

    // double frame (the spine sits on the right for Arabic books)
    canvas.drawRect(Rect.fromLTWH(inset, inset, w - inset * 2 - spine, h - inset * 2), strokePaint(0.55, stroke));
    final inset2 = inset + w * 0.025;
    canvas.drawRect(
      Rect.fromLTWH(inset2, inset2, w - inset2 * 2 - spine, h - inset2 * 2),
      strokePaint(0.3, stroke * 0.7),
    );

    // rosette
    final cx = (w - spine) / 2;
    final cy = h * 0.2;
    final r = w * 0.15;
    final star = Path();
    for (var i = 0; i < 16; i++) {
      final radius = i.isEven ? r : r * 0.55;
      final angle = math.pi / 8 * i - math.pi / 2;
      final x = cx + radius * math.cos(angle);
      final y = cy + radius * math.sin(angle);
      i == 0 ? star.moveTo(x, y) : star.lineTo(x, y);
    }
    star.close();
    canvas.drawPath(star, strokePaint(0.9, stroke * 1.1));
    canvas.drawCircle(Offset(cx, cy), r * 0.22, Paint()..color = color.withValues(alpha: 0.85));
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(22.5 * math.pi / 180);
    canvas.drawRect(Rect.fromLTWH(-r * 0.42, -r * 0.42, r * 0.84, r * 0.84), strokePaint(0.35, stroke * 0.8));
    canvas.restore();

    // corner dots
    final d = w * 0.018;
    final dot = Paint()..color = color.withValues(alpha: 0.7);
    for (final o in [
      Offset(inset2 + d * 2, inset2 + d * 2),
      Offset(w - spine - inset2 - d * 2, inset2 + d * 2),
      Offset(inset2 + d * 2, h - inset2 - d * 2),
      Offset(w - spine - inset2 - d * 2, h - inset2 - d * 2),
    ]) {
      canvas.drawCircle(o, d, dot);
    }
  }

  @override
  bool shouldRepaint(_CoverPainter old) => old.palette != palette;
}

/// The spine on the right edge: darker band, hinge highlight and a page-edge shadow for depth.
class _SpinePainter extends CustomPainter {
  const _SpinePainter({required this.spineOnly});

  final bool spineOnly;

  static void drawSpine(Canvas canvas, Size size, {required bool spineOnly}) {
    final w = size.width;
    final h = size.height;
    final spine = w * 0.09;
    final band = Rect.fromLTWH(w - spine, 0, spine, h);
    canvas.drawRect(
      band,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.black.withValues(alpha: 0.05),
            Colors.black.withValues(alpha: 0.38),
            Colors.black.withValues(alpha: 0.18),
          ],
        ).createShader(band),
    );
    // hinge highlight
    canvas.drawRect(
      Rect.fromLTWH(w - spine - w * 0.012, 0, w * 0.008, h),
      Paint()..color = Colors.white.withValues(alpha: 0.22),
    );
    // hinge shadow
    final hinge = Rect.fromLTWH(w - spine - w * 0.06, 0, w * 0.048, h);
    canvas.drawRect(
      hinge,
      Paint()
        ..shader = LinearGradient(
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.25)],
        ).createShader(hinge),
    );
    if (!spineOnly) {
      // subtle sheen across the cover
      final all = Offset.zero & size;
      canvas.drawRect(
        all,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0),
              Colors.white.withValues(alpha: 0.07),
              Colors.white.withValues(alpha: 0),
            ],
          ).createShader(all),
      );
    }
  }

  @override
  void paint(Canvas canvas, Size size) => drawSpine(canvas, size, spineOnly: spineOnly);

  @override
  bool shouldRepaint(_SpinePainter old) => old.spineOnly != spineOnly;
}
