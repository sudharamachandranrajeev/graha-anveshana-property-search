import 'dart:convert';

import 'package:anveshana/domain/safety.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

// Answers shaped like the live services on 2026-11-27.
http.Response _answer(http.Request r) {
  final host = r.url.host, path = r.url.path;
  if (host == 'services.arcgis.com' && path.contains('England')) {
    return http.Response(
      jsonEncode({
        'features': [
          {
            'attributes': {'LSOA21NM': 'Leeds 111B', 'Crime_Rank': 718},
          },
        ],
      }),
      200,
    );
  }
  if (path.contains('RoadCasualty')) {
    return http.Response(
      jsonEncode({
        'features': [
          {
            'attributes': {'collision_severity': 'Serious', 'n': 6},
          },
          {
            'attributes': {'collision_severity': 'Slight', 'n': 21},
          },
        ],
      }),
      200,
    );
  }
  if (host == 'environment.data.gov.uk') {
    return http.Response(
      jsonEncode({
        'features': [
          {
            'properties': {'risk_band': 'Low'},
          },
        ],
      }),
      200,
    );
  }
  return http.Response('{}', 404);
}

void main() {
  test('a busy city centre: high crime, a low flood risk and serious collisions', () async {
    final asked = <Uri>[];
    final r = await SafetyChecks(
      MockClient((q) async {
        asked.add(q.url);
        return _answer(q);
      }),
    ).report((lat: 53.8008, lon: -1.5491));
    expect(r.notes, isEmpty);
    // The flood map wants longitude first, with its coordinate system named.
    expect(
      asked.firstWhere((u) => u.host == 'environment.data.gov.uk').queryParameters['CQL_FILTER'],
      'INTERSECTS(shape,SRID=4326;POINT(-1.5491 53.8008))',
    );
    expect(r.crime?.decile, 1);
    expect(r.flood, FloodBand.low);
    expect(r.collisions, (year: 2025, fatal: 0, serious: 6, slight: 21));
    // Decile 1, less 0.5 for flood and 1.5 for six serious: clamped to 1.
    expect(r.score, 1);
    expect(
      r.reasons.first,
      startsWith('Much more crime than most areas: Leeds 111B is ranked 718 of 33,755'),
    );
    expect(
      {for (final f in r.insuranceFactors) f.factor: f.level},
      {'Flood (buildings cover)': 'Low', 'Theft and break-ins (contents cover)': 'High'},
    );
  });

  test('the score starts from the crime decile', () {
    const quiet = CrimeIndex(
      index: 'Index of Multiple Deprivation 2025 (England)',
      area: 'X',
      rank: 33000,
      of: 33755,
    );
    expect(quiet.decile, 10);
    expect(const SafetyReport(crime: quiet).score, 10);
    expect(const SafetyReport(crime: quiet, flood: FloodBand.high).score, 7);
    expect(
      const SafetyReport(crime: quiet, collisions: (year: 2025, fatal: 1, serious: 1, slight: 9)).score,
      10, // 9.5 rounds up
    );
    expect(const SafetyReport().score, isNull);
  });

  test('a source that fails leaves a note, the rest still answer', () async {
    final r = await SafetyChecks(
      MockClient((q) async => q.url.path.contains('RoadCasualty') ? http.Response('busy', 503) : _answer(q)),
    ).report((lat: 53.8009, lon: -1.5492));
    expect(r.collisions, isNull);
    expect(r.notes, ['The road collision map did not answer. Try again later.']);
    expect(r.crime?.rank, 718);
  });
}
