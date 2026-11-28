import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';

import 'look.dart';
import 'molten.dart';

// The Molten theme: every Material widget in the app takes its stone and
// rose-gold form from here, so screens need no changes to wear it. The
// reference's foundations map onto it as:
//  surfaces   Base: cards. Raised: the best of a list, figures, primary
//             buttons. Inset: text fields, tracks. Pressed: a held button.
//  elevation  1 chips and tiles, 2 cards, 3 menus and sheets, 4 dialogs,
//             which drip.
//  borders    1 px chips, 2 px buttons and raised slabs, 3 px a focused
//             field's ring, 4 px the rope under each page's title.
//  radius     4 checkboxes, 8 tooltips and toasts, 12 cards and fields,
//             full for buttons and tabs.
//  icons      rose gold.

/// A button's edge in each state: a raised pill with a glowing rim; held
/// down, a cracked recess; unavailable, dim stone with no rim.
WidgetStateProperty<OutlinedBorder> _pill({required bool primary}) => WidgetStateProperty.resolveWith((s) {
  if (s.contains(WidgetState.disabled)) {
    return const StoneBorder(radius: 999, kind: Stone.flat, seed: 1, wobble: 0.6);
  }
  if (s.contains(WidgetState.pressed)) {
    return const StoneBorder(
      radius: 999,
      kind: Stone.pressed,
      seed: 1,
      wobble: 0.6,
      side: BorderSide(color: Forge.ember, width: 2),
    );
  }
  final lit = s.contains(WidgetState.hovered) || s.contains(WidgetState.focused);
  return primary
      ? StoneBorder(
          radius: 999,
          kind: Stone.raised,
          glow: lit ? 0.7 : 0.35,
          seed: 1,
          wobble: 0.6,
          side: const BorderSide(color: Forge.rose, width: 2),
        )
      : StoneBorder(
          radius: 999,
          kind: Stone.flat,
          glow: lit ? 0.4 : 0,
          seed: 1,
          wobble: 0.6,
          side: const BorderSide(color: Forge.rose, width: 1.5),
        );
});

