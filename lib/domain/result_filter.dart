/// Ticking down the homes a search found, as shops filter products: each
/// section (type, bedrooms, price...) lists what the results hold with a
/// count; ticks in one section widen it (flat OR terraced), sections narrow
/// each other (2 bed AND flat). Runs on the results already loaded, so
/// nothing is searched again.
library;

import 'home_features.dart';
import 'property_search.dart';

/// What kind of home it is, read from the sites' own words.
enum HomeType {
  detached('Detached house', r'\bdetached\b'),
  semi('Semi-detached', r'\bsemi[ -]?detached\b|\bsemi\b'),
  terraced('Terraced', r'\bterrace[d]?\b|\bend of terrace\b|\bmews\b|\btown ?house\b'),
  bungalow('Bungalow', r'\bbungalow\b'),
  flat('Flat or apartment', r'\bflat\b|\bapartment\b|\bpenthouse\b|\bduplex\b'),
  maisonette('Maisonette', r'\bmaisonette\b'),
  studio('Studio', r'\bstudio\b'),
  room('Room', r'\broom (?:in|to rent)\b|\bhouse ?share\b|\bflat ?share\b|\bhmo\b'),
  house('House, type not given', r'\bhouse\b|\bcottage\b|\bfarmhouse\b|\bvilla\b');

  const HomeType(this.label, this._pattern);
  final String label;
  final String _pattern;
}

/// The checks in order: the narrower word first ("semi-detached" before
/// "detached", a room in a house before "house").
const _typeOrder = [
  HomeType.room,
  HomeType.studio,
  HomeType.maisonette,
  HomeType.semi,
  HomeType.terraced,
  HomeType.bungalow,
  HomeType.detached,
  HomeType.flat,
  HomeType.house,
];

HomeType? _typeIn(String text) {
  final t = text.toLowerCase();
  for (final k in _typeOrder) {
    if (RegExp(k._pattern).hasMatch(t)) return k;
  }
  return null;
}

/// [h]'s type: the sites' property type first, then the advert's words;
/// null when none says.
HomeType? homeTypeOf(FoundHome h) {
  for (final c in h.copies) {
    if (c.style.isNotEmpty) {
      if (_typeIn(c.style) case final k?) return k;
    }
  }
  if (h.beds == 0) return HomeType.studio;
  return _typeIn(h.copies.map((c) => '${c.address}\n${c.description}').join('\n'));
}

/// Furnishing in three words, from however a site wrote it.
String? furnishingOf(FoundHome h) {
  final f = h.copies.map((c) => c.furnished.toLowerCase()).where((f) => f.isNotEmpty).firstOrNull;
  if (f == null) return null;
  if (f.contains('part')) return 'Part furnished';
  if (f.contains('unfurn')) return 'Unfurnished';
  if (f.contains('furn')) return 'Furnished';
  return null;
}

/// Bedrooms as a filter option: 0 studio, 1..4, 5 meaning five or more.
int? bedsOption(FoundHome h) => h.beds == null ? null : (h.beds! > 5 ? 5 : h.beds);

/// The ticks the user made. Empty sets mean "any".
class ResultFilter {
  const ResultFilter({
    this.types = const {},
    this.beds = const {},
    this.minPrice,
    this.maxPrice,
    this.furnishing = const {},
    this.features = const {},
    this.sites = const {},
    this.withinMiles,
  });

  /// null in [types] stands for "type not stated".
  final Set<HomeType?> types;
  final Set<int> beds;
  final int? minPrice, maxPrice;
  final Set<String> furnishing, sites;

  /// Features the advert must say it has.
  final Set<HomeFeature> features;
  final double? withinMiles;

  bool get isEmpty =>
      types.isEmpty &&
      beds.isEmpty &&
      minPrice == null &&
      maxPrice == null &&
      furnishing.isEmpty &&
      features.isEmpty &&
      sites.isEmpty &&
      withinMiles == null;

  /// How many sections are narrowing the list, for the Filters button.
  int get count => [
    types.isNotEmpty,
    beds.isNotEmpty,
    minPrice != null || maxPrice != null,
    furnishing.isNotEmpty,
    features.isNotEmpty,
    sites.isNotEmpty,
    withinMiles != null,
  ].where((b) => b).length;

  ResultFilter copyWith({
    Set<HomeType?>? types,
    Set<int>? beds,
    int? Function()? minPrice,
    int? Function()? maxPrice,
    Set<String>? furnishing,
    Set<HomeFeature>? features,
    Set<String>? sites,
    double? Function()? withinMiles,
  }) => ResultFilter(
    types: types ?? this.types,
    beds: beds ?? this.beds,
    minPrice: minPrice == null ? this.minPrice : minPrice(),
    maxPrice: maxPrice == null ? this.maxPrice : maxPrice(),
    furnishing: furnishing ?? this.furnishing,
    features: features ?? this.features,
    sites: sites ?? this.sites,
    withinMiles: withinMiles == null ? this.withinMiles : withinMiles(),
  );

