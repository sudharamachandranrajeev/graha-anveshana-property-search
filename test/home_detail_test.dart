import 'dart:convert';

import 'package:anveshana/db/database.dart';
import 'package:anveshana/domain/advert.dart';
import 'package:anveshana/domain/book.dart';
import 'package:anveshana/domain/home_records.dart';
import 'package:anveshana/domain/listing.dart';
import 'package:anveshana/domain/pipeline.dart';
import 'package:anveshana/domain/price_log.dart';
import 'package:brahma_core/brahma_core.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

// A saved home's full advert, its refresh, its records and the summary
// that is copied.
void main() {
  test('an advert is kept in meta and read back the same', () {
    const d = AdvertDetails(
      description: 'Bright flat.',
      photos: ['https://media.example/1.jpg', 'https://media.example/2.jpg'],
      floorplans: ['https://media.example/plan.jpg'],
      features: ['Parking'],
      facts: {'Deposit': '£900'},
      agent: 'Example Lettings',
      phone: '0100 000 000',
    );
    final back = AdvertDetails.fromJson(jsonDecode(jsonEncode(d.toJson())))!;
    expect(back.description, d.description);
    expect(back.photos, d.photos);
    expect(back.floorplans, d.floorplans);
    expect(back.features, d.features);
    expect(back.facts, d.facts);
    expect(back.agent, d.agent);
    expect(back.phone, d.phone);
    expect(AdvertDetails.fromJson(null), isNull);
  });

  test('advert status from the words on the page', () {
    expect(advertStatusIn('2 bed flat - Let Agreed'), 'letAgreed');
    expect(advertStatusIn('This property has been let'), 'letAgreed');
    expect(advertStatusIn('Sold STC'), 'saleAgreed');
    expect(advertStatusIn('UNDER_OFFER'), 'saleAgreed');
    expect(advertStatusIn('This property is no longer available'), 'withdrawn');
    expect(advertStatusIn('2 bed flat to rent'), '');
  });

  test('the copied summary has the address, price, facts, agent and link', () {
    final text = homeSummary(
      address: '1 Example Road, Leeds LS6 1AA',
      price: 1250,
      rent: true,
      facts: ['2 bed', 'Flat'],
      agent: 'Example Lettings',
      phone: '0100 000 000',
      url: 'https://www.rightmove.co.uk/properties/1',
      advert: const AdvertDetails(facts: {'Deposit': '£1,442'}, features: ['Parking']),
    );
    expect(
      text,
      '1 Example Road, Leeds LS6 1AA\n£1,250 a month\n2 bed · Flat\nDeposit: £1,442\n\nKey features\n• Parking\n'
      '\nAgent: Example Lettings, 0100 000 000\n\nhttps://www.rightmove.co.uk/properties/1',
    );
  });

  group('saved home', () {
    late AppDatabase db;
    late PropertyBook book;

    setUp(() async {
      db = memoryDatabase();
      book = PropertyBook(await Store.open(db));
    });
    tearDown(() => db.close());

    Future<Property> only() async => (await db.select(db.properties).get()).single;

    test('reading the advert keeps it, logs a price cut and the let', () async {
      final l = parsePropertyPalPage(nextData({'property': samplePropertyPal(price: 650)})).single;
      final id = (await book.importListing(l, today: '2026-11-01')).id;
      final seenBefore = MarketFacts.of((await only()).meta).seen;

      await book.applyAdvert(
        id,
        const AdvertDetails(
          description: 'Bright flat.',
          photos: ['https://media.example/1.jpg'],
          price: 600,
          status: 'letAgreed',
        ),
        '2026-11-20',
      );
      var p = await only();
      expect(p.price, 600);
      expect(p.listingStatus, 'letAgreed');
      expect(listingGone(p.listingStatus), isTrue);
      expect(p.imageUrl, 'https://media.example/1.jpg');
      final saved = SavedRecords.of(p.meta);
      expect(saved.advert?.description, 'Bright flat.');
      expect(saved.advertRead, '2026-11-20');
      final market = MarketFacts.of(p.meta);
      expect(market.prices.map((x) => x.price), [650, 600]);
      // "Last seen in Search" is Search's, not the refresh's.
      expect(market.seen, seenBefore);

      // Taken down: the advert read before is kept.
      await book.applyAdvert(id, AdvertDetails.takenDown, '2026-11-25');
      p = await only();
      expect(p.listingStatus, 'withdrawn');
      expect(SavedRecords.of(p.meta).advert?.description, 'Bright flat.');
    });

    test('records are kept with the home', () async {
      final l = parsePropertyPalPage(nextData({'property': samplePropertyPal()})).single;
      final id = (await book.importListing(l, today: '2026-11-01')).id;
      await book.saveRecords(
        id,
        epc: const EpcCertificate(number: '0000-0000-0000-0000-0001', band: 'C', score: 72),
        sales: const [],
        today: '2026-11-02',
      );
      final r = SavedRecords.of((await only()).meta);
      expect(r.epc?.band, 'C');
      expect(r.epc?.score, 72);
      expect(r.sales, isEmpty);
      expect(r.recordsRead, '2026-11-02');
    });
  });

  test('EPC register answers are read, old and new schemas alike', () {
    final search = jsonEncode({
      'data': [
        {
          'certificateNumber': '1111-2222-3333-4444-5555',
          'addressLine1': '1 Some Street',
          'postTown': 'Whitbury',
          'postcode': 'A0 0AA',
          'currentEnergyEfficiencyBand': 'E',
          'registrationDate': '2025-04-04',
        },
      ],
      'pagination': {'totalRecords': 1},
    });
    final rows = parseEpcSearch(search);
    expect(rows.single.number, '1111-2222-3333-4444-5555');
    expect(rows.single.address, '1 Some Street, Whitbury');
    expect(rows.single.band, 'E');

    // Shaped like the register's RdSAP 17 sample: text and money wrapped.
    final cert = parseEpcCertificate(
      '1111-2222-3333-4444-5555',
      jsonEncode({
        'data': {
          'current_energy_efficiency_band': 'D',
          'potential_energy_efficiency_band': 'C',
          'energy_rating_current': 66,
          'energy_rating_potential': 79,
          'total_floor_area': 55,
          'dwelling_type': {'value': 'Mid-floor flat', 'language': '1'},
          'main_heating': [
            {
              'description': {'value': 'Electric storage heaters', 'language': '1'},
            },
          ],
          'walls': [
            {'description': 'Brick walls'},
          ],
          'heating_cost_current': {'value': 214, 'currency': 'GBP'},
          'registration_date': '2016-01-12',
          'suggested_improvements': [{}, {}],
        },
      }),
    );
    expect(cert.band, 'D');
    expect(cert.potentialBand, 'C');
    expect(cert.score, 66);
    expect(cert.floorArea, 55);
    expect(cert.dwelling, 'Mid-floor flat');
    expect(cert.heating, 'Electric storage heaters');
    expect(cert.walls, 'Brick walls');
    expect(cert.heatingCostYear, 214);
    expect(cert.upgrades, 2);
    expect(EpcCertificate.fromJson(cert.toJson())?.dwelling, 'Mid-floor flat');
  });
}
