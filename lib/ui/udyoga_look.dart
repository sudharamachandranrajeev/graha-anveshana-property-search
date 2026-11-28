import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';

// The Udyoga look, borrowed from the Udyoga app (keep in step with its
// lib/ui/look.dart): a calm, airy canvas (soft azure light, deep navy at
// night) so the content stands forward; white cards lifted by soft tinted
// shadows; an ink pill navigation bar with an azure indicator; motion that
// adds depth (cards tilt towards the pointer, pages rise in) and stops when
// the system asks for reduced motion.

const azure = Color(0xFF2F6BFF);
const night = Color(0xFF0B1020);
const mint = Color(0xFF12B886);

/// Headings: Plus Jakarta Sans. Reading text: Inter. Both bundled; inside the
/// Brahma suite a package's fonts live under `packages/<name>/`.
const headingFont = 'PlusJakartaSans';
const _headingFallback = ['packages/anveshana/PlusJakartaSans'];
const _bodyFont = 'Inter';
const _bodyFallback = ['packages/anveshana/Inter'];

/// Marks a theme as the Udyoga look, so the widgets that change with it can
/// tell (see [Udyoga.on]).
class Udyoga extends ThemeExtension<Udyoga> {
  const Udyoga();

  static bool on(BuildContext context) => Theme.of(context).extension<Udyoga>() != null;

  @override
  Udyoga copyWith() => this;

  @override
  Udyoga lerp(Udyoga? other, double t) => this;
}

/// The canvas colours behind every page.
({Color top, Color bottom, Color glow, Color glow2}) udyogaCanvas(Brightness b) => b == Brightness.dark
    ? (
        top: const Color(0xFF0A1022),
        bottom: const Color(0xFF05070F),
        glow: const Color(0x552F6BFF),
        glow2: const Color(0x3312B886),
      )
    : (
        top: const Color(0xFFDDE8FF),
        bottom: const Color(0xFFF7F9FD),
        glow: const Color(0x662F6BFF),
        glow2: const Color(0x3312B886),
      );

/// The azure of a figure or a mark, readable on either canvas.
Color udyogaAccent(Brightness b) => b == Brightness.dark ? const Color(0xFF6E9BFF) : azure;

