import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ui/look.dart';
import '../ui/molten_theme.dart';
import 'modules.dart';
import 'providers.dart';

ThemeData anveshanaTheme(Brightness b) => instrumentTheme(b);

// Built once: a new ThemeData on every build would restyle every screen.
final _light = anveshanaTheme(Brightness.light);
final _dark = anveshanaTheme(Brightness.dark);
final _molten = moltenTheme();

class AnveshanaApp extends ConsumerWidget {
  const AnveshanaApp({super.key, this.home = const _Root()});
  final Widget home;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Only the look itself, so the re-read after each save does not rebuild.
    final (look, ready) = ref.watch(lookProvider.select((a) => (a.value, a.hasValue || a.hasError)));
    // The first read takes a moment; waiting for it saves a flash of the
    // other look. A failed read falls back to the usual look.
    if (!ready) return const ColoredBox(color: ink);
    final molten = look == Look.molten;
    return MaterialApp(
      title: 'Graha Anveshana',
      debugShowCheckedModeBanner: false,
      theme: molten ? _molten : _light,
      darkTheme: molten ? _molten : _dark,
      // A look's shapes do not blend into another's, so the switch is
      // immediate rather than animated through a mix of the two.
      themeAnimationDuration: Duration.zero,
      builder: (context, child) => AppLockGate(child: Backdrop(child: child ?? const SizedBox.shrink())),
      home: home,
    );
  }
}

/// New listings from Brahma Watch since the last start.
void fetchWatch(WidgetRef ref) => Future.microtask(() => ref.read(watchAutoProvider.future)).ignore();

/// The app, opening the links the platform hands over (a scanned pairing
/// code). There is no onboarding: every screen works empty.
class _Root extends ConsumerWidget {
  const _Root();

  @override
  Widget build(BuildContext context, WidgetRef ref) => LinkHandler(
    child: AppShell(destinations: allDestinations, onStart: fetchWatch, floating: true),
  );
}
