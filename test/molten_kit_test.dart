import 'dart:io';
import 'dart:ui' as ui;

import 'package:anveshana/domain/book.dart';
import 'package:anveshana/ui/molten.dart';
import 'package:anveshana/ui/molten_theme.dart';
import 'package:anveshana/ui/udyoga_look.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_harness.dart';

/// Every piece of the Molten look on one page. With GRAHA_SHOTS naming a
/// folder it also saves the page as a PNG, for checking the look by eye;
/// without, it still builds and paints it all, so a piece that throws or
/// overflows fails here.
void main() {
  final out = Platform.environment['GRAHA_SHOTS'];

  Future<void> loadFonts() async {
    Future<void> family(String name, List<String> files) async {
      final loader = FontLoader(name);
      for (final f in files) {
        loader.addFont(Future.value(ByteData.sublistView(File(f).readAsBytesSync())));
      }
      await loader.load();
    }

    final inter = [
      for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) 'assets/fonts/Inter-$w.ttf',
    ];
    await family('Inter', inter);
    await family('Roboto', inter);
    final icons = File(
      '${Platform.environment['FLUTTER_ROOT'] ?? ''}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    );
    if (icons.existsSync()) await family('MaterialIcons', [icons.path]);
  }

  testWidgets('Settings switches the look and it is kept', (tester) async {
    bool molten() => Theme.of(tester.element(find.byType(Scaffold).first)).extension<Molten>() != null;
    final app = AppHarness(tester)..desktop();
    await app.open();
    await app.run();
    expect(molten(), isFalse);
    await app.go('Settings');
    await app.tap(find.text('Molten').last);
    expect(molten(), isTrue);
    expect(await tester.runAsync(() => app.book.pref<String>(PrefKeys.look, '')), 'molten');
    // Every screen still opens in it.
    for (final page in ['Dashboard', 'Search', 'Shortlist', 'Contacts']) {
      await app.go(page);
      expect(tester.takeException(), isNull);
    }
    await app.go('Settings');
    await app.tap(find.text('Instrument').last);
    expect(molten(), isFalse);
    await app.close();
  });

  testWidgets('Settings switches to the Udyoga look and back', (tester) async {
    bool udyoga() => Theme.of(tester.element(find.byType(Scaffold).first)).extension<Udyoga>() != null;
    final app = AppHarness(tester)..desktop();
    await app.open();
    await app.run();
    await app.go('Settings');
    await app.tap(find.text('Udyoga').last);
    expect(udyoga(), isTrue);
    expect(await tester.runAsync(() => app.book.pref<String>(PrefKeys.look, '')), 'udyoga');
    for (final page in ['Dashboard', 'Search', 'Shortlist', 'Contacts', 'Lettings']) {
      await app.go(page);
      expect(tester.takeException(), isNull);
    }
    await app.go('Settings');
    await app.tap(find.text('Instrument').last);
    expect(udyoga(), isFalse);
    await app.close();
  });

  testWidgets('the Molten kit builds and paints', (tester) async {
    if (out != null) await tester.runAsync(loadFonts);
    debugDisableShadows = false;
    tester.view.physicalSize = const Size(1170, 8400);
    tester.view.devicePixelRatio = 3;
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: moltenTheme(),
          home: const Scaffold(
            body: CustomPaint(painter: MoltenCanvasPainter(), child: _Kit()),
          ),
        ),
      ),
    );
    // Spinners and flowing bars repeat forever; let a few frames pass.
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
    if (out != null) {
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final bytes = await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 3);
        return image.toByteData(format: ui.ImageByteFormat.png);
      });
      File('$out/molten-kit.png')
        ..createSync(recursive: true)
        ..writeAsBytesSync(bytes!.buffer.asUint8List());
    }
    // Stop the endless animations before the test ends.
    await tester.pumpWidget(const SizedBox());
    tester.view.reset();
    debugDisableShadows = true;
  });
}

class _Kit extends StatefulWidget {
  const _Kit();

  @override
  State<_Kit> createState() => _KitState();
}

class _KitState extends State<_Kit> {
  var _check = true, _radio = 1, _switch = true, _tab = 0, _page = 1;
  var _range = const RangeValues(400, 900);
  final _pressed = WidgetStatesController({WidgetState.pressed});

