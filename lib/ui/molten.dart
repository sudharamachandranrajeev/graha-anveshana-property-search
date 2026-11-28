import 'dart:math' as math;

import 'package:brahma_core/brahma_core.dart' show EmptyState;
import 'package:flutter/material.dart';

// The Molten look: grey stone slabs on a steel canvas, rims and cracks that
// glow rose gold, molten drips and a little smoke. Every shape is drawn in
// code, so it stays sharp at any size. Edges wobble a little, but the same
// size always gives the same edge, so nothing flickers between frames.
// Drawing stays inside a widget's own padding or outside its edge where
// there is room (dialogs, tooltips); it never covers text.

/// The palette. Text colours are checked against the stone for contrast
/// (body text 6.5:1, muted 4.6:1 or better).
abstract final class Forge {
  static const steelTop = Color(0xFF55575B);
  static const steelBottom = Color(0xFF1F2022);
  static const stone = Color(0xFF4A4C50);
  static const stoneLight = Color(0xFF6E7075);
  static const stoneDark = Color(0xFF38393C);
  static const stoneDeep = Color(0xFF2A2B2E);
  static const rose = Color(0xFFE29D7E);
  static const roseBright = Color(0xFFF6BEA2);
  static const copper = Color(0xFFA6583D);
  static const ember = Color(0xFFFF9466);
  static const lava = Color(0xFFFFD3A8);
  static const text = Color(0xFFFAF5F2);
  static const muted = Color(0xFFD6CFCA);
  static const error = Color(0xFFF07A6E);
  static const warning = Color(0xFFEDBB5C);
  static const success = Color(0xFF9CCB8F);
}

/// Marks a theme as Molten, so widgets with a Molten form can find it.
class Molten extends ThemeExtension<Molten> {
  const Molten();

  static bool on(BuildContext context) => Theme.of(context).extension<Molten>() != null;

  @override
  Molten copyWith() => this;

  @override
  Molten lerp(covariant ThemeExtension<Molten>? other, double t) => this;
}

// ---------------------------------------------------------------------------
// Organic shapes.

final _shapes = <(double, double, double, int, double), Path>{};

/// A rounded rectangle whose edge wanders inwards by up to [wobble] px, the
/// same way every time for the same size and [seed]. It never leaves [r].
Path organicRect(Rect r, double radius, {int seed = 0, double wobble = 1.2}) {
  final w = r.width, h = r.height;
  if (w <= 0 || h <= 0 || !w.isFinite || !h.isFinite) return Path();
  final key = ((w * 2).roundToDouble() / 2, (h * 2).roundToDouble() / 2, radius, seed, wobble);
  var p = _shapes[key];
  if (p == null) {
    p = _organic(key.$1, key.$2, radius, seed, wobble);
    // Sizes that animate fill this; it starts again rather than grow.
    if (_shapes.length > 512) _shapes.clear();
    _shapes[key] = p;
  }
  // Scale the cached shape onto the exact size (it differs by under 0.25 px).
  final sx = key.$1 == 0 ? 1.0 : w / key.$1, sy = key.$2 == 0 ? 1.0 : h / key.$2;
  final m = Matrix4.identity()
    ..translateByDouble(r.left, r.top, 0, 1)
    ..scaleByDouble(sx, sy, 1, 1);
  return p.transform(m.storage);
}

Path _organic(double w, double h, double radius, int seed, double wobble) {
  final r = math.max(0.0, math.min(radius, math.min(w, h) / 2));
  final rnd = math.Random(seed * 7919 + (w * 31).round() + (h * 17).round());
  final f1 = 2 + rnd.nextInt(3), f2 = 5 + rnd.nextInt(4);
  final p1 = rnd.nextDouble() * 2 * math.pi, p2 = rnd.nextDouble() * 2 * math.pi;
  final sw = w - 2 * r, sh = h - 2 * r, arc = math.pi * r / 2;
  final total = 2 * sw + 2 * sh + 4 * arc;
  final path = Path();
  if (total <= 0) return path..addRect(Rect.fromLTWH(0, 0, w, h));
  final n = (total / 5).clamp(24, 260).round();
  for (var i = 0; i < n; i++) {
    final s = total * i / n;
    final (pt, normal) = _along(s, w, h, r, sw, sh, arc);
    final u = s / total;
    final noise =
        0.5 + 0.5 * (0.6 * math.sin(2 * math.pi * f1 * u + p1) + 0.4 * math.sin(2 * math.pi * f2 * u + p2));
    final q = pt - normal * (wobble * noise);
    i == 0 ? path.moveTo(q.dx, q.dy) : path.lineTo(q.dx, q.dy);
  }
  return path..close();
}

/// The point [s] px along a rounded rectangle's edge, clockwise from the
/// top-left corner's end, with its outward normal.
(Offset, Offset) _along(double s, double w, double h, double r, double sw, double sh, double arc) {
  Offset corner(Offset c, double from, double d) {
    final a = from + (r == 0 ? 0 : d / r);
    return Offset(math.cos(a), math.sin(a));
  }

  var d = s;
  if (d <= sw) return (Offset(r + d, 0), const Offset(0, -1));
  d -= sw;
  if (d <= arc) {
    final n = corner(Offset(w - r, r), -math.pi / 2, d);
    return (Offset(w - r, r) + n * r, n);
  }
  d -= arc;
  if (d <= sh) return (Offset(w, r + d), const Offset(1, 0));
  d -= sh;
  if (d <= arc) {
    final n = corner(Offset(w - r, h - r), 0, d);
    return (Offset(w - r, h - r) + n * r, n);
  }
  d -= arc;
  if (d <= sw) return (Offset(w - r - d, h), const Offset(0, 1));
  d -= sw;
  if (d <= arc) {
    final n = corner(Offset(r, h - r), math.pi / 2, d);
    return (Offset(r, h - r) + n * r, n);
  }
  d -= arc;
  if (d <= sh) return (Offset(0, h - r - d), const Offset(-1, 0));
  d -= sh;
  final n = corner(Offset(r, r), math.pi, math.min(d, arc));
  return (Offset(r, r) + n * r, n);
}

// ---------------------------------------------------------------------------
// Surfaces.

/// The four surface tokens, plus a bare edge.
enum Stone {
  /// A slab: bevelled, a thin rose rim.
  base,

  /// Lifted: a glowing rose-gold rim.
  raised,

  /// Sunk into the surface: shadow inside the edge.
  inset,

  /// Pressed in hard: sunk, with glowing cracks from the edge.
  pressed,

  /// Only the rim.
  flat,
}

