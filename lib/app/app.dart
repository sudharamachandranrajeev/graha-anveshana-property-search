import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ui/look.dart';
import '../ui/molten_theme.dart';
import '../ui/udyoga_look.dart';
import 'modules.dart';
import 'providers.dart';

ThemeData anveshanaTheme(Brightness b) => instrumentTheme(b);

// Built once: a new ThemeData on every build would restyle every screen.
final _light = anveshanaTheme(Brightness.light);
final _dark = anveshanaTheme(Brightness.dark);
final _molten = moltenTheme();
final _udyogaLight = udyogaTheme(Brightness.light);
final _udyogaDark = udyogaTheme(Brightness.dark);

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
    final (light, dark) = switch (look) {
      Look.molten => (_molten, _molten),
      Look.udyoga => (_udyogaLight, _udyogaDark),
      _ => (_light, _dark),
    };
    return MaterialApp(
      title: 'Graha Anveshana',
      debugShowCheckedModeBanner: false,
      theme: light,
      darkTheme: dark,
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
/// code). There is no onboarding: every screen works empty. At start it
/// offers a new version when there is one (see [offerUpdateAtStart]).
class _Root extends ConsumerStatefulWidget {
  const _Root();

  @override
  ConsumerState<_Root> createState() => _RootState();
}

class _RootState extends ConsumerState<_Root> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => offerUpdateAtStart(context, ref).ignore());
  }

  @override
  Widget build(BuildContext context) => LinkHandler(
    child: AppShell(destinations: allDestinations, onStart: fetchWatch, floating: true),
  );
}

/// The version last offered at start, on this device.
const _offeredKey = 'anveshana.update.offered';

/// Asks GitHub for a newer release and, the first time each one is seen,
/// says so in a dialog with what is new and an Update button (download,
/// checksum, install). Core's banner stays as the quiet reminder after
/// Later; it reuses a day-old answer, so on its own a release that just
/// came out could wait a day. Only an app that updates itself asks (a
/// release build); Sentinel's update switch turns this off too. Offline
/// says nothing.
Future<void> offerUpdateAtStart(BuildContext context, WidgetRef ref) async {
  final updater = ref.read(updaterProvider);
  if (updater == null) return;
  try {
    if (!await ref.read(updateChecksProvider.future)) return;
    final release = await updater.check();
    final db = ref.read(sessionProvider).db;
    if (release == null || await db.localSetting(_offeredKey) == release.version) return;
    await db.setLocalSetting(_offeredKey, release.version);
    if (context.mounted) await showUpdate(context, updater, release);
  } on Object {
    return; // Offline or GitHub busy: ask again next start.
  }
}