ThemeData udyogaTheme(Brightness b) {
  final dark = b == Brightness.dark;
  final base = buildTheme(b, seed: azure, accent: mint);
  final scheme = base.colorScheme.copyWith(
    primary: udyogaAccent(b),
    onPrimary: Colors.white,
    surface: dark ? const Color(0xFF0E1426) : Colors.white,
    surfaceContainerLow: dark ? const Color(0xFF121A30) : Colors.white,
    surfaceContainerHighest: dark ? const Color(0xFF1A2440) : const Color(0xFFEFF3FB),
  );
  final c = udyogaCanvas(b);
  final shadow = dark ? Colors.black : azure.withValues(alpha: 0.35);
  final text = base.textTheme.apply(
    fontFamily: _bodyFont,
    fontFamilyFallback: _bodyFallback,
    bodyColor: dark ? const Color(0xFFE8ECF6) : night,
    displayColor: dark ? Colors.white : night,
  );
  TextStyle? heading(TextStyle? s, FontWeight w, [double spacing = -0.4]) => s?.copyWith(
    fontFamily: headingFont,
    fontFamilyFallback: _headingFallback,
    fontWeight: w,
    letterSpacing: spacing,
  );
  final type = text.copyWith(
    displayLarge: heading(text.displayLarge, FontWeight.w800, -1.2),
    displayMedium: heading(text.displayMedium, FontWeight.w800, -1),
    displaySmall: heading(text.displaySmall, FontWeight.w700, -0.8),
    headlineLarge: heading(text.headlineLarge, FontWeight.w700, -0.6),
    headlineMedium: heading(text.headlineMedium, FontWeight.w700, -0.5),
    headlineSmall: heading(text.headlineSmall, FontWeight.w700),
    titleLarge: heading(text.titleLarge, FontWeight.w700, -0.3),
    titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.1),
    titleSmall: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
    bodyLarge: text.bodyLarge?.copyWith(height: 1.5, letterSpacing: 0),
    bodyMedium: text.bodyMedium?.copyWith(height: 1.45, letterSpacing: 0),
    labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w600, letterSpacing: 0),
  );
  const stadium = StadiumBorder();
  final line = dark ? Colors.white12 : const Color(0xFFDCE3F0);
  return base.copyWith(
    colorScheme: scheme,
    textTheme: type,
    primaryTextTheme: base.primaryTextTheme.apply(fontFamily: _bodyFont, fontFamilyFallback: _bodyFallback),
    extensions: const [Udyoga()],
    // The canvas (see UdyogaCanvas) shows through every page.
    scaffoldBackgroundColor: Colors.transparent,
    canvasColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: c.top.withValues(alpha: dark ? 0.92 : 0.86),
      foregroundColor: type.titleLarge?.color,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: type.headlineSmall?.copyWith(fontSize: 22),
    ),
    cardTheme: CardThemeData(
      color: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      elevation: dark ? 0 : 2.5,
      shadowColor: shadow.withValues(alpha: dark ? 0.6 : 0.22),
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: dark ? Colors.white.withValues(alpha: 0.07) : const Color(0xFFE6ECF7)),
      ),
    ),
    dividerTheme: DividerThemeData(color: line, space: 1),
    chipTheme: base.chipTheme.copyWith(
      shape: stadium,
      side: BorderSide(color: dark ? Colors.white24 : const Color(0xFFDCE3F0)),
      backgroundColor: dark ? const Color(0xFF141C33) : Colors.white,
      selectedColor: dark ? Colors.white : night,
      secondarySelectedColor: dark ? Colors.white : night,
      checkmarkColor: dark ? night : Colors.white,
      labelStyle: type.labelLarge?.copyWith(
        fontWeight: FontWeight.w500,
        color: WidgetStateColor.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? (dark ? night : Colors.white)
              : type.labelLarge?.color ?? scheme.onSurface,
        ),
      ),
      secondaryLabelStyle: type.labelLarge?.copyWith(color: dark ? night : Colors.white),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        shape: const WidgetStatePropertyAll(stadium),
        side: WidgetStatePropertyAll(BorderSide(color: dark ? Colors.white24 : const Color(0xFFDCE3F0))),
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) =>
              s.contains(WidgetState.selected) ? (dark ? Colors.white : night) : scheme.surfaceContainerLow,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? (dark ? night : Colors.white) : type.bodyLarge?.color,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: stadium,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        textStyle: type.labelLarge?.copyWith(fontSize: 15),
        elevation: 3,
        shadowColor: shadow,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: stadium,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        side: BorderSide(color: dark ? Colors.white24 : const Color(0xFFD5DDEC)),
        backgroundColor: scheme.surfaceContainerLow,
      ),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(shape: stadium)),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: azure,
      foregroundColor: Colors.white,
      shape: stadium,
      elevation: 6,
      highlightElevation: 10,
      extendedTextStyle: type.labelLarge?.copyWith(fontSize: 15, color: Colors.white),
    ),
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      fillColor: dark ? const Color(0xFF131B31) : Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: scheme.primary, width: 1.6),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      // Lifted off the night canvas so it still reads as floating.
      backgroundColor: dark ? const Color(0xFF222C4D) : night,
      surfaceTintColor: Colors.transparent,
      indicatorColor: azure,
      indicatorShape: stadium,
      elevation: 0,
      height: 64,
      labelTextStyle: WidgetStatePropertyAll(
        type.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(color: s.contains(WidgetState.selected) ? Colors.white : Colors.white70),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: Colors.transparent,
      indicatorColor: azure,
      indicatorShape: stadium,
      selectedIconTheme: const IconThemeData(color: Colors.white),
      selectedLabelTextStyle: type.labelLarge?.copyWith(color: scheme.primary),
      unselectedLabelTextStyle: type.labelLarge?.copyWith(
        color: type.bodyMedium?.color?.withValues(alpha: 0.7),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      titleTextStyle: type.headlineSmall,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    snackBarTheme: base.snackBarTheme.copyWith(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: dark ? const Color(0xFF1C2643) : night,
    ),
    sliderTheme: base.sliderTheme.copyWith(trackHeight: 6),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      linearTrackColor: scheme.surfaceContainerHighest,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: RisePageTransitionsBuilder(),
        TargetPlatform.linux: RisePageTransitionsBuilder(),
        TargetPlatform.windows: RisePageTransitionsBuilder(),
        TargetPlatform.macOS: RisePageTransitionsBuilder(),
        TargetPlatform.iOS: RisePageTransitionsBuilder(),
        TargetPlatform.fuchsia: RisePageTransitionsBuilder(),
      },
    ),
  );
}

/// The canvas: a soft vertical wash with two faint glows, behind every page.
class UdyogaCanvas extends StatelessWidget {
  const UdyogaCanvas({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = udyogaCanvas(Theme.of(context).brightness);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [c.top, c.bottom],
          stops: const [0, 0.55],
        ),
      ),
      child: Stack(
        children: [
          Positioned(top: -160, right: -120, child: _Glow(c.glow, 420)),
          Positioned(bottom: -200, left: -160, child: _Glow(c.glow2, 460)),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow(this.color, this.size);
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    ),
  );
}

/// Pushed pages rise into place from slightly below and behind, while the
/// page underneath recedes: depth without a slide across the screen.
class RisePageTransitionsBuilder extends PageTransitionsBuilder {
  const RisePageTransitionsBuilder();

