import 'dart:convert';

import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../app/search_controller.dart';
import '../db/database.dart';
import '../domain/advert.dart';
import '../domain/book.dart';
import '../domain/home_records.dart';
import '../domain/listing.dart';
import '../domain/pipeline.dart';
import '../domain/research.dart';
import '../domain/sources.dart';
import 'advert_view.dart';
import 'browser_page.dart';
import 'common.dart';

/// A saved home's advert, kept in the app: it stays after the site takes
/// the advert down. Read again from the site the first time the home is
/// opened in a session, so price cuts and "let agreed" are caught.
class SavedAdvertCard extends ConsumerStatefulWidget {
  const SavedAdvertCard(this.p, {super.key});
  final Property p;

  @override
  ConsumerState<SavedAdvertCard> createState() => _SavedAdvertCardState();
}

class _SavedAdvertCardState extends ConsumerState<SavedAdvertCard> {
  /// Homes whose advert was read since the app started: opening one again
  /// does not ask the site again.
  static final _readThisRun = <String>{};

  var _busy = false;
  String _note = '';

  SourceId? get _source => SourceId.ofKey(widget.p.source);

  /// The site's advert page can be read without a browser.
  bool get _readable => widget.p.url.startsWith('https://') && _source != null && !_source!.readInBrowser;

  @override
  void initState() {
    super.initState();
    if (_readable && _readThisRun.add(widget.p.id)) _refresh();
  }