ThemeData moltenTheme() {
  final base = buildTheme(Brightness.dark, seed: Forge.rose, accent: Forge.rose);
  const raisedStone = Color(0xFF5C5E62);
  final scheme = base.colorScheme.copyWith(
    primary: Forge.rose,
    onPrimary: Forge.stoneDeep,
    primaryContainer: Forge.copper,
    onPrimaryContainer: Colors.white,
    secondary: Forge.roseBright,
    onSecondary: Forge.stoneDeep,
    secondaryContainer: raisedStone,
    onSecondaryContainer: Forge.text,
    tertiary: Forge.roseBright,
    onTertiary: Forge.stoneDeep,
    surface: Forge.stoneDark,
    onSurface: Forge.text,
    onSurfaceVariant: Forge.muted,
    surfaceContainerLowest: Forge.stoneDeep,
    surfaceContainerLow: Forge.stone,
    surfaceContainer: Forge.stone,
    surfaceContainerHigh: raisedStone,
    surfaceContainerHighest: raisedStone,
    outline: Forge.rose,
    outlineVariant: const Color(0x55E29D7E),
    error: Forge.error,
    onError: Forge.stoneDeep,
    errorContainer: const Color(0xFF5A2A26),
    onErrorContainer: const Color(0xFFFFDAD5),
    shadow: Colors.black,
  );
  final type = base.textTheme.apply(
    fontFamily: lookFont,
    fontFamilyFallback: lookFontFallback,
    bodyColor: Forge.text,
    displayColor: Forge.text,
  );
  TextStyle? tight(TextStyle? s, FontWeight w, double spacing) =>
      s?.copyWith(fontWeight: w, letterSpacing: spacing);
  final t = type.copyWith(
    displayLarge: tight(type.displayLarge, FontWeight.w800, -2.4),
    displayMedium: tight(type.displayMedium, FontWeight.w800, -2),
    displaySmall: tight(type.displaySmall, FontWeight.w800, -1.4),
    headlineLarge: tight(type.headlineLarge, FontWeight.w800, -1),
    headlineMedium: tight(type.headlineMedium, FontWeight.w800, -0.8),
    headlineSmall: tight(type.headlineSmall, FontWeight.w700, -0.6),
    titleLarge: tight(type.titleLarge, FontWeight.w700, -0.4),
    titleMedium: tight(type.titleMedium, FontWeight.w600, -0.1),
    titleSmall: tight(type.titleSmall, FontWeight.w600, 0),
    bodyLarge: type.bodyLarge?.copyWith(height: 1.45, letterSpacing: 0),
    bodyMedium: type.bodyMedium?.copyWith(height: 1.4, letterSpacing: 0),
    bodySmall: type.bodySmall?.copyWith(color: Forge.muted, letterSpacing: 0),
    labelLarge: type.labelLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.6),
  );
  const rim = BorderSide(color: Color(0x66E29D7E));
  const slab = StoneBorder(side: rim);
  final buttonText = t.labelLarge;
  WidgetStateProperty<Color?> fg(Color on) => WidgetStateProperty.resolveWith(
    (s) => s.contains(WidgetState.disabled) ? Forge.muted.withValues(alpha: 0.55) : on,
  );
  return base.copyWith(
    colorScheme: scheme,
    textTheme: t,
    primaryTextTheme: base.primaryTextTheme.apply(fontFamily: lookFont, fontFamilyFallback: lookFontFallback),
    extensions: const [Molten()],
    scaffoldBackgroundColor: Colors.transparent,
    canvasColor: Forge.stoneDark,
    shadowColor: Colors.black,
    iconTheme: const IconThemeData(color: Forge.rose, size: 22),
    dividerTheme: const DividerThemeData(color: Color(0x55E29D7E), thickness: 1, space: 24),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: Forge.text,
      iconTheme: const IconThemeData(color: Forge.rose),
      actionsIconTheme: const IconThemeData(color: Forge.rose),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: 68,
      titleSpacing: 20,
      shape: const RopeEdge(),
      titleTextStyle: t.headlineSmall?.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.9,
      ),
    ),
    cardTheme: const CardThemeData(
      color: Forge.stone,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.black,
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: slab,
    ),
    listTileTheme: base.listTileTheme.copyWith(
      iconColor: Forge.rose,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      subtitleTextStyle: t.bodySmall,
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: const StoneBorder(radius: 10, kind: Stone.flat, wobble: 0.6),
      side: const BorderSide(color: Color(0x88E29D7E)),
      backgroundColor: Forge.stoneDark,
      selectedColor: Forge.copper,
      secondarySelectedColor: Forge.copper,
      checkmarkColor: Colors.white,
      iconTheme: const IconThemeData(color: Forge.rose, size: 18),
      labelStyle: t.labelMedium?.copyWith(
        fontWeight: FontWeight.w500,
        color: WidgetStateColor.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : Forge.text,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
    ),
    // Tabs: a pill group, the chosen one hot copper.
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        shape: const WidgetStatePropertyAll(StadiumBorder()),
        side: const WidgetStatePropertyAll(BorderSide(color: Forge.rose, width: 1.5)),
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Forge.copper : Forge.stoneDark,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : Forge.text,
        ),
        iconColor: const WidgetStatePropertyAll(Colors.white),
        textStyle: WidgetStatePropertyAll(
          t.labelMedium?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.8),
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        shape: _pill(primary: true),
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.disabled)
              ? Forge.stoneDark
              : (s.contains(WidgetState.pressed) ? Forge.stoneDeep : raisedStone),
        ),
        foregroundColor: fg(Forge.text),
        iconColor: fg(Forge.roseBright),
        overlayColor: const WidgetStatePropertyAll(Color(0x14FF9466)),
        elevation: const WidgetStatePropertyAll(0),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 20, vertical: 14)),
        textStyle: WidgetStatePropertyAll(buttonText),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        shape: _pill(primary: false),
        // Buttons hand their side to the shape, which draws it as the rim.
        side: WidgetStateProperty.resolveWith(
          (s) => BorderSide(
            color: s.contains(WidgetState.disabled) ? const Color(0x44E29D7E) : Forge.rose,
            width: 1.5,
          ),
        ),
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.pressed) ? Forge.stoneDeep : Colors.transparent,
        ),
        foregroundColor: fg(Forge.roseBright),
        iconColor: fg(Forge.roseBright),
        overlayColor: const WidgetStatePropertyAll(Color(0x14FF9466)),
        textStyle: WidgetStatePropertyAll(buttonText),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: const StadiumBorder(),
        foregroundColor: Forge.roseBright,
        textStyle: buttonText,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: Forge.rose, disabledForegroundColor: Forge.stoneLight),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: Forge.copper,
      foregroundColor: Colors.white,
      shape: const StoneBorder(
        radius: 18,
        kind: Stone.raised,
        glow: 0.6,
        seed: 6,
        side: BorderSide(color: Forge.roseBright, width: 2),
      ),
      elevation: 3,
      highlightElevation: 6,
      extendedTextStyle: t.labelLarge?.copyWith(fontSize: 15, color: Colors.white),
    ),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      // A state-aware side, or Material drops it once the box is ticked.
      side: WidgetStateBorderSide.resolveWith((_) => const BorderSide(color: Forge.rose, width: 1.5)),
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.disabled) ? Forge.stoneDark : Forge.stoneDeep,
      ),
      checkColor: const WidgetStatePropertyAll(Forge.roseBright),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Forge.roseBright : Forge.rose.withValues(alpha: 0.7),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Forge.roseBright : Forge.stoneLight,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Forge.copper : Forge.stoneDeep,
      ),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Forge.roseBright : Forge.rose.withValues(alpha: 0.5),
      ),
      thumbIcon: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? const Icon(Icons.local_fire_department, size: 14, color: Forge.copper)
            : const Icon(Icons.cloud_outlined, size: 14, color: Forge.stoneDeep),
      ),
    ),
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      filled: true,
      fillColor: Forge.stoneDeep,
      border: const FieldBorder(borderSide: BorderSide(color: Color(0x88E29D7E))),
      enabledBorder: const FieldBorder(borderSide: BorderSide(color: Color(0x88E29D7E))),
      disabledBorder: const FieldBorder(borderSide: BorderSide(color: Color(0x33E29D7E))),
      focusedBorder: const FieldBorder(focus: 1, borderSide: BorderSide(color: Forge.roseBright, width: 1.5)),
      errorBorder: const FieldBorder(error: true, borderSide: BorderSide(color: Forge.error)),
      focusedErrorBorder: const FieldBorder(
        error: true,
        focus: 1,
        borderSide: BorderSide(color: Forge.error, width: 1.5),
      ),
      labelStyle: const TextStyle(color: Forge.muted),
      floatingLabelStyle: const TextStyle(color: Forge.roseBright),
      helperStyle: t.bodySmall,
      errorStyle: t.bodySmall?.copyWith(color: Forge.error),
      prefixIconColor: Forge.rose,
      suffixIconColor: Forge.rose,
    ),
    sliderTheme: base.sliderTheme.copyWith(
      trackHeight: 8,
      rangeTrackShape: const MoltenRangeTrack(),
      rangeThumbShape: const BeadThumb(),
      overlayColor: Forge.ember.withValues(alpha: 0.14),
      valueIndicatorColor: Forge.copper,
      valueIndicatorTextStyle: t.labelMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
      showValueIndicator: ShowValueIndicator.onDrag,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Forge.stoneDark,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.black,
      indicatorColor: Forge.copper,
      indicatorShape: const StadiumBorder(),
      elevation: 0,
      height: 64,
      labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(color: s.contains(WidgetState.selected) ? Colors.white : Forge.rose),
      ),
      labelTextStyle: WidgetStatePropertyAll(
        t.labelSmall?.copyWith(color: Forge.text, fontWeight: FontWeight.w600, letterSpacing: 1.2),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: Colors.transparent,
      indicatorColor: Forge.copper,
      indicatorShape: const CircleBorder(),
      selectedIconTheme: const IconThemeData(color: Colors.white, size: 20),
      unselectedIconTheme: const IconThemeData(color: Forge.rose, size: 20),
      selectedLabelTextStyle: t.labelSmall?.copyWith(
        color: Forge.text,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
      unselectedLabelTextStyle: t.labelSmall?.copyWith(color: Forge.muted, letterSpacing: 1.2),
    ),
    // Level 4: cracked stone that drips, smoke off its corners.
    dialogTheme: DialogThemeData(
      backgroundColor: Forge.stone,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.black,
      elevation: 12,
      shape: const StoneBorder(
        radius: 16,
        seed: 5,
        glow: 0.25,
        drips: 3,
        smoke: true,
        cracked: true,
        side: BorderSide(color: Forge.rose),
      ),
      titleTextStyle: t.headlineSmall,
      iconColor: Forge.rose,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Forge.stoneDark,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: Forge.rose,
      elevation: 6,
      shape: StoneBorder(radius: 20, seed: 8, side: rim),
    ),
    popupMenuTheme: const PopupMenuThemeData(
      color: Forge.stoneDark,
      surfaceTintColor: Colors.transparent,
      elevation: 6,
      shape: StoneBorder(radius: 12, seed: 3, side: rim),
    ),
    // Toasts: stone tablets with a lit rim; errors in a darker red stone.
    snackBarTheme: base.snackBarTheme.copyWith(
      backgroundColor: Forge.stoneDark,
      contentTextStyle: t.bodyMedium?.copyWith(color: Forge.text),
      actionTextColor: Forge.roseBright,
      closeIconColor: Forge.muted,
      elevation: 6,
      shape: const StoneBorder(
        radius: 8,
        kind: Stone.raised,
        glow: 0.3,
        seed: 7,
        wobble: 0.8,
        side: BorderSide(color: Forge.rose),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: const ShapeDecoration(color: Forge.stoneDark, shape: DropBorder()),
      textStyle: t.bodySmall?.copyWith(color: Forge.text),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      // Leaves room for the drop under the tablet.
      verticalOffset: 32,
    ),
    badgeTheme: const BadgeThemeData(backgroundColor: Forge.copper, textColor: Colors.white),
    dataTableTheme: DataTableThemeData(
      headingRowColor: const WidgetStatePropertyAll(Forge.stoneDark),
      headingRowHeight: 40,
      dataRowMinHeight: 40,
      headingTextStyle: t.labelMedium?.copyWith(
        color: Forge.roseBright,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
      dividerThickness: 1,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: Forge.rose,
      linearTrackColor: Forge.stoneDeep,
      circularTrackColor: Colors.transparent,
    ),
    expansionTileTheme: const ExpansionTileThemeData(
      shape: Border(),
      collapsedShape: Border(),
      iconColor: Forge.rose,
      collapsedIconColor: Forge.rose,
    ),
    pageTransitionsTheme: onCanvasTransitions,
  );
}