  /// [h] passes every section but [skip] (counts for a section are worked
  /// out with that section's own ticks left off, so ticking more widens).
  bool matches(FoundHome h, {String? skip}) {
    if (skip != 'type' && types.isNotEmpty && !types.contains(homeTypeOf(h))) return false;
    if (skip != 'beds' && beds.isNotEmpty && !beds.contains(bedsOption(h))) return false;
    if (skip != 'price' && (minPrice != null || maxPrice != null)) {
      final p = h.price;
      if (p == null || (minPrice != null && p < minPrice!) || (maxPrice != null && p > maxPrice!))
        return false;
    }
    if (skip != 'furnishing' && furnishing.isNotEmpty && !furnishing.contains(furnishingOf(h))) return false;
    if (skip != 'features' && features.isNotEmpty) {
      final text = h.copies.map((c) => c.description).join('\n');
      if (!features.every((f) => f.said(text) == Says.yes)) return false;
    }
    if (skip != 'sites' && sites.isNotEmpty && !h.sources.any(sites.contains)) return false;
    if (skip != 'distance' && withinMiles != null) {
      final km = h.km;
      if (km == null || km / 1.609344 > withinMiles!) return false;
    }
    return true;
  }
}

/// One option in a section, with how many results it would show.
typedef Facet<T> = ({T value, String label, int count});

/// Every section's options with counts, for [homes] under [f].
class Facets {
  Facets(List<FoundHome> homes, ResultFilter f) {
    List<FoundHome> rest(String section) => [
      for (final h in homes)
        if (f.matches(h, skip: section)) h,
    ];
    List<Facet<T>> count<T>(
      String section,
      Iterable<T> Function(FoundHome h) of,
      String Function(T v) label,
      List<T> order,
    ) {
      final n = <T, int>{};
      for (final h in rest(section)) {
        for (final v in of(h)) {
          n[v] = (n[v] ?? 0) + 1;
        }
      }
      return [
        for (final v in order)
          if ((n[v] ?? 0) > 0 || _ticked(f, section, v)) (value: v, label: label(v), count: n[v] ?? 0),
      ];
    }

    types = count<HomeType?>('type', (h) => [homeTypeOf(h)], (v) => v?.label ?? 'Type not stated', [
      ...HomeType.values,
      null,
    ]);
    beds = count<int>(
      'beds',
      (h) => [?bedsOption(h)],
      (v) => switch (v) {
        0 => 'Studio',
        5 => '5 or more',
        _ => '$v bed',
      },
      [0, 1, 2, 3, 4, 5],
    );
    furnishing = count<String>('furnishing', (h) => [?furnishingOf(h)], (v) => v, const [
      'Furnished',
      'Part furnished',
      'Unfurnished',
    ]);
    features = count<HomeFeature>(
      'features',
      (h) {
        final text = h.copies.map((c) => c.description).join('\n');
        return HomeFeature.mustHaves.where((x) => x.said(text) == Says.yes);
      },
      (v) => v.label,
      HomeFeature.mustHaves.toList(),
    );
    sites = count<String>(
      'sites',
      (h) => h.sources,
      (v) => v,
      {for (final h in homes) ...h.sources}.toList()..sort(),
    );
    distances = count<double>(
      'distance',
      (h) => [
        if (h.km != null)
          for (final m in _miles)
            if (h.km! / 1.609344 <= m) m,
      ],
      (v) => 'Within ${v == v.roundToDouble() ? v.round() : v} mi',
      _miles,
    );
    final prices = [for (final h in rest('price')) ?h.price]..sort();
    priceLow = prices.firstOrNull;
    priceHigh = prices.lastOrNull;
  }

  late final List<Facet<HomeType?>> types;
  late final List<Facet<int>> beds;
  late final List<Facet<String>> furnishing, sites;
  late final List<Facet<HomeFeature>> features;
  late final List<Facet<double>> distances;

  /// The cheapest and dearest of the results, for the price slider.
  late final int? priceLow, priceHigh;
}

const _miles = [0.5, 1.0, 2.0, 3.0, 5.0, 10.0];

bool _ticked(ResultFilter f, String section, Object? v) => switch (section) {
  'type' => f.types.contains(v),
  'beds' => f.beds.contains(v),
  'furnishing' => f.furnishing.contains(v),
  'features' => f.features.contains(v),
  'sites' => f.sites.contains(v),
  'distance' => f.withinMiles == v,
  _ => false,
};

/// Ready-made price bands for [low]..[high], as shops list them under the
/// slider: about four steps on round numbers.
List<({int? min, int? max})> priceBands(int low, int high, {required bool rent}) {
  if (high <= low) return const [];
  final step = _round((high - low) / 4, rent: rent);
  if (step <= 0) return const [];
  var edge = _round(low + step, rent: rent);
  final bands = <({int? min, int? max})>[(min: null, max: edge)];
  while (edge + step < high) {
    bands.add((min: edge, max: edge + step));
    edge += step;
  }
  return [...bands, (min: edge, max: null)];
}

int _round(num n, {required bool rent}) {
  final unit = rent ? (n < 500 ? 50 : 100) : (n < 50000 ? 5000 : (n < 200000 ? 25000 : 50000));
  return ((n / unit).round() * unit).toInt();
}