  @override
  Duration get transitionDuration => const Duration(milliseconds: 380);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // Each page brings its own canvas, so the page beneath never shows through.
    child = UdyogaCanvas(child: child);
    if (Motion.reduced(context)) return FadeTransition(opacity: animation, child: child);
    final inCurve = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutQuart,
      reverseCurve: Curves.easeInCubic,
    );
    final outCurve = CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeOutCubic);
    return AnimatedBuilder(
      animation: Listenable.merge([inCurve, outCurve]),
      child: child,
      builder: (context, child) {
        final t = inCurve.value;
        final back = outCurve.value;
        final m = Matrix4.identity()
          ..setEntry(3, 2, 0.0009)
          ..translateByDouble(0, (1 - t) * 48, 0, 1)
          ..rotateX((1 - t) * 0.08)
          ..scaleByDouble(1 - back * 0.04, 1 - back * 0.04, 1, 1);
        return Opacity(
          opacity: (t.clamp(0, 1) * (1 - back * 0.3)).toDouble(),
          child: Transform(transform: m, alignment: Alignment.topCenter, child: child),
        );
      },
    );
  }
}

/// [child] in a [Tilt] under the Udyoga look, else as it is.
Widget tiltOn(BuildContext context, Widget child) => Udyoga.on(context) ? Tilt(child: child) : child;

/// Tilts its child towards the pointer in 3D and lifts it on hover; presses
/// sink it slightly. Static when the system asks for reduced motion.
class Tilt extends StatefulWidget {
  const Tilt({super.key, required this.child, this.maxAngle = 0.07});
  final Widget child;

  /// Radians at the edges.
  final double maxAngle;

  @override
  State<Tilt> createState() => _TiltState();
}

class _TiltState extends State<Tilt> {
  var _x = 0.0, _y = 0.0;
  var _hover = false, _down = false;

  void _move(Offset local, Size size) {
    if (size.isEmpty) return;
    setState(() {
      _x = ((local.dx / size.width - 0.5) * 2).clamp(-1.0, 1.0);
      _y = ((local.dy / size.height - 0.5) * 2).clamp(-1.0, 1.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (Motion.reduced(context)) return widget.child;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onHover: (e) {
        final box = context.findRenderObject() as RenderBox?;
        if (box != null && box.hasSize) _move(e.localPosition, box.size);
      },
      onExit: (_) => setState(() {
        _hover = false;
        _x = 0;
        _y = 0;
      }),
      child: Listener(
        onPointerDown: (_) => setState(() => _down = true),
        onPointerUp: (_) => setState(() => _down = false),
        onPointerCancel: (_) => setState(() => _down = false),
        child: TweenAnimationBuilder<Offset>(
          tween: Tween(end: _hover ? Offset(_x, _y) : Offset.zero),
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          builder: (context, o, child) {
            final scale = _down ? 0.985 : (_hover ? 1.012 : 1.0);
            final m = Matrix4.identity()
              ..setEntry(3, 2, 0.0012)
              ..rotateX(-o.dy * widget.maxAngle)
              ..rotateY(o.dx * widget.maxAngle)
              ..scaleByDouble(scale, scale, 1, 1);
            return AnimatedSlide(
              offset: Offset(0, _hover ? -0.012 : 0),
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: Transform(transform: m, alignment: Alignment.center, child: child),
            );
          },
          child: widget.child,
        ),
      ),
    );
  }
}

/// Someone's mark: their initials on a gradient picked from their name, so
/// the same agent always looks the same (no pictures are fetched).
class OrgLogo extends StatelessWidget {
  const OrgLogo(this.name, {super.key, this.size = 40});
  final String name;
  final double size;

  /// FNV-1a: well spread, so similar names still get different colours.
  static int _hash(String s) => s.codeUnits.fold(0x811C9DC5, (h, c) => ((h ^ c) * 0x01000193) & 0xFFFFFFFF);

  static const _palettes = [
    [Color(0xFF2F6BFF), Color(0xFF7A5CFF)],
    [Color(0xFF12B886), Color(0xFF0CA5E9)],
    [Color(0xFFFF7A45), Color(0xFFFF4D7E)],
    [Color(0xFF7A5CFF), Color(0xFFE056FD)],
    [Color(0xFF0EA5E9), Color(0xFF2F6BFF)],
    [Color(0xFFF59F00), Color(0xFFFF6B3D)],
    [Color(0xFF20C997), Color(0xFF2F9E44)],
    [Color(0xFF364FC7), Color(0xFF15AABF)],
  ];

  @override
  Widget build(BuildContext context) {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty && w[0].contains(RegExp('[A-Za-z0-9]')));
    final letters = words.take(2).map((w) => w[0].toUpperCase()).join();
    final colors = _palettes[(_hash(name.toLowerCase()) >> 8) % _palettes.length];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.3),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
        boxShadow: [
          BoxShadow(color: colors.first.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 5)),
        ],
      ),
      child: Text(
        letters.isEmpty ? '•' : letters,
        style: TextStyle(
          fontFamily: headingFont,
          fontFamilyFallback: _headingFallback,
          fontWeight: FontWeight.w800,
          fontSize: size * (letters.length > 1 ? 0.36 : 0.44),
          color: Colors.white,
          letterSpacing: -0.5,
        ),
      ),
    );
  }
}
