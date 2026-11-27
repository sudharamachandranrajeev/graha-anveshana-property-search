import 'package:flutter/material.dart';

import '../domain/property_search.dart';
import '../domain/result_filter.dart';
import 'common.dart';

/// The filters beside the results, laid out as shops do: a heading per
/// section, a tick box per option with how many homes it shows, a price
/// slider with ready-made bands, and "See more" on long lists.
class ResultFilterPanel extends StatelessWidget {
  const ResultFilterPanel({
    super.key,
    required this.homes,
    required this.filter,
    required this.rent,
    required this.onChanged,
    this.siteLabel = _same,
  });

  /// Every home the search found, before these filters.
  final List<FoundHome> homes;
  final ResultFilter filter;
  final bool rent;
  final ValueChanged<ResultFilter> onChanged;

  /// A site's name from its key ("rightmove" -> "Rightmove").
  final String Function(String key) siteLabel;

  static String _same(String s) => s;

  @override
  Widget build(BuildContext context) {
    final f = filter;
    final facets = Facets(homes, f);
    final t = Theme.of(context).textTheme;
    Set<T> flip<T>(Set<T> s, T v) => s.contains(v) ? ({...s}..remove(v)) : {...s, v};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('Filters', style: t.titleMedium)),
            if (!f.isEmpty) TextButton(onPressed: () => onChanged(const ResultFilter()), child: const Text('Clear all')),
          ],
        ),
        _Section<HomeType?>(
          title: 'Type of home',
          options: facets.types,
          ticked: f.types.contains,
          onTap: (v) => onChanged(f.copyWith(types: flip(f.types, v))),
        ),
        _Section<int>(
          title: 'Bedrooms',
          options: facets.beds,
          ticked: f.beds.contains,
          onTap: (v) => onChanged(f.copyWith(beds: flip(f.beds, v))),
        ),
        if (facets.priceLow != null && facets.priceHigh != null && facets.priceHigh! > facets.priceLow!)
          _PriceSection(
            low: facets.priceLow!,
            high: facets.priceHigh!,
            rent: rent,
            min: f.minPrice,
            max: f.maxPrice,
            onChanged: (a, b) => onChanged(f.copyWith(minPrice: () => a, maxPrice: () => b)),
          ),
        if (rent)
          _Section<String>(
            title: 'Furnishing',
            options: facets.furnishing,
            ticked: f.furnishing.contains,
            onTap: (v) => onChanged(f.copyWith(furnishing: flip(f.furnishing, v))),
          ),
        _Section(
          title: 'The advert mentions',
          options: facets.features,
          ticked: f.features.contains,
          onTap: (v) => onChanged(f.copyWith(features: flip(f.features, v))),
        ),
        _Section<double>(
          title: 'Distance',
          options: facets.distances,
          ticked: (v) => f.withinMiles == v,
          onTap: (v) => onChanged(f.copyWith(withinMiles: () => f.withinMiles == v ? null : v)),
        ),
        _Section<String>(
          title: 'Site',
          options: [for (final o in facets.sites) (value: o.value, label: siteLabel(o.value), count: o.count)],
          ticked: f.sites.contains,
          onTap: (v) => onChanged(f.copyWith(sites: flip(f.sites, v))),
        ),
      ],
    );
  }
}

/// One section: a heading and a tick box per option, the first six shown
/// until "See more".
class _Section<T> extends StatefulWidget {
  const _Section({required this.title, required this.options, required this.ticked, required this.onTap});
  final String title;
  final List<Facet<T>> options;
  final bool Function(T v) ticked;
  final ValueChanged<T> onTap;

  @override
  State<_Section<T>> createState() => _SectionState<T>();
}

class _SectionState<T> extends State<_Section<T>> {
  static const _short = 6;
  var _all = false;

  @override
  Widget build(BuildContext context) {
    final options = widget.options;
    if (options.isEmpty) return const SizedBox.shrink();
    final t = Theme.of(context).textTheme;
    final shown = _all ? options : options.take(_short);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.title, style: t.titleSmall),
          for (final o in shown)
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              visualDensity: VisualDensity.compact,
              value: widget.ticked(o.value),
              title: Text('${o.label} (${o.count})'),
              onChanged: o.count == 0 && !widget.ticked(o.value) ? null : (_) => widget.onTap(o.value),
            ),
          if (options.length > _short)
            TextButton.icon(
              onPressed: () => setState(() => _all = !_all),
              icon: Icon(_all ? Icons.expand_less : Icons.expand_more, size: 18),
              label: Text(_all ? 'See less' : 'See more'),
            ),
        ],
      ),
    );
  }
}

/// A price slider from the cheapest result to the dearest, with bands to
/// tap beneath it.
class _PriceSection extends StatefulWidget {
  const _PriceSection({
    required this.low,
    required this.high,
    required this.rent,
    required this.min,
    required this.max,
    required this.onChanged,
  });
  final int low, high;
  final bool rent;
  final int? min, max;
  final void Function(int? min, int? max) onChanged;

  @override
  State<_PriceSection> createState() => _PriceSectionState();
}

class _PriceSectionState extends State<_PriceSection> {
  /// Where the handles are while being dragged; null: the filter's values.
  RangeValues? _dragging;

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final t = Theme.of(context).textTheme;
    double clamp(int? v, int fallback) => (v ?? fallback).clamp(w.low, w.high).toDouble();
    final values = _dragging ?? RangeValues(clamp(w.min, w.low), clamp(w.max, w.high));
    final per = w.rent ? ' pcm' : '';
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Price', style: t.titleSmall),
          Text('${gbp(values.start.round())} – ${gbp(values.end.round())}$per', style: t.bodyMedium),
          RangeSlider(
            min: w.low.toDouble(),
            max: w.high.toDouble(),
            values: values,
            onChanged: (v) => setState(() => _dragging = v),
            onChangeEnd: (v) {
              setState(() => _dragging = null);
              w.onChanged(
                v.start.round() <= w.low ? null : v.start.round(),
                v.end.round() >= w.high ? null : v.end.round(),
              );
            },
          ),
          for (final b in priceBands(w.low, w.high, rent: w.rent))
            InkWell(
              onTap: () => w.onChanged(b.min, b.max),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  switch (b) {
                    (min: null, max: final m?) => 'Up to ${gbp(m)}',
                    (min: final a?, max: null) => '${gbp(a)} and above',
                    (min: final a?, max: final m?) => '${gbp(a)} to ${gbp(m)}',
                    _ => '',
                  },
                  style: TextStyle(
                    fontWeight: w.min == b.min && w.max == b.max ? FontWeight.w600 : null,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