/// The stone edge for cards, buttons, chips, dialogs and tooltips. It draws
/// only near the edge (bevel, rim, glow, cracks) and outside it (drips,
/// smoke), never across what the surface holds.
class StoneBorder extends OutlinedBorder {
  const StoneBorder({
    super.side = BorderSide.none,
    this.radius = 12,
    this.kind = Stone.base,
    this.glow = 0,
    this.seed = 0,
    this.wobble = 1.2,
    this.drips = 0,
    this.dripColor,
    this.smoke = false,
    this.cracked = false,
  });

  final double radius;
  final Stone kind;

  /// Glowing cracks running in from the edge (a dialog asking for care).
  final bool cracked;

  /// 0 to 1: how far the rose glow reaches outside the edge (up to 6 px).
  final double glow;
  final int seed;
  final double wobble;

  /// Molten drips hanging from the bottom edge (elevation level 4).
  final int drips;
  final Color? dripColor;

  /// Smoke curling off two corners.
  final bool smoke;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      organicRect(rect, radius, seed: seed, wobble: wobble);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      organicRect(rect.deflate(side.width), math.max(0, radius - side.width), seed: seed, wobble: wobble);

  @override
  StoneBorder copyWith({
    BorderSide? side,
    double? radius,
    Stone? kind,
    double? glow,
    int? drips,
    Color? dripColor,
    bool? smoke,
  }) => StoneBorder(
    side: side ?? this.side,
    radius: radius ?? this.radius,
    kind: kind ?? this.kind,
    glow: glow ?? this.glow,
    seed: seed,
    wobble: wobble,
    drips: drips ?? this.drips,
    dripColor: dripColor ?? this.dripColor,
    smoke: smoke ?? this.smoke,
    cracked: cracked,
  );

  @override
  ShapeBorder scale(double t) => copyWith(side: side.scale(t), radius: radius * t);

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) {
    if (a is StoneBorder) return _lerp(a, this, t);
    return super.lerpFrom(a, t);
  }

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) {
    if (b is StoneBorder) return _lerp(this, b, t);
    return super.lerpTo(b, t);
  }

  static StoneBorder _lerp(StoneBorder a, StoneBorder b, double t) {
    final near = t < 0.5 ? a : b;
    return StoneBorder(
      side: BorderSide.lerp(a.side, b.side, t),
      radius: a.radius + (b.radius - a.radius) * t,
      kind: near.kind,
      glow: a.glow + (b.glow - a.glow) * t,
      seed: near.seed,
      wobble: near.wobble,
      drips: near.drips,
      dripColor: near.dripColor,
      smoke: near.smoke,
      cracked: near.cracked,
    );
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (rect.isEmpty) return;
    final path = getOuterPath(rect);
    if (smoke) paintSmoke(canvas, rect, seed: seed);
    if (drips > 0) _paintDrips(canvas, rect);
    if (glow > 0) {
      // Blurring the filled shape, outside only: the halo starts at the edge.
      canvas.drawPath(
        path,
        Paint()
          ..color = Forge.ember.withValues(alpha: 0.35 + 0.35 * glow)
          ..maskFilter = MaskFilter.blur(BlurStyle.outer, 1.5 + 3 * glow),
      );
    }
    switch (kind) {
      case Stone.base || Stone.raised:
        _bevel(canvas, rect, path);
      case Stone.inset:
        _sunk(canvas, rect, path);
      case Stone.pressed:
        _sunk(canvas, rect, path);
        paintCracks(canvas, rect, path, seed: seed, count: 5, reach: math.min(7, rect.shortestSide / 4));
      case Stone.flat:
        break;
    }
    if (cracked) {
      paintCracks(canvas, rect, path, seed: seed, count: 7, reach: math.min(14, rect.shortestSide / 8));
    }
    if (side.style != BorderStyle.none && side.width > 0) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = side.width
          ..shader = kind == Stone.raised
              ? const LinearGradient(colors: [Forge.roseBright, Forge.copper, Forge.rose]).createShader(rect)
              : null
          ..color = side.color,
      );
    }
  }

  /// Light on the top-left edge, shade on the bottom-right: a cut slab.
  static void _bevel(Canvas canvas, Rect rect, Path path) {
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.22),
            Colors.white.withValues(alpha: 0.02),
            Colors.black.withValues(alpha: 0.4),
          ],
          stops: const [0, 0.5, 1],
        ).createShader(rect),
    );
  }

  /// Shadow just inside the edge: a recess.
  static void _sunk(Canvas canvas, Rect rect, Path path) {
    canvas.save();
    canvas.clipPath(path);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = Colors.black.withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.restore();
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.black.withValues(alpha: 0.5), Colors.white.withValues(alpha: 0.14)],
        ).createShader(rect),
    );
  }

  void _paintDrips(Canvas canvas, Rect rect) {
    final rnd = math.Random(seed + 101);
    // Stone at the edge, cooling to glowing copper at the bead.
    final fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [dripColor ?? Forge.stone, Forge.copper, Forge.ember],
        stops: const [0.2, 0.75, 1],
      ).createShader(Rect.fromLTRB(rect.left, rect.bottom - 2, rect.right, rect.bottom + 26));
    final shine = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.18);
    for (var i = 0; i < drips; i++) {
      // Spread along the bottom, clear of the rounded corners.
      final x = rect.left + radius + (rect.width - 2 * radius) * ((i + 0.3 + 0.4 * rnd.nextDouble()) / drips);
      final width = 7 + rnd.nextDouble() * 7;
      final length = 9 + rnd.nextDouble() * 16;
      final drip = dripPath(Offset(x, rect.bottom - 1.5), width, length);
      canvas.drawPath(drip, fill);
      canvas.drawPath(drip, shine);
    }
  }

  @override
  bool operator ==(Object other) =>
      other is StoneBorder &&
      other.side == side &&
      other.radius == radius &&
      other.kind == kind &&
      other.glow == glow &&
      other.seed == seed &&
      other.wobble == wobble &&
      other.drips == drips &&
      other.dripColor == dripColor &&
      other.smoke == smoke &&
      other.cracked == cracked;

  @override
  int get hashCode => Object.hash(side, radius, kind, glow, seed, wobble, drips, dripColor, smoke, cracked);
}

