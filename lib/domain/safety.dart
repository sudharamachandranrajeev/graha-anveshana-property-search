/// How safe the area around a home is, from open government data: the
/// crime part of each nation's deprivation index, road collisions nearby
/// and the long-term flood risk. Nothing needs a key. Nothing is sent until
/// the user asks; then only the map point.
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'search_request.dart' show LatLon;

class SafetyUnavailable implements Exception {
  const SafetyUnavailable(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Where the area sits on its nation's crime index: [rank] 1 has the most
/// crime of [of] small areas (about 1,500 people each).
class CrimeIndex {
  const CrimeIndex({required this.index, required this.area, required this.rank, required this.of});

  /// "Index of Multiple Deprivation 2025 (England)" and the like.
  final String index;
  final String area;
  final int rank, of;

  /// 1 = the 10% of areas with the most crime, 10 = the 10% with the least.
  int get decile => ((rank - 1) * 10 ~/ of + 1).clamp(1, 10);
}

/// Road collisions with injuries reported to the police within 500 m.
typedef Collisions = ({int year, int fatal, int serious, int slight});

/// The Environment Agency's long-term risk of flooding from rivers and the
/// sea (England): High, Medium, Low or Very low.
enum FloodBand {
  high('High', 'more than 1 in 30 a year'),
  medium('Medium', 'between 1 in 100 and 1 in 30 a year'),
  low('Low', 'between 1 in 1,000 and 1 in 100 a year'),
  veryLow('Very low', 'less than 1 in 1,000 a year');

  const FloodBand(this.label, this.chance);
  final String label, chance;

  static FloodBand? of(String s) => switch (s.trim().toLowerCase()) {
    'high' => high,
    'medium' => medium,
    'low' => low,
    'very low' => veryLow,
    _ => null,
  };
}

/// What the checks found. A part is null when its source does not cover
/// the place (Northern Ireland has no crime index here, only England has
/// the flood map) or did not answer.
class SafetyReport {
  const SafetyReport({this.crime, this.collisions, this.flood, this.notes = const []});
  final CrimeIndex? crime;
  final Collisions? collisions;
  final FloodBand? flood;

  /// Sources that did not answer, in words.
  final List<String> notes;

  /// 1 (least safe) to 10 (safest), or null without a crime index. The
  /// crime decile is the base; a flood risk or a road with serious
  /// collisions takes points off.
  int? get score {
    final c = crime;
    if (c == null) return null;
    var s = c.decile.toDouble();
    s -= switch (flood) {
      FloodBand.high => 3,
      FloodBand.medium => 2,
      FloodBand.low => 0.5,
      _ => 0,
    };
    if (collisions case final r?) {
      final bad = r.fatal + r.serious;
      s -= bad == 0 ? 0 : (bad <= 2 ? 0.5 : (bad <= 5 ? 1 : 1.5));
    }
    return s.round().clamp(1, 10);
  }

  /// Why the score is what it is, one line each.
  List<String> get reasons => [
    if (crime case final c?)
      '${_crimeWords(c.decile)}: ${c.area} is ranked ${_n(c.rank)} of ${_n(c.of)} areas for crime '
          '(1 = most crime), in the ${c.index}.',
    if (flood case final f?)
      'Flood risk from rivers and the sea: ${f.label} (${f.chance}).'
    else if (crime?.index.contains('England') ?? false)
      'Flood risk from rivers and the sea: Very low (outside every mapped risk area).',
    if (collisions case final r?)
      r.fatal + r.serious + r.slight == 0
          ? 'No road collisions with injuries reported within 500 m in ${r.year}.'
          : 'Road collisions with injuries within 500 m in ${r.year}: '
                '${[if (r.fatal > 0) '${r.fatal} fatal', if (r.serious > 0) '${r.serious} serious', if (r.slight > 0) '${r.slight} slight'].join(', ')}.',
  ];

  /// What insurers look at that this data speaks to, each Low, Medium or
  /// High. Not a price: premiums also depend on the home and the person.
  List<({String factor, String level, String why})> get insuranceFactors => [
    if (flood case final f?)
      (
        factor: 'Flood (buildings cover)',
        level: switch (f) {
          FloodBand.high => 'High',
          FloodBand.medium => 'Medium',
          _ => 'Low',
        },
        why: 'Environment Agency band ${f.label}.',
      )
    else if (crime?.index.contains('England') ?? false)
      (factor: 'Flood (buildings cover)', level: 'Low', why: 'Outside every mapped river and sea risk area.'),
    if (crime case final c?)
      (
        factor: 'Theft and break-ins (contents cover)',
        level: c.decile <= 3 ? 'High' : (c.decile <= 6 ? 'Medium' : 'Low'),
        why: 'Crime rank ${_n(c.rank)} of ${_n(c.of)}.',
      ),
  ];
}

String _crimeWords(int decile) => decile <= 2
    ? 'Much more crime than most areas'
    : decile <= 4
    ? 'More crime than most areas'
    : decile <= 6
    ? 'About average crime'
    : decile <= 8
    ? 'Less crime than most areas'
    : 'Much less crime than most areas';

String _n(int n) => n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+$)'), (_) => ',');

/// Price comparison sites for home insurance, opened for a quote.
const insuranceQuoteSites = [
  ('MoneySuperMarket', 'https://www.moneysupermarket.com/home-insurance/'),
  ('Compare the Market', 'https://www.comparethemarket.com/home-insurance/'),
  ('GoCompare', 'https://www.gocompare.com/home-insurance/'),
  ('Confused.com', 'https://www.confused.com/home-insurance'),
  ('Uswitch', 'https://www.uswitch.com/home-insurance/'),
];

/// Flood Re helps homes at high flood risk built before 2009 get cover.
const floodReUrl = 'https://www.floodre.co.uk/';

// The crime indexes are republished on ArcGIS by others (the official
// English service has no crime figures): Esri UK for England, a public
// account for Wales 2025. Scotland is the Scottish Government's own.
const _englandIod =
    'https://services.arcgis.com/qHLhLQrcvEnxjtPr/arcgis/rest/services/'
    'Index_of_Multiple_Deprivation_(IMD)_2025_England/FeatureServer/4/query';
const _walesWimd =
    'https://services3.arcgis.com/tRh0agnyck3rPSQG/arcgis/rest/services/WIMD_2025/FeatureServer/0/query';
const _scotlandSimd = 'https://maps.gov.scot/server/rest/services/ScotGov/PeopleSociety/MapServer/7/query';
const _collisions2025 =
    'https://services5.arcgis.com/qUwnXV5uf1zyW6Y2/arcgis/rest/services/'
    'RoadCasualtyStatsCollision_GB_DfT_Point_2025/FeatureServer/0/query';
const _floodWfs =
    'https://environment.data.gov.uk/geoservices/datasets/96ab4342-82c1-4095-87f1-0082e8d84ef1/wfs';

/// Runs the checks. Answers are kept for the session.
class SafetyChecks {
  SafetyChecks(this._http);
  final http.Client _http;
  static final _cache = <String, SafetyReport>{};

