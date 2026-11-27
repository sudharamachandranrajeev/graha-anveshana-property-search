import 'package:anveshana/domain/home_features.dart';
import 'package:anveshana/domain/listing.dart';
import 'package:anveshana/domain/property_search.dart';
import 'package:anveshana/domain/result_filter.dart';
import 'package:anveshana/domain/suggestions.dart';
import 'package:flutter_test/flutter_test.dart';

FoundHome _home(
  String id, {
  String source = 'rightmove',
  String style = '',
  String description = '',
  int? beds,
  int? price,
  String furnished = '',
  double? km,
}) => FoundHome(
  Listing(
    source: source,
    sourceId: id,
    url: 'https://example.invalid/$id',
    address: '$id Sample Street, Leeds',
    style: style,
    description: description,
    beds: beds,
    price: price,
    furnished: furnished,
  ),
)..km = km;

void main() {
  test('the type of home comes from the site, else the advert', () {
    expect(homeTypeOf(_home('1', style: 'Semi-Detached')), HomeType.semi);
    expect(homeTypeOf(_home('2', style: 'End of Terrace')), HomeType.terraced);
    expect(homeTypeOf(_home('3', style: 'Detached')), HomeType.detached);
    expect(homeTypeOf(_home('4', description: 'A bright apartment near the park')), HomeType.flat);
    expect(homeTypeOf(_home('5', beds: 0)), HomeType.studio);
    expect(homeTypeOf(_home('6', description: 'Room in a shared house, bills included')), HomeType.room);
    expect(homeTypeOf(_home('7', description: 'Well kept')), isNull);
  });

  test('ticks in one section widen, sections narrow each other', () {
    final homes = [
      _home('1', style: 'Flat', beds: 1, price: 800, km: 1),
      _home('2', style: 'Flat', beds: 2, price: 1000, km: 4),
      _home('3', style: 'Terraced', beds: 2, price: 1200, km: 2, description: 'Garden and parking'),
      _home('4', style: 'Detached', beds: 4, price: 2000, source: 'zoopla'),
    ];
    List<String> ids(ResultFilter f) => [
      for (final h in homes)
        if (f.matches(h)) h.main.sourceId,
    ];

    expect(ids(const ResultFilter(types: {HomeType.flat, HomeType.terraced})), ['1', '2', '3']);
    expect(ids(const ResultFilter(types: {HomeType.flat}, beds: {2})), ['2']);
    expect(ids(const ResultFilter(minPrice: 900, maxPrice: 1500)), ['2', '3']);
    expect(ids(const ResultFilter(features: {HomeFeature.garden})), ['3']);
    expect(ids(const ResultFilter(sites: {'zoopla'})), ['4']);
    expect(ids(const ResultFilter(withinMiles: 2)), ['1', '3']);

    // A section's counts leave its own ticks off, so the other types still
    // show what ticking them would add.
    final facets = Facets(homes, const ResultFilter(types: {HomeType.flat}, beds: {2}));
    expect(
      {for (final o in facets.types) o.value: o.count},
      {HomeType.flat: 1, HomeType.terraced: 1},
    );
    expect({for (final o in facets.beds) o.value: o.count}, {1: 1, 2: 1});
    expect(const ResultFilter(types: {HomeType.flat}, beds: {2}).count, 2);
  });

  test('price bands cover the results on round numbers', () {
    final bands = priceBands(800, 2000, rent: true);
    expect(bands.first, (min: null, max: 1100));
    expect(bands.last.max, isNull);
    for (var i = 1; i < bands.length; i++) {
      expect(bands[i].min, bands[i - 1].max);
    }
    expect(priceBands(900, 900, rent: true), isEmpty);
  });

  test('the place being typed, and past searches matching the words', () {
    expect(placeBeingTyped('2 bed to rent in Lee'), (before: '2 bed to rent in ', place: 'Lee'));
    expect(placeBeingTyped('flats near Hea'), (before: 'flats near ', place: 'Hea'));
    expect(placeBeingTyped('Harro'), (before: '', place: 'Harro'));
    expect(placeBeingTyped('2 bed under £900'), isNull);
    expect(pastMatches('leeds 2', ['2 bed in Leeds', '3 bed in York', '2 bed flat in Leeds LS6']), [
      '2 bed in Leeds',
      '2 bed flat in Leeds LS6',
    ]);
  });
}