/// A drop of molten stone hanging from [top]: a neck [width] wide that
/// thins, then a round bead at the end, [length] px down.
Path dripPath(Offset top, double width, double length) {
  final bead = width * 0.36;
  final tip = top + Offset(0, length);
  return Path()
    ..moveTo(top.dx - width / 2, top.dy)
    ..cubicTo(
      top.dx - width / 2,
      top.dy + length * 0.35,
      tip.dx - bead * 0.55,
      tip.dy - bead * 1.8,
      tip.dx - bead,
      tip.dy - bead * 0.2,
    )
    ..arcToPoint(Offset(tip.dx + bead, tip.dy - bead * 0.2), radius: Radius.circular(bead), clockwise: false)
    ..cubicTo(
      tip.dx + bead * 0.55,
      tip.dy - bead * 1.8,
      top.dx + width / 2,
      top.dy + length * 0.35,
      top.dx + width / 2,
      top.dy,
    )
    ..close();
}

/// Cracks running in from the edge of [path], glowing ember inside.
void paintCracks(Canvas canvas, Rect rect, Path path, {required int seed, int count = 4, double reach = 6}) {
  final metric = path.computeMetrics().firstOrNull;
  if (metric == null || reach <= 1) return;
  final rnd = math.Random(seed + 7);
  final glow = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.4
    ..strokeCap = StrokeCap.round
    ..color = Forge.ember.withValues(alpha: 0.55)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6);
  final dark = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.9
    ..strokeCap = StrokeCap.round
    ..color = Forge.stoneDeep;
  for (var i = 0; i < count; i++) {
    final at = metric.length * ((i + rnd.nextDouble() * 0.6) / count);
    final tangent = metric.getTangentForOffset(at);
    if (tangent == null) continue;
    // Inwards is the tangent turned a quarter towards the middle.
    var inward = Offset(-tangent.vector.dy, tangent.vector.dx);
    if ((rect.center - tangent.position).dx * inward.dx + (rect.center - tangent.position).dy * inward.dy <
        0) {
      inward = -inward;
    }
    final crack = Path()..moveTo(tangent.position.dx, tangent.position.dy);
    var p = tangent.position;
    const steps = 3;
    for (var s = 1; s <= steps; s++) {
      final side = Offset(inward.dy, -inward.dx) * ((rnd.nextDouble() - 0.5) * reach * 0.5);
      p = tangent.position + inward * (reach * s / steps) + side;
      crack.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(crack, glow);
    canvas.drawPath(crack, dark);
  }
}

/// Soft grey smoke drifting off the top-right and bottom-left corners of
/// [rect], outside it.
void paintSmoke(Canvas canvas, Rect rect, {int seed = 0, double strength = 1}) {
  final rnd = math.Random(seed + 33);
  final puff = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
  for (final (corner, dir) in [
    (rect.topRight + const Offset(-6, 6), const Offset(0.6, -1)),
    (rect.bottomLeft + const Offset(6, -6), const Offset(-0.7, 0.4)),
  ]) {
    for (var i = 0; i < 5; i++) {
      final along = 6.0 + i * 9;
      final c = corner + dir * along + Offset(rnd.nextDouble() * 10 - 5, rnd.nextDouble() * 10 - 5);
      puff.color = const Color(0xFFB9B6B4).withValues(alpha: (0.16 - i * 0.025) * strength);
      canvas.drawCircle(c, 9 + i * 3.5, puff);
    }
  }
}

/// A twisted rose-gold rope along the bottom of an app bar: the thick
/// (4 px) border.
class RopeEdge extends ShapeBorder {
  const RopeEdge();

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => Path()..addRect(rect);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => Path()..addRect(rect);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) => paintRope(
    canvas,
    Offset(rect.left + 16, rect.bottom - 2.5),
    Offset(rect.right - 16, rect.bottom - 2.5),
  );

  @override
  ShapeBorder scale(double t) => this;
}

/// Two strands twisting around a line from [a] to [b], [thickness] px.
void paintRope(Canvas canvas, Offset a, Offset b, {double thickness = 4}) {
  final length = (b - a).distance;
  if (length < 8) return;
  final dir = (b - a) / length;
  final normal = Offset(-dir.dy, dir.dx);
  final amp = thickness / 2 - 0.6;
  final period = thickness * 2.6;
  for (final (phase, color) in [(0.0, Forge.copper), (math.pi, Forge.roseBright)]) {
    final strand = Path();
    for (var d = 0.0; d <= length; d += 1.5) {
      final p = a + dir * d + normal * (amp * math.sin(d / period * 2 * math.pi + phase));
      d == 0 ? strand.moveTo(p.dx, p.dy) : strand.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      strand,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness * 0.45
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }
}

/// The text field's edge: sunk into the stone (the inset layer), a thin
/// rose rim; focused, a glowing ring 3 px thick; with an error, cracked and
/// glowing red.
class FieldBorder extends InputBorder {
  const FieldBorder({
    super.borderSide = const BorderSide(color: Forge.rose),
    this.focus = 0,
    this.error = false,
  });

  /// 0 to 1, animated by the field as it gains focus.
  final double focus;
  final bool error;

  static const _radius = 12.0;

  @override
  bool get isOutline => false;

  @override
  FieldBorder copyWith({BorderSide? borderSide, double? focus, bool? error}) => FieldBorder(
    borderSide: borderSide ?? this.borderSide,
    focus: focus ?? this.focus,
    error: error ?? this.error,
  );

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(borderSide.width);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      organicRect(rect.deflate(borderSide.width), _radius - borderSide.width, wobble: 0.8);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => organicRect(rect, _radius, wobble: 0.8);

  @override
  ShapeBorder scale(double t) => copyWith(borderSide: borderSide.scale(t));

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) {
    if (a is FieldBorder) {
      return FieldBorder(
        borderSide: BorderSide.lerp(a.borderSide, borderSide, t),
        focus: a.focus + (focus - a.focus) * t,
        error: t < 0.5 ? a.error : error,
      );
    }
    return super.lerpFrom(a, t);
  }

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) {
    if (b is FieldBorder) {
      return FieldBorder(
        borderSide: BorderSide.lerp(borderSide, b.borderSide, t),
        focus: focus + (b.focus - focus) * t,
        error: t < 0.5 ? error : b.error,
      );
    }
    return super.lerpTo(b, t);
  }

  @override
  void paint(
    Canvas canvas,
    Rect rect, {
    double? gapStart,
    double gapExtent = 0.0,
    double gapPercentage = 0.0,
    TextDirection? textDirection,
  }) {
    if (rect.isEmpty) return;
    final path = getOuterPath(rect);
    StoneBorder._sunk(canvas, rect, path);
    final hot = error ? Forge.error : Forge.ember;
    if (focus > 0 || error) {
      canvas.drawPath(
        path,
        Paint()
          ..color = hot.withValues(alpha: 0.3 + 0.35 * focus)
          ..maskFilter = MaskFilter.blur(BlurStyle.outer, 1.5 + 1.5 * focus),
      );
    }
    if (error) paintCracks(canvas, rect, path, seed: 3, count: 6, reach: 5);
    if (borderSide.style == BorderStyle.none || borderSide.width == 0) return;
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderSide.width
        ..color = borderSide.color,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is FieldBorder && other.borderSide == borderSide && other.focus == focus && other.error == error;

  @override
  int get hashCode => Object.hash(borderSide, focus, error);
}