  Future<Object?> _get(String url, Map<String, String> query) async {
    final r = await _http
        .get(Uri.parse(url).replace(queryParameters: query))
        .timeout(const Duration(seconds: 30));
    if (r.statusCode != 200) throw SafetyUnavailable('${Uri.parse(url).host} said ${r.statusCode}');
    final j = jsonDecode(r.body);
    // ArcGIS reports errors inside a 200 answer.
    if (j is Map && j['error'] != null) throw SafetyUnavailable('${Uri.parse(url).host} gave an error');
    return j;
  }

  static Map<String, String> _at(LatLon p) => {
    'geometry': '${p.lon},${p.lat}',
    'geometryType': 'esriGeometryPoint',
    'inSR': '4326',
    'spatialRel': 'esriSpatialRelIntersects',
    'returnGeometry': 'false',
    'f': 'json',
  };

  static Map? _first(Object? j) => switch (j) {
    {'features': [{'attributes': final Map a}, ...]} => a,
    _ => null,
  };

  static int? _int(Object? v) => v is num ? v.round() : int.tryParse('$v');

  /// England first, then Wales, then Scotland; each answers only inside
  /// its own nation, so a point gets the one that covers it.
  Future<CrimeIndex?> crime(LatLon p) async {
    final eng = _first(await _get(_englandIod, {..._at(p), 'outFields': 'LSOA21NM,Crime_Rank'}));
    if (_int(eng?['Crime_Rank']) case final rank?) {
      return CrimeIndex(
        index: 'Index of Multiple Deprivation 2025 (England)',
        area: '${eng!['LSOA21NM']}',
        rank: rank,
        of: 33755,
      );
    }
    final wal = _first(await _get(_walesWimd, {..._at(p), 'outFields': 'LSOA21NM,Community_Safety'}));
    if (_int(wal?['Community_Safety']) case final rank?) {
      return CrimeIndex(
        index: 'Welsh Index of Multiple Deprivation 2025 (community safety)',
        area: '${wal!['LSOA21NM']}',
        rank: rank,
        of: 1917,
      );
    }
    final sco = _first(await _get(_scotlandSimd, {..._at(p), 'outFields': 'dzname,crimerank'}));
    if (_int(sco?['crimerank']) case final rank?) {
      return CrimeIndex(
        index: 'Scottish Index of Multiple Deprivation 2020',
        area: '${sco!['dzname']}',
        rank: rank,
        of: 6976,
      );
    }
    return null;
  }

