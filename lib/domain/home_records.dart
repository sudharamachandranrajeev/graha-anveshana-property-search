/// Official records about one house, not its area: its energy certificate
/// (the EPC register, England and Wales) and what it sold for before (HM
/// Land Registry). Both are looked up by postcode, then the house is picked
/// out by its address.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'advert.dart';
import 'research.dart';

/// The EPC register's API. Each user signs in with GOV.UK One Login on
/// [epcAccountPage] and copies the key it shows; the app sends it only here.
const epcApiHost = 'api.get-energy-performance-data.communities.gov.uk';
final epcAccountPage = Uri.parse('https://get-energy-performance-data.communities.gov.uk/api/my-account');

/// One certificate in a postcode, as the register's search lists it.
typedef EpcEntry = ({String number, String address, String band, String date});

/// The parts of an energy certificate a buyer or renter asks about.
class EpcCertificate {
  const EpcCertificate({
    required this.number,
    this.band = '',
    this.potentialBand = '',
    this.score,
    this.potentialScore,
    this.floorArea,
    this.dwelling = '',
    this.heating = '',
    this.walls = '',
    this.roof = '',
    this.windows = '',
    this.heatingCostYear,
    this.date = '',
    this.upgrades = 0,
  });

  final String number;

  /// A to G, now and after the suggested upgrades.
  final String band, potentialBand;
  final int? score, potentialScore;

  /// Square metres.
  final num? floorArea;
  final String dwelling, heating, walls, roof, windows;

  /// Heating cost a year in pounds, as the assessor worked it out.
  final int? heatingCostYear;

  /// When it was lodged (yyyy-MM-dd).
  final String date;

  /// How many upgrades the certificate suggests.
  final int upgrades;

  /// The certificate on the government's own site, with the upgrades.
  Uri get page => Uri.parse('https://find-energy-certificate.service.gov.uk/energy-certificate/$number');

  Map<String, Object?> toJson() => {
    'number': number,
    'band': band,
    'potentialBand': potentialBand,
    'score': ?score,
    'potentialScore': ?potentialScore,
    'floorArea': ?floorArea,
    'dwelling': dwelling,
    'heating': heating,
    'walls': walls,
    'roof': roof,
    'windows': windows,
    'heatingCostYear': ?heatingCostYear,
    'date': date,
    'upgrades': upgrades,
  };

  static EpcCertificate? fromJson(Object? j) {
    if (j is! Map || j['number'] is! String) return null;
    String s(String k) => '${j[k] ?? ''}';
    return EpcCertificate(
      number: j['number'] as String,
      band: s('band'),
      potentialBand: s('potentialBand'),
      score: (j['score'] as num?)?.toInt(),
      potentialScore: (j['potentialScore'] as num?)?.toInt(),
      floorArea: j['floorArea'] as num?,
      dwelling: s('dwelling'),
      heating: s('heating'),
      walls: s('walls'),
      roof: s('roof'),
      windows: s('windows'),
      heatingCostYear: (j['heatingCostYear'] as num?)?.toInt(),
      date: s('date'),
      upgrades: (j['upgrades'] as num?)?.toInt() ?? 0,
    );
  }
}

/// A value from a certificate: older schemas wrap text and money in
/// {"value": ...}; lists (walls, roofs) give their first part.
String _text(Object? o) => switch (o) {
  null => '',
  String s => s.trim(),
  num n => '$n',
  {'value': final v} => _text(v),
  {'description': final v} => _text(v),
  List l when l.isNotEmpty => _text(l.first),
  _ => '',
};

num? _num(Object? o) => switch (o) {
  num n => n,
  String s => num.tryParse(s),
  {'value': final v} => _num(v),
  _ => null,
};

/// A register answer's "data": the certificate, or the list of them.
Object? _data(String body) {
  final j = jsonDecode(body);
  return j is Map ? j['data'] : null;
}

/// The certificates [parseEpcSearch] finds in a register search answer.
List<EpcEntry> parseEpcSearch(String body) {
  var rows = _data(body);
  // The list may sit one level down ({"data": {"assessments": [...]}}).
  if (rows is Map) rows = rows.values.whereType<List>().firstOrNull;
  if (rows is! List) return const [];
  return [
    for (final r in rows)
      if (r is Map && r['certificateNumber'] != null)
        (
          number: '${r['certificateNumber']}',
          address: [
            for (final k in ['addressLine1', 'addressLine2', 'addressLine3', 'addressLine4', 'postTown'])
              if (_text(r[k]).isNotEmpty) _text(r[k]),
          ].join(', '),
          band: _text(r['currentEnergyEfficiencyBand']),
          date: _text(r['registrationDate']),
        ),
  ];
}