// ---------------------------------------------------------------------------
// Slider parts: a cracked groove with molten stone in it, a rose bead.

class MoltenRangeTrack extends RangeSliderTrackShape with BaseRangeSliderTrackShape {
  const MoltenRangeTrack();

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required Offset startThumbCenter,
    required Offset endThumbCenter,
    bool isEnabled = false,
    bool isDiscrete = false,
    required TextDirection textDirection,
    double additionalActiveTrackHeight = 2,
  }) {
    final rect = getPreferredRect(parentBox: parentBox, offset: offset, sliderTheme: sliderTheme);
    paintMoltenTrack(context.canvas, rect, startThumbCenter.dx, endThumbCenter.dx);
  }
}

/// The groove, the molten run from [from] to [to], cracks off it and the
/// ruler ticks below.
void paintMoltenTrack(Canvas canvas, Rect rect, double from, double to) {
  final groove = RRect.fromRectAndRadius(rect, Radius.circular(rect.height / 2));
  canvas.drawRRect(groove, Paint()..color = Forge.stoneDeep);
  canvas.drawRRect(
    groove,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.black.withValues(alpha: 0.5),
  );
  final lo = math.min(from, to), hi = math.max(from, to);
  final run = Rect.fromLTRB(lo, rect.top + 1, hi, rect.bottom - 1);
  if (run.width > 0) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(run.inflate(1.5), Radius.circular(rect.height)),
      Paint()
        ..color = Forge.ember.withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(run, Radius.circular(rect.height / 2)),
      Paint()
        ..shader = const LinearGradient(colors: [Forge.copper, Forge.lava, Forge.rose]).createShader(run),
    );
    // Hairline cracks running off the hot stone into the groove's lip.
    final crack = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = Forge.ember.withValues(alpha: 0.7);
    for (var x = lo + 14; x < hi - 6; x += 23) {
      final up = (x ~/ 23).isEven;
      final y = up ? rect.top : rect.bottom;
      final s = up ? -1 : 1;
      canvas.drawPath(
        Path()
          ..moveTo(x, y)
          ..lineTo(x + 2, y + s * 3)
          ..lineTo(x - 1, y + s * 5),
        crack,
      );
    }
  }
  final tick = Paint()
    ..strokeWidth = 1
    ..color = Forge.muted.withValues(alpha: 0.55);
  const n = 10;
  for (var i = 0; i <= n; i++) {
    final x = rect.left + rect.width * i / n;
    final long = i % 5 == 0;
    canvas.drawLine(Offset(x, rect.bottom + 7), Offset(x, rect.bottom + (long ? 13 : 10)), tick);
  }
}

/// A rose-gold bead with a bright spot.
class BeadThumb extends RangeSliderThumbShape {
  const BeadThumb();

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => const Size.square(20);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    bool isDiscrete = false,
    bool isEnabled = false,
    bool? isOnTop,
    required SliderThemeData sliderTheme,
    TextDirection? textDirection,
    Thumb? thumb,
    bool? isPressed,
  }) => paintBead(context.canvas, center, 9 + 2 * activationAnimation.value, glow: isEnabled);
}

void paintBead(Canvas canvas, Offset center, double r, {bool glow = true, bool hot = true}) {
  if (glow) {
    canvas.drawCircle(
      center,
      r + 2,
      Paint()
        ..color = Forge.ember.withValues(alpha: hot ? 0.55 : 0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
  }
  canvas.drawCircle(
    center,
    r,
    Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.4),
        colors: hot
            ? const [Color(0xFFFFF1E6), Forge.roseBright, Forge.copper]
            : const [Color(0xFFE8E6E4), Forge.stoneLight, Forge.stoneDark],
        stops: const [0, 0.45, 1],
      ).createShader(Rect.fromCircle(center: center, radius: r)),
  );
}

// ---------------------------------------------------------------------------
// Drawn pieces.

/// Paints with a fixed size and no state.
class _Paint extends StatelessWidget {
  const _Paint(this.size, this.painter, {this.label});
  final Size size;
  final CustomPainter painter;
  final String? label;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    image: label != null,
    child: RepaintBoundary(
      child: CustomPaint(size: size, painter: painter),
    ),
  );
}

/// A gear outline with [teeth] teeth.
Path gearPath(Offset c, double r, {int teeth = 8}) {
  final p = Path();
  final inner = r * 0.78;
  for (var i = 0; i < teeth * 4; i++) {
    final a = i / (teeth * 4) * 2 * math.pi;
    final rr = (i % 4 == 1 || i % 4 == 2) ? r : inner;
    final pt = c + Offset(math.cos(a), math.sin(a)) * rr;
    i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
  }
  p.close();
  return p..addOval(Rect.fromCircle(center: c, radius: r * 0.32));
}

/// A swirl of stone and rose gold, turned by [turn] (0 to 1).
void paintSwirl(Canvas canvas, Offset c, double r, {double turn = 0, int seed = 0}) {
  canvas.drawCircle(
    c,
    r,
    Paint()
      ..shader = const RadialGradient(
        colors: [Forge.stoneLight, Forge.stone, Forge.stoneDeep],
        stops: [0, 0.55, 1],
      ).createShader(Rect.fromCircle(center: c, radius: r)),
  );
  canvas.save();
  canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: r - 1)));
  final arms = 3;
  for (var k = 0; k < arms; k++) {
    final start = 2 * math.pi * (k / arms + turn + seed * 0.13);
    for (var i = 0; i < 26; i++) {
      final t0 = i / 26, t1 = (i + 1) / 26;
      Offset at(double t) {
        final a = start + t * 3.4;
        return c + Offset(math.cos(a), math.sin(a)) * (r * 0.1 + r * 0.85 * t);
      }

      final rose = k == 0;
      canvas.drawLine(
        at(t0),
        at(t1),
        Paint()
          ..strokeWidth = r * (0.05 + 0.22 * t0)
          ..strokeCap = StrokeCap.round
          ..color = (rose ? Forge.rose : const Color(0xFFBDBAB7)).withValues(alpha: 0.25 + 0.6 * (1 - t0)),
      );
    }
  }
  canvas.restore();
  canvas.drawCircle(
    c,
    r,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..shader = const SweepGradient(colors: [Forge.roseBright, Forge.copper, Forge.rose, Forge.roseBright])
          .createShader(Rect.fromCircle(center: c, radius: r)),
  );
}

