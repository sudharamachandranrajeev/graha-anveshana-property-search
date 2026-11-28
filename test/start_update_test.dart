import 'dart:convert';
import 'dart:io';

import 'package:anveshana/app/session.dart';
import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/widgets.dart' show SizedBox;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'app_harness.dart';

/// The new-version dialog at start: shown once per release, with its notes.
void main() {
  const repo = 'sudharamachandranrajeev/graha-anveshana-property-search';
  var asked = 0;

  // GitHub's release list, as the updater asks for it: one newer release.
  final github = MockClient((r) async {
    asked++;
    return http.Response(
      jsonEncode([
        {
          'tag_name': 'v9.9.0',
          'html_url': 'https://github.com/$repo/releases/tag/v9.9.0',
          'body': 'A brighter dashboard.',
          'assets': [
            for (final name in ['Graha-Anveshana-9.9.0-linux-x64.tar.gz', 'SHA256SUMS.txt'])
              {
                'name': name,
                'size': 1,
                'browser_download_url': 'https://github.com/$repo/releases/download/v9.9.0/$name',
              },
          ],
        },
      ]),
      200,
    );
  });

  AppUpdater updater() => AppUpdater(
    github,
    app: anveshanaIdentity,
    current: '0.16.0',
    os: 'linux',
    dir: Directory.systemTemp.createTempSync('anveshana-update'),
  );

  testWidgets('a new release is offered at start, once', (tester) async {
    final app = AppHarness(tester);
    await app.open();
    await app.run(overrides: [updaterProvider.overrideWithValue(updater())]);
    await app.settle();
    expect(asked, 1);
    expect(find.textContaining('9.9.0'), findsWidgets);
    expect(find.textContaining('A brighter dashboard.'), findsOneWidget);
    await app.tap(find.text('Close'));
    expect(find.textContaining('A brighter dashboard.'), findsNothing);

    // The next start asks GitHub again but does not repeat the offer.
    await tester.pumpWidget(const SizedBox());
    await app.run(overrides: [updaterProvider.overrideWithValue(updater())]);
    await app.settle();
    expect(asked, 2);
    expect(find.textContaining('A brighter dashboard.'), findsNothing);
    await app.close();
  });

  testWidgets('a debug build, without an updater, asks nothing', (tester) async {
    asked = 0;
    final app = AppHarness(tester);
    await app.open();
    await app.run();
    expect(asked, 0);
    expect(find.textContaining('9.9.0'), findsNothing);
    await app.close();
  });
}