  Future<void> _refresh() async {
    final p = widget.p;
    setState(() {
      _busy = true;
      _note = '';
    });
    try {
      final d = await readAdvert(
        ref.read(searchHttpProvider),
        Listing(source: p.source, sourceId: p.sourceId ?? '', url: p.url, address: p.address),
      );
      if (d != null) await ref.mutate((s) => s.book.applyAdvert(p.id, d, ref.read(todayProvider)));
    } on SourceBlocked {
      _note =
          '${_source?.label ?? 'The site'} asked to check you are not a robot. Open the advert to see it.';
    } on Object catch (e) {
      _note = 'Could not read the advert just now (${describeError(e)}).';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    final saved = SavedRecords.of(p.meta);
    final advert = saved.advert;
    final words = '${(jsonDecode(p.meta) as Map)['description'] ?? ''}';
    final t = Theme.of(context).textTheme;
    final site = _source?.label ?? 'the site';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (advert != null)
          AdvertSections(
            advert,
            rent: PropertyKind.of(p.kind) == PropertyKind.rent,
            fallbackDescription: words,
          )
        else if (words.isNotEmpty)
          SectionCard(title: 'Description', child: Text(words)),
        if (_readable || _note.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                if (_busy) ...[
                  const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    _busy
                        ? 'Checking the advert on $site…'
                        : _note.isNotEmpty
                        ? _note
                        : saved.advertRead == null
                        ? 'The advert has not been read yet.'
                        : 'Advert last checked on $site ${niceDate(saved.advertRead!)}.',
                    style: t.bodySmall,
                  ),
                ),
                if (!_busy)
                  TextButton.icon(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Check again'),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// The house's own records: its energy certificate and what it sold for
/// before. Looked up only when the user taps; then only the postcode is
/// sent (to HM Land Registry, and with the user's key to the EPC register).
class HomeRecordsCard extends ConsumerStatefulWidget {
  const HomeRecordsCard(this.p, {super.key});
  final Property p;

  @override
  ConsumerState<HomeRecordsCard> createState() => _HomeRecordsCardState();
}

class _HomeRecordsCardState extends ConsumerState<HomeRecordsCard> {
  var _busy = false;
  final _notes = <String>[];

  /// Certificates in the postcode, when none matched the address: the
  /// user picks this home's.
  List<EpcEntry> _unmatched = const [];

  Future<void> _lookUp() async {
    final p = widget.p;
    final today = ref.read(todayProvider);
    setState(() {
      _busy = true;
      _notes.clear();
      _unmatched = const [];
    });
    List<Sale>? sales;
    EpcCertificate? epc;
    try {
      sales = salesOf(p.address, await Research(client: ref.read(searchHttpProvider)).sales(p.postcode));
    } on Object catch (e) {
      _notes.add('Past sales: ${describeError(e)}');
    }
    final key = (await ref.read(sessionProvider).book.pref<String>(PrefKeys.epcKey, '')).trim();
    if (key.isEmpty) {
      _notes.add('Energy certificate: add your free EPC register key in Settings to see it here.');
    } else {
      try {
        final register = EpcRegister(ref.read(searchHttpProvider), key);
        final all = await register.inPostcode(p.postcode);
        final mine = all.where((e) => sameHouse(p.address, e.address)).firstOrNull;
        if (mine != null) {
          epc = await register.certificate(mine.number);
        } else if (all.isEmpty) {
          _notes.add('Energy certificate: none in ${p.postcode}.');
        } else {
          _unmatched = all;
        }
      } on Object catch (e) {
        _notes.add('Energy certificate: ${describeError(e)}');
      }
    }
    await ref.mutate((s) => s.book.saveRecords(p.id, epc: epc, sales: sales, today: today));
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _pick() async {
    final picked = await showDialog<EpcEntry>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Which is this home?'),
        children: [
          for (final e in _unmatched)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, e),
              child: Text('${e.address}\nBand ${e.band} · ${niceDate(e.date)}'),
            ),
        ],
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final key = await ref.read(sessionProvider).book.pref<String>(PrefKeys.epcKey, '');
      final epc = await EpcRegister(ref.read(searchHttpProvider), key.trim()).certificate(picked.number);
      await ref.mutate((s) => s.book.saveRecords(widget.p.id, epc: epc, today: ref.read(todayProvider)));
      _unmatched = const [];
    } on Object catch (e) {
      _notes.add('Energy certificate: ${describeError(e)}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    if (p.postcode.isEmpty) return const SizedBox.shrink();
    final saved = SavedRecords.of(p.meta);
    final epc = saved.epc, sales = saved.sales;
    final t = Theme.of(context).textTheme;
    return SectionCard(
      title: 'This home\'s records',
      trailing: _busy
          ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
          : TextButton(onPressed: _lookUp, child: Text(saved.recordsRead == null ? 'Look up' : 'Look again')),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (saved.recordsRead == null)
            Text(
              'Its energy certificate and what it sold for before, from the official registers '
              '(England and Wales). Only the postcode is sent.',
              style: t.bodySmall,
            ),
          if (epc != null) ...[
            Text('Energy certificate', style: t.titleSmall),
            FigureRow('Rating now', [epc.band, if (epc.score != null) '(${epc.score})'].join(' ')),
            if (epc.potentialBand.isNotEmpty)
              FigureRow(
                'Could be',
                [epc.potentialBand, if (epc.potentialScore != null) '(${epc.potentialScore})'].join(' '),
              ),
            if (epc.floorArea != null)
              FigureRow('Floor area', '${epc.floorArea} m² (${(epc.floorArea! * 10.764).round()} sq ft)'),
            if (epc.dwelling.isNotEmpty) FigureRow('Type', epc.dwelling),
            if (epc.heating.isNotEmpty) FigureRow('Heating', epc.heating),
            if (epc.walls.isNotEmpty) FigureRow('Walls', epc.walls),
            if (epc.roof.isNotEmpty) FigureRow('Roof', epc.roof),
            if (epc.windows.isNotEmpty) FigureRow('Windows', epc.windows),
            if (epc.heatingCostYear != null)
              FigureRow('Heating cost', '${gbp(epc.heatingCostYear!)} a year (estimate)'),
            if (epc.date.isNotEmpty) FigureRow('Certificate from', niceDate(epc.date)),
            TextButton.icon(
              onPressed: () => openInApp(context, epc.page, title: 'Energy certificate'),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: Text(
                epc.upgrades > 0
                    ? 'See the certificate and its ${epc.upgrades} upgrades'
                    : 'See the certificate',
              ),
            ),
          ],
          if (_unmatched.isNotEmpty)
            OutlinedButton(
              onPressed: _pick,
              child: Text('Pick this home from ${_unmatched.length} certificates in ${p.postcode}'),
            ),
          if (sales != null) ...[
            const SizedBox(height: 8),
            Text('Sold before', style: t.titleSmall),
            if (sales.isEmpty)
              Text(
                'No sale of this address since 1995 in HM Land Registry. If the address has no house '
                'number, add it with Edit and look again.',
                style: t.bodySmall,
              )
            else
              for (final s in sales) FigureRow(niceDate(s.date), gbp(s.price)),
          ],
          for (final n in _notes) ...[const SizedBox(height: 4), Text(n, style: t.bodySmall)],
        ],
      ),
    );
  }
}