/// A contact's avatar: their own swirl, the same every time for the name.
class SwirlAvatar extends StatelessWidget {
  const SwirlAvatar(this.name, {super.key, this.size = 44});
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) =>
      _Paint(Size.square(size), _SwirlPainter(name.hashCode & 0xFF), label: 'Avatar for $name');
}

class _SwirlPainter extends CustomPainter {
  const _SwirlPainter(this.seed);
  final int seed;

  @override
  void paint(Canvas canvas, Size size) =>
      paintSwirl(canvas, size.center(Offset.zero), size.shortestSide / 2 - 1, seed: seed);

  @override
  bool shouldRepaint(_SwirlPainter old) => old.seed != seed;
}

/// Turns while something loads: a swirl and two small gears. Still when the
/// platform asks for less motion.
class MoltenSpinner extends StatefulWidget {
  const MoltenSpinner({super.key, this.size = 56});
  final double size;

  @override
  State<MoltenSpinner> createState() => _MoltenSpinnerState();
}

class _MoltenSpinnerState extends State<MoltenSpinner> with SingleTickerProviderStateMixin {
  late final _turn = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (still) {
      _turn.stop();
    } else if (!_turn.isAnimating) {
      _turn.repeat();
    }
  }

  @override
  void dispose() {
    _turn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Loading',
    child: RepaintBoundary(
      child: AnimatedBuilder(
        animation: _turn,
        builder: (_, _) => CustomPaint(size: Size.square(widget.size), painter: _SpinnerPainter(_turn.value)),
      ),
    ),
  );
}

class _SpinnerPainter extends CustomPainter {
  const _SpinnerPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2;
    final c = size.center(Offset.zero) - Offset(r * 0.12, r * 0.12);
    paintSwirl(canvas, c, r * 0.78, turn: -t);
    final gear = Paint()..color = Forge.stoneLight;
    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Forge.rose;
    for (final (at, gr, dir, teeth) in [
      (Offset(size.width - r * 0.3, size.height - r * 0.42), r * 0.26, 1.0, 8),
      (Offset(size.width - r * 0.72, size.height - r * 0.14), r * 0.16, -1.6, 6),
    ]) {
      canvas.save();
      canvas.translate(at.dx, at.dy);
      canvas.rotate(dir * t * 2 * math.pi);
      final g = gearPath(Offset.zero, gr, teeth: teeth)..fillType = PathFillType.evenOdd;
      canvas.drawPath(g, gear);
      canvas.drawPath(g, rim);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_SpinnerPainter old) => old.t != t;
}

/// A molten progress bar. With a [value], the run of hot stone stops there
/// and drips, and [label] ("Loading: 60%") sits in the bar. Without one, a
/// glowing run flows along it, pushed by a gear.
class MoltenProgress extends StatefulWidget {
  const MoltenProgress({super.key, this.value, this.label, this.height = 16});
  final double? value;
  final String? label;
  final double height;

  @override
  State<MoltenProgress> createState() => _MoltenProgressState();
}

class _MoltenProgressState extends State<MoltenProgress> with SingleTickerProviderStateMixin {
  late final _flow = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(MoltenProgress old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (widget.value != null || still) {
      _flow.stop();
    } else if (!_flow.isAnimating) {
      _flow.repeat();
    }
  }

  @override
  void dispose() {
    _flow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.value;
    final label = widget.label;
    // Room below the bar for the drip and the gear's lower teeth.
    final bar = SizedBox(
      height: widget.height + 10,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _flow,
          builder: (_, _) => CustomPaint(
            painter: _ProgressPainter(v?.clamp(0, 1).toDouble(), _flow.value, widget.height),
            child: label == null || widget.height < 14
                ? null
                : Padding(
                    padding: const EdgeInsets.only(left: 12, bottom: 10),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: widget.height * 0.62,
                          height: 1,
                          fontWeight: FontWeight.w600,
                          color: Forge.stoneDeep,
                          shadows: const [Shadow(color: Color(0x66FFFFFF), blurRadius: 2)],
                        ),
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
    return Semantics(
      label: label ?? 'Loading',
      value: v == null ? null : '${(v * 100).round()}%',
      child: bar,
    );
  }
}

class _ProgressPainter extends CustomPainter {
  const _ProgressPainter(this.value, this.flow, this.h);
  final double? value;
  final double flow;
  final double h;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, h);
    final r = Radius.circular(h / 2);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, r), Paint()..color = Forge.stoneDeep);
    StoneBorder._sunk(canvas, rect, Path()..addRRect(RRect.fromRectAndRadius(rect, r)));
    final inner = rect.deflate(2);
    final hot = Paint()
      ..shader = const LinearGradient(colors: [Forge.copper, Forge.ember, Forge.lava]).createShader(inner);
    final v = value;
    if (v != null) {
      if (v <= 0) return;
      final run = Rect.fromLTWH(inner.left, inner.top, inner.width * v, inner.height);
      canvas.drawRRect(RRect.fromRectAndRadius(run, Radius.circular(inner.height / 2)), hot);
      if (run.width > inner.height) {
        // A drop forming under the leading edge.
        final x = run.right - inner.height * 0.6;
        canvas.drawPath(dripPath(Offset(x, rect.bottom - 2), h * 0.42, 9), Paint()..color = Forge.ember);
        canvas.drawCircle(
          Offset(x, rect.bottom + 6),
          h * 0.16,
          Paint()..color = Forge.lava.withValues(alpha: 0.9),
        );
      }
      return;
    }
    // Indeterminate: a run of hot stone flows along, a gear at its head.
    final len = inner.width * 0.34;
    final head = inner.left + (inner.width + len) * flow;
    final run = Rect.fromLTRB(
      math.max(inner.left, head - len),
      inner.top,
      math.min(inner.right, head),
      inner.bottom,
    );
    if (run.width > 0) {
      canvas.save();
      canvas.clipRRect(RRect.fromRectAndRadius(inner, Radius.circular(inner.height / 2)));
      canvas.drawRect(
        run,
        Paint()
          ..shader = const LinearGradient(colors: [Color(0x00A6583D), Forge.ember, Forge.lava])
              .createShader(run),
      );
      canvas.restore();
    }
    if (head > inner.left && head < inner.right) {
      canvas.save();
      canvas.translate(head, rect.center.dy);
      canvas.rotate(flow * 4 * math.pi);
      final g = gearPath(Offset.zero, h * 0.62, teeth: 8)..fillType = PathFillType.evenOdd;
      canvas.drawPath(g, Paint()..color = Forge.stoneLight);
      canvas.drawPath(
        g,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Forge.rose,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ProgressPainter old) => old.value != value || old.flow != flow || old.h != h;
}