EpcCertificate parseEpcCertificate(String number, String body) {
  final d = _data(body);
  if (d is! Map) throw const FormatException('The EPC register sent no certificate.');
  final cost = _num(d['heating_cost_current']);
  return EpcCertificate(
    number: number,
    band: _text(d['current_energy_efficiency_band']),
    potentialBand: _text(d['potential_energy_efficiency_band']),
    score: _num(d['energy_rating_current'])?.toInt(),
    potentialScore: _num(d['energy_rating_potential'])?.toInt(),
    floorArea: _num(d['total_floor_area']),
    dwelling: _text(d['dwelling_type']),
    heating: _text(d['main_heating']),
    walls: _text(d['walls']),
    roof: _text(d['roofs'] ?? d['roof']),
    windows: _text(d['window'] ?? d['windows']),
    heatingCostYear: cost?.round(),
    date: _text(d['registration_date']),
    upgrades: (d['suggested_improvements'] as List?)?.length ?? 0,
  );
}

class EpcUnavailable implements Exception {
  const EpcUnavailable(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Reads the EPC register with the user's own key.
class EpcRegister {
  EpcRegister(this._http, this._key);
  final http.Client _http;
  final String _key;

  Future<String> _get(String path, Map<String, String> query) async {
    final r = await _http
        .get(
          Uri.https(epcApiHost, path, query),
          headers: {'authorization': 'Bearer $_key', 'accept': 'application/json'},
        )
        .timeout(const Duration(seconds: 30));
    return switch (r.statusCode) {
      200 => r.body,
      404 => '{"data":[]}',
      401 || 403 => throw const EpcUnavailable('The EPC register did not accept your key. Copy it again in Settings.'),
      429 => throw const EpcUnavailable('The EPC register is busy. Try again in a few minutes.'),
      final c => throw EpcUnavailable('The EPC register answered with error $c.'),
    };
  }

  /// Every certificate in [postcode], newest first.
  Future<List<EpcEntry>> inPostcode(String postcode) async {
    final rows = parseEpcSearch(await _get('/api/domestic/search', {'postcode': postcode}));
    return rows.toList()..sort((a, b) => b.date.compareTo(a.date));
  }

  Future<EpcCertificate> certificate(String number) async =>
      parseEpcCertificate(number, await _get('/api/certificate', {'certificate_number': number}));
}

/// What a saved home's meta keeps from its advert page and its records.
class SavedRecords {
  const SavedRecords({this.advert, this.advertRead, this.epc, this.sales, this.recordsRead});

  final AdvertDetails? advert;
  final EpcCertificate? epc;

  /// Null: never looked up; empty: none found.
  final List<Sale>? sales;

  /// When the advert page and the records were last read (yyyy-MM-dd).
  final String? advertRead, recordsRead;

  static SavedRecords of(String meta) {
    final Object? j;
    try {
      j = jsonDecode(meta);
    } on FormatException {
      return const SavedRecords();
    }
    if (j is! Map) return const SavedRecords();
    return SavedRecords(
      advert: AdvertDetails.fromJson(j['advert']),
      advertRead: j['advertRead'] as String?,
      epc: EpcCertificate.fromJson(j['epc']),
      sales: switch (j['sales']) {
        final List all => [
          for (final s in all)
            if (s is Map) Sale.fromJson(s.cast()),
        ],
        _ => null,
      },
      recordsRead: j['recordsRead'] as String?,
    );
  }
}

/// Whether [record]'s address (from the EPC register or Land Registry) is
/// the same house as [home]'s (as the advert or the user wrote it). Both
/// are in the same postcode already.
bool sameHouse(String home, String record) {
  // TODO(human)
  return false;
}

/// [sales] in a postcode that are this house, newest first.
List<Sale> salesOf(String home, List<Sale> sales) => [
  for (final s in sales)
    if (sameHouse(home, s.address)) s,
];