  Future<Collisions> collisions(LatLon p) async {
    final j = await _get(_collisions2025, {
      ..._at(p),
      'distance': '500',
      'units': 'esriSRUnit_Meter',
      'outStatistics': jsonEncode([
        {'statisticType': 'count', 'onStatisticField': 'OBJECTID', 'outStatisticFieldName': 'n'},
      ]),
      'groupByFieldsForStatistics': 'collision_severity',
    });
    final by = <String, int>{
      for (final f in ((j as Map?)?['features'] as List?) ?? const [])
        if (f case {'attributes': final Map a}) '${a['collision_severity']}'.toLowerCase(): _int(a['n']) ?? 0,
    };
    return (year: 2025, fatal: by['fatal'] ?? 0, serious: by['serious'] ?? 0, slight: by['slight'] ?? 0);
  }

  /// Null outside England, where the map has no answer at all; Very low
  /// inside England but outside every risk area is left to the caller.
  Future<FloodBand?> flood(LatLon p) async {
    final j = await _get(_floodWfs, {
      'service': 'WFS',
      'version': '1.1.0',
      'request': 'GetFeature',
      'typeName': 'rofrs_4band',
      'propertyName': 'risk_band',
      'outputFormat': 'application/json',
      'CQL_FILTER': 'INTERSECTS(shape,SRID=4326;POINT(${p.lon} ${p.lat}))',
    });
    return switch (j) {
      {'features': [{'properties': {'risk_band': final String b}}, ...]} => FloodBand.of(b),
      _ => null,
    };
  }

  /// All three; a source that fails leaves a note, not an error.
  Future<SafetyReport> report(LatLon p) async {
    final key = '${p.lat.toStringAsFixed(5)},${p.lon.toStringAsFixed(5)}';
    if (_cache[key] case final r?) return r;
    final notes = <String>[];
    Future<T?> attempt<T>(String what, Future<T> Function() f) async {
      try {
        return await f();
      } on Object {
        notes.add('$what did not answer. Try again later.');
        return null;
      }
    }

    final (crime, collisions, flood) = await (
      attempt('The crime index', () => this.crime(p)),
      attempt('The road collision map', () => this.collisions(p)),
      attempt('The flood map', () => this.flood(p)),
    ).wait;
    final r = SafetyReport(crime: crime, collisions: collisions, flood: flood, notes: notes);
    if (notes.isEmpty) _cache[key] = r;
    return r;
  }
}