/// Grey rows standing in for results still loading: a dot and two bars,
/// pulsing gently.
class SkeletonRows extends StatefulWidget {
  const SkeletonRows({super.key, this.rows = 3});
  final int rows;

  @override
  State<SkeletonRows> createState() => _SkeletonRowsState();
}

class _SkeletonRowsState extends State<SkeletonRows> with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (still) {
      _pulse.value = 0.5;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Loading results',
    child: RepaintBoundary(
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (_, _) => Column(
          children: [
            for (var i = 0; i < widget.rows; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: SizedBox(
                  height: 36,
                  child: CustomPaint(painter: _SkeletonPainter(_pulse.value, i), size: Size.infinite),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class _SkeletonPainter extends CustomPainter {
  const _SkeletonPainter(this.t, this.row);
  final double t;
  final int row;

  @override
  void paint(Canvas canvas, Size size) {
    final a = 0.35 + 0.3 * t;
    final blur = Paint()
      ..color = Forge.stoneLight.withValues(alpha: a)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
    final cy = size.height / 2;
    // A small drop, then a long bar and a short one, like the reference.
    canvas.drawPath(dripPath(Offset(12, cy - 8), 8, 14), blur);
    final w = size.width - 40;
    canvas.drawRRect(
      RRect.fromLTRBR(36, cy - 8, 36 + w * (0.82 - row * 0.09), cy - 2, const Radius.circular(3)),
      blur,
    );
    canvas.drawRRect(
      RRect.fromLTRBR(36, cy + 3, 36 + w * (0.46 + row * 0.07), cy + 8, const Radius.circular(3)),
      blur,
    );
  }

  @override
  bool shouldRepaint(_SkeletonPainter old) => old.t != t || old.row != row;
}

/// A home's stage as molten beads on a cracked chain: past stages cool
/// stone, the one it is at glowing with a note above and "STEP n: …" below.
class StepBeads extends StatelessWidget {
  const StepBeads({super.key, required this.steps, required this.at, this.note, this.onTap});
  final List<String> steps;

  /// The step it is at, or -1 for none of them.
  final int at;

  /// Shown in a bubble above the glowing bead.
  final String? note;
  final ValueChanged<int>? onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return LayoutBuilder(
      builder: (context, box) {
        final n = steps.length;
        final w = box.maxWidth;
        final gap = n < 2 ? 0.0 : (w - 48) / (n - 1);
        double xAt(int i) => n < 2 ? w / 2 : 24 + gap * i;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (note != null && at >= 0)
              SizedBox(
                height: 30,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      // Centred over the bead, kept inside the card.
                      left: (xAt(at) - 90).clamp(0, math.max(0, w - 180)).toDouble(),
                      width: math.min(180, w),
                      top: 0,
                      child: Center(
                        child: DecoratedBox(
                          decoration: const ShapeDecoration(
                            color: Forge.stoneDark,
                            shape: StoneBorder(
                              radius: 8,
                              kind: Stone.flat,
                              side: BorderSide(color: Forge.rose, width: 1),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            child: Text(
                              note!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t.labelSmall?.copyWith(color: Forge.text),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            SizedBox(
              height: 44,
              child: Stack(
                children: [
                  Positioned.fill(child: CustomPaint(painter: _BeadsPainter(n, at, xAt))),
                  for (var i = 0; i < n; i++)
                    Positioned(
                      left: xAt(i) - 22,
                      top: 0,
                      width: 44,
                      height: 44,
                      child: Semantics(
                        button: onTap != null,
                        selected: i == at,
                        label: steps[i],
                        child: Tooltip(
                          message: steps[i],
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: onTap == null ? null : () => onTap!(i),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (at >= 0)
              Text(
                'STEP ${at + 1}: ${steps[at].toUpperCase()}',
                textAlign: TextAlign.center,
                style: t.labelMedium?.copyWith(color: Forge.roseBright, letterSpacing: 1.2),
              ),
          ],
        );
      },
    );
  }
}

class _BeadsPainter extends CustomPainter {
  const _BeadsPainter(this.n, this.at, this.xAt);
  final int n, at;
  final double Function(int) xAt;

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    final link = Paint()
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < n - 1; i++) {
      final a = Offset(xAt(i), cy), b = Offset(xAt(i + 1), cy);
      final hot = i < at;
      link.color = hot ? Forge.copper : Forge.stoneDark;
      canvas.drawLine(a, b, link);
      // A crack in each link, glowing in the stretch already done.
      final m = Offset.lerp(a, b, 0.5)!;
      canvas.drawPath(
        Path()
          ..moveTo(m.dx - 3, cy - 3)
          ..lineTo(m.dx + 1, cy)
          ..lineTo(m.dx - 1, cy + 3),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = hot ? Forge.lava : Colors.black.withValues(alpha: 0.5),
      );
    }
    for (var i = 0; i < n; i++) {
      final current = i == at;
      paintBead(canvas, Offset(xAt(i), cy), current ? 13 : 9, glow: current, hot: i <= at);
    }
  }

  @override
  bool shouldRepaint(_BeadsPainter old) => old.n != n || old.at != at;
}

/// A trail of where something sits: dots on a line, names under them.
/// Every crumb but the last can be tapped.
class Breadcrumbs extends StatelessWidget {
  const Breadcrumbs(this.items, {super.key, this.onTap});
  final List<String> items;
  final ValueChanged<int>? onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      label: 'Where you are: ${items.join(', then ')}',
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 6,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onTap == null || i == items.length - 1 ? null : () => onTap!(i),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CustomPaint(
                      size: const Size.square(12),
                      painter: _CrumbDot(first: i == 0, last: i == items.length - 1),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      items[i],
                      style: t.labelMedium?.copyWith(
                        color: i == items.length - 1 ? Forge.text : Forge.muted,
                        fontWeight: i == items.length - 1 ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (i < items.length - 1)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 2),
                child: Text('›', style: TextStyle(color: Forge.rose)),
              ),
          ],
        ],
      ),
    );
  }
}

class _CrumbDot extends CustomPainter {
  const _CrumbDot({required this.first, required this.last});
  final bool first, last;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    if (first) {
      canvas.drawCircle(
        c,
        5.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = Forge.rose,
      );
      canvas.drawCircle(c, 2.5, Paint()..color = Forge.roseBright);
    } else if (last) {
      canvas.drawCircle(
        c,
        5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = Forge.muted,
      );
    } else {
      paintBead(canvas, c, 4.5, glow: false, hot: false);
    }
  }

  @override
  bool shouldRepaint(_CrumbDot old) => old.first != first || old.last != last;
}

/// PREV 1 2 3 NEXT: stone pebbles, the page you are on glowing.
class Pager extends StatelessWidget {
  const Pager({super.key, required this.count, required this.at, required this.onChanged});
  final int count, at;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    // At most five numbers, around the page you are on.
    final first = (at - 2).clamp(0, math.max(0, count - 5)).toInt();
    final last = math.min(count - 1, first + 4);
    Widget pebble(String text, int? to, {bool on = false, String? tip}) {
      final enabled = to != null && !on;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Tooltip(
          message: tip ?? 'Photo ${int.tryParse(text) ?? ''}',
          child: Material(
            color: on ? Forge.copper : (enabled ? Forge.stone : Forge.stoneDark),
            shape: StoneBorder(
              radius: 18,
              kind: on ? Stone.raised : Stone.base,
              glow: on ? 0.8 : 0,
              seed: text.hashCode & 0xF,
              side: BorderSide(color: on ? Forge.roseBright : Forge.rose.withValues(alpha: 0.3)),
            ),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: enabled ? () => onChanged(to) : null,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Center(
                    widthFactor: 1,
                    child: Text(
                      text,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        letterSpacing: text.length > 2 ? 1 : 0,
                        color: enabled || on ? Forge.text : Forge.muted.withValues(alpha: 0.6),
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

    return Wrap(
      alignment: WrapAlignment.center,
      runSpacing: 6,
      children: [
        pebble('PREV', at > 0 ? at - 1 : null, tip: 'Previous photo'),
        for (var i = first; i <= last; i++) pebble('${i + 1}', i, on: i == at),
        pebble('NEXT', at < count - 1 ? at + 1 : null, tip: 'Next photo'),
      ],
    );
  }
}

/// A small glowing NEW tag.
class NewBadge extends StatelessWidget {
  const NewBadge({super.key, this.text = 'NEW'});
  final String text;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const ShapeDecoration(
      color: Forge.copper,
      shape: StoneBorder(
        radius: 10,
        kind: Stone.raised,
        glow: 0.5,
        side: BorderSide(color: Forge.roseBright),
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
          color: Colors.white,
        ),
      ),
    ),
  );
}

/// Nothing here yet: an astronaut on a grey moon, the title and what to do.
class MoltenEmpty extends StatelessWidget {
  const MoltenEmpty({super.key, required this.title, this.message, this.actions = const []});
  final String title;
  final String? message;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        children: [
          const ExcludeSemantics(child: _Paint(Size(220, 132), _AstronautPainter())),
          const SizedBox(height: 12),
          Text(title, style: t.titleMedium, textAlign: TextAlign.center),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: t.bodyMedium?.copyWith(color: Forge.muted),
            ),
          ],
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 18),
            Wrap(spacing: 12, runSpacing: 12, alignment: WrapAlignment.center, children: actions),
          ],
        ],
      ),
    );
  }
}

class _AstronautPainter extends CustomPainter {
  const _AstronautPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    // Stars and a crescent moon.
    final star = Paint()..color = Forge.muted.withValues(alpha: 0.7);
    for (final (x, y, r) in [
      (0.12, 0.12, 1.2),
      (0.3, 0.05, 0.9),
      (0.62, 0.1, 1.1),
      (0.9, 0.35, 0.9),
      (0.06, 0.4, 0.8),
    ]) {
      canvas.drawCircle(Offset(w * x, h * y), r, star);
    }
    final moon = Offset(w * 0.82, h * 0.14);
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addOval(Rect.fromCircle(center: moon, radius: 9)),
        Path()..addOval(Rect.fromCircle(center: moon + const Offset(4, -3), radius: 8)),
      ),
      Paint()..color = Forge.rose,
    );
    // Rocky ground with a crater.
    final ground = Path()..moveTo(0, h * 0.78);
    for (var i = 0; i <= 12; i++) {
      final x = w * i / 12;
      final y = h * (0.74 + 0.05 * math.sin(i * 1.7) + 0.03 * math.cos(i * 3.1));
      ground.lineTo(x, y);
    }
    ground
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
      ground,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Forge.stoneLight, Forge.stoneDeep],
        ).createShader(Rect.fromLTWH(0, h * 0.7, w, h * 0.3)),
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.2, h * 0.9), width: 34, height: 8),
      Paint()..color = Forge.stoneDeep,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.78, h * 0.93), width: 22, height: 6),
      Paint()..color = Forge.stoneDeep,
    );

    // The astronaut, standing a little to the left of the middle.
    final suit = Paint()..color = const Color(0xFFDAD6D2);
    final shade = Paint()..color = const Color(0xFFA9A5A1);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Forge.stoneDeep;
    final c = Offset(w * 0.47, h * 0.5);
    // Backpack, legs, body, arms, helmet.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: c + const Offset(-9, 2), width: 26, height: 30),
        const Radius.circular(5),
      ),
      shade,
    );
    for (final dx in [-7.0, 7.0]) {
      final leg = RRect.fromRectAndRadius(
        Rect.fromCenter(center: c + Offset(dx, 26), width: 11, height: 22),
        const Radius.circular(4),
      );
      canvas.drawRRect(leg, suit);
      canvas.drawRRect(leg, line);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: c + Offset(dx + 1, 37), width: 14, height: 6),
          const Radius.circular(3),
        ),
        shade,
      );
    }
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: c + const Offset(0, 6), width: 30, height: 32),
      const Radius.circular(9),
    );
    canvas.drawRRect(body, suit);
    canvas.drawRRect(body, line);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: c + const Offset(0, 6), width: 12, height: 9),
        const Radius.circular(2),
      ),
      Paint()..color = Forge.rose,
    );
    for (final (from, to) in [
      (c + const Offset(-14, 0), c + const Offset(-22, 14)),
      (c + const Offset(14, 0), c + const Offset(24, -8)),
    ]) {
      canvas.drawLine(
        from,
        to,
        Paint()
          ..strokeWidth = 9
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFFDAD6D2),
      );
    }
    final helmet = c + const Offset(0, -16);
    canvas.drawCircle(helmet, 13, suit);
    canvas.drawCircle(helmet, 13, line);
    final visor = RRect.fromRectAndRadius(
      Rect.fromCenter(center: helmet + const Offset(2, 0), width: 18, height: 12),
      const Radius.circular(6),
    );
    canvas.drawRRect(visor, Paint()..color = Forge.stoneDeep);
    canvas.drawArc(
      visor.outerRect.deflate(2),
      -2.6,
      1.2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = Forge.roseBright,
    );
  }

  @override
  bool shouldRepaint(_AstronautPainter old) => false;
}