  @override
  void dispose() {
    _pressed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    Widget gap([double h = 18]) => SizedBox(height: h);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      children: [
        AppBar(title: const Text('Molten kit'), automaticallyImplyLeading: false),
        gap(),
        const Card(
          child: Padding(padding: EdgeInsets.all(16), child: Text('Base surface: a card')),
        ),
        gap(),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton(onPressed: () {}, child: const Text('PRIMARY')),
            FilledButton.icon(
              onPressed: () {},
              statesController: _pressed,
              icon: const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              label: const Text('LOADING…'),
            ),
            const FilledButton(onPressed: null, child: Text('UNAVAILABLE')),
            OutlinedButton(onPressed: () {}, child: const Text('Outlined')),
            TextButton(onPressed: () {}, child: const Text('Text')),
          ],
        ),
        gap(),
        CheckboxListTile(
          value: _check,
          onChanged: (v) => setState(() => _check = v ?? false),
          title: const Text('Checkbox'),
        ),
        RadioGroup<int>(
          groupValue: _radio,
          onChanged: (v) => setState(() => _radio = v ?? 0),
          child: const Column(
            children: [
              RadioListTile(value: 0, title: Text('Radio one')),
              RadioListTile(value: 1, title: Text('Radio two')),
            ],
          ),
        ),
        SwitchListTile(
          value: _switch,
          onChanged: (v) => setState(() => _switch = v),
          title: const Text('Switch on'),
        ),
        SwitchListTile(value: false, onChanged: (_) {}, title: const Text('Switch off')),
        gap(),
        const TextField(
          decoration: InputDecoration(labelText: 'Email address', helperText: 'We never share it'),
        ),
        gap(),
        const TextField(
          decoration: InputDecoration(labelText: 'Email address', errorText: 'That is not an e-mail address'),
        ),
        gap(),
        const TextField(autofocus: true, decoration: InputDecoration(labelText: 'Focused')),
        gap(),
        Text('Price', style: t.titleSmall),
        RangeSlider(min: 0, max: 1500, values: _range, onChanged: (v) => setState(() => _range = v)),
        gap(),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 0, label: Text('HOMES')),
            ButtonSegment(value: 1, label: Text('AREAS')),
            ButtonSegment(value: 2, label: Text('SETTINGS')),
          ],
          selected: {_tab},
          onSelectionChanged: (s) => setState(() => _tab = s.first),
        ),
        gap(),
        const Breadcrumbs(['Shortlist', 'To rent', 'Viewing']),
        gap(),
        Pager(count: 7, at: _page, onChanged: (i) => setState(() => _page = i)),
        gap(),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: StepBeads(
              steps: const ['New', 'Liked', 'Enquired', 'Viewing', 'Applied', 'Let agreed'],
              at: 2,
              note: 'Next: Viewing',
              onTap: (_) {},
            ),
          ),
        ),
        gap(),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: DripLineChart([0, 2, 1, 4, 3, 3, 6, 2, 0, 1, 5, 3]),
          ),
        ),
        gap(),
        const Card(
          child: ListTile(
            leading: SwirlAvatar('Sam Placeholder'),
            title: Text('Task A'),
            subtitle: Text('Due tomorrow'),
            trailing: NewBadge(),
          ),
        ),
        gap(),
        DecoratedBox(
          decoration: Theme.of(context).tooltipTheme.decoration!,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Text('A tooltip with its drop'),
          ),
        ),
        gap(24),
        DataTable(
          sortColumnIndex: 0,
          columns: const [
            DataColumn(label: Text('NAME')),
            DataColumn(label: Text('DATE')),
            DataColumn(label: Text('STATUS')),
          ],
          rows: const [
            DataRow(cells: [DataCell(Text('Alpha')), DataCell(Text('1 Nov')), DataCell(Text('Active'))]),
            DataRow(cells: [DataCell(Text('Beta')), DataCell(Text('3 Nov')), DataCell(Text('Paused'))]),
          ],
        ),
        gap(40),
        SizedBox(
          height: 300,
          child: AlertDialog(
            title: const Text('Delete account?'),
            content: const Text('This cannot be undone.'),
            actions: [
              TextButton(onPressed: () {}, child: const Text('Cancel')),
              FilledButton(onPressed: () {}, child: const Text('Delete')),
            ],
          ),
        ),
        gap(40),
        const MoltenProgress(value: 0.6, label: 'Processing: 60%'),
        gap(),
        const MoltenProgress(label: 'Working'),
        gap(),
        const Row(
          children: [
            MoltenSpinner(),
            SizedBox(width: 24),
            Expanded(child: SkeletonRows(rows: 2)),
          ],
        ),
        gap(),
        const Card(
          child: MoltenEmpty(title: 'No results found', message: 'Nothing here yet.'),
        ),
        gap(),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                const Chip(label: Text('Chip')),
                FilterChip(label: const Text('Picked'), selected: true, onSelected: (_) {}),
                ActionChip(label: const Text('Action'), onPressed: () {}),
                Badge(
                  label: const Text('3'),
                  child: Icon(Icons.notifications_outlined, color: Theme.of(context).iconTheme.color),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