/// The steel canvas behind every page: lit from the top, darker below, a
/// little smoke drifting in from the edges.
class MoltenCanvasPainter extends CustomPainter {
  const MoltenCanvasPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, -1.1),
          radius: 1.5,
          colors: [Forge.steelTop, Color(0xFF3A3B3E), Forge.steelBottom],
          stops: [0, 0.55, 1],
        ).createShader(rect),
    );
    final puff = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40);
    for (final (x, y, r, a) in [
      (1.02, 0.08, 90.0, 0.07),
      (-0.04, 0.62, 110.0, 0.06),
      (0.9, 0.95, 80.0, 0.05),
    ]) {
      puff.color = const Color(0xFFC9C6C3).withValues(alpha: a);
      canvas.drawCircle(Offset(size.width * x, size.height * y), r, puff);
    }
  }

  @override
  bool shouldRepaint(MoltenCanvasPainter old) => false;
}

/// A tooltip's edge: a small stone tablet with a drop of molten stone
/// under it. The drop is 5 px long; tooltips sit far enough from what they
/// explain (see the theme's verticalOffset) that it never touches it.
class DropBorder extends ShapeBorder {
  const DropBorder({this.side = const BorderSide(color: Forge.rose), this.fill = Forge.stoneDark});
  final BorderSide side;
  final Color fill;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => organicRect(rect, 8, seed: 2, wobble: 0.6);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => getOuterPath(rect);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (rect.isEmpty) return;
    if (rect.width > 40) {
      final drop = dripPath(Offset(rect.left + rect.width * 0.72, rect.bottom - 1), 6, 5);
      canvas.drawPath(drop, Paint()..color = fill);
      canvas.drawPath(
        drop,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = side.color.withValues(alpha: 0.7),
      );
    }
    if (side.style == BorderStyle.none || side.width == 0) return;
    canvas.drawPath(
      getOuterPath(rect),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = side.width
        ..color = side.color,
    );
  }

  @override
  ShapeBorder scale(double t) => DropBorder(side: side.scale(t), fill: fill);
}

/// A line chart of [values] in molten rose gold: a glowing line over a
/// fading fill, drops hanging from the peaks and a bead on the latest.
/// Point i sits in the middle of the i-th of [values].length equal columns,
/// so a row of Expanded boxes laid over it lines up with the points.
class DripLineChart extends StatelessWidget {
  const DripLineChart(this.values, {super.key, this.height = 56});
  final List<int> values;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: RepaintBoundary(
      child: CustomPaint(painter: _DripLinePainter(values), size: Size.infinite),
    ),
  );
}

class _DripLinePainter extends CustomPainter {
  const _DripLinePainter(this.values);
  final List<int> values;

  @override
  void paint(Canvas canvas, Size size) {
    final n = values.length;
    if (n == 0 || size.isEmpty) return;
    const dripRoom = 16.0;
    final floor = size.height - dripRoom;
    final top = values.fold(0, math.max);
    Offset at(int i) =>
        Offset(size.width * (i + 0.5) / n, top == 0 ? floor - 2 : 6 + (floor - 8) * (1 - values[i] / top));
    final points = [for (var i = 0; i < n; i++) at(i)];
    final line = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < n; i++) {
      final a = points[i - 1], b = points[i];
      final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
      line.quadraticBezierTo(a.dx, a.dy, mid.dx, mid.dy);
      if (i == n - 1) line.lineTo(b.dx, b.dy);
    }
    final area = Path.from(line)
      ..lineTo(points.last.dx, floor)
      ..lineTo(points.first.dx, floor)
      ..close();
    final box = Rect.fromLTRB(0, 0, size.width, floor);
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Forge.rose.withValues(alpha: 0.35), Forge.rose.withValues(alpha: 0)],
        ).createShader(box),
    );
    // Drops hang from the peaks, inside the room left under the floor.
    final drop = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Forge.rose, Forge.copper],
      ).createShader(Offset.zero & size);
    for (var i = 0; i < n; i++) {
      final v = values[i];
      final peak = v > 0 && (i == 0 || v >= values[i - 1]) && (i == n - 1 || v >= values[i + 1]);
      if (!peak) continue;
      final p = points[i];
      canvas.drawPath(dripPath(p + const Offset(0, 1), 7, math.min(14, size.height - p.dy - 2)), drop);
    }
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = Forge.ember.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..shader = const LinearGradient(colors: [Forge.copper, Forge.rose, Forge.lava]).createShader(box),
    );
    paintBead(canvas, points.last, 4.5);
  }

  @override
  bool shouldRepaint(_DripLinePainter old) => !_same(old.values, values);

  static bool _same(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

// ---------------------------------------------------------------------------
// Pieces that follow the look: Molten's own form under the Molten theme,
// the usual Material one otherwise.

/// Something is loading: the molten swirl, or Material's ring.
class LoadingMark extends StatelessWidget {
  const LoadingMark({super.key});

  @override
  Widget build(BuildContext context) =>
      Molten.on(context) ? const MoltenSpinner() : const CircularProgressIndicator();
}

/// A progress bar: molten stone with [label] in it, or Material's line.
/// Without a [value] it shows work going on.
class LoadingBar extends StatelessWidget {
  const LoadingBar({super.key, this.value, this.label, this.minHeight});
  final double? value;
  final String? label;

  /// The Material line's thickness.
  final double? minHeight;

  @override
  Widget build(BuildContext context) => Molten.on(context)
      ? MoltenProgress(value: value, label: label, height: label == null ? 8 : 16)
      : LinearProgressIndicator(value: value, minHeight: minHeight);
}

/// Nothing to show yet: the astronaut on the moon, or Brahma's icon and
/// words. Same arguments as [EmptyState].
class EmptyNote extends StatelessWidget {
  const EmptyNote({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actions = const [],
  });
  final IconData icon;
  final String title;
  final String? message;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Molten.on(context)
      ? MoltenEmpty(title: title, message: message, actions: actions)
      : EmptyState(icon: icon, title: title, message: message, actions: actions);
}
