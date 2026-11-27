import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';

import '../domain/advert.dart';
import '../domain/leasehold.dart';
import 'common.dart';
import 'look.dart';

/// What an advert page says, shown the same way for a home in Search and a
/// saved one: key features, details, leasehold costs, description and
/// floor plans.
class AdvertSections extends StatelessWidget {
  const AdvertSections(this.d, {super.key, required this.rent, this.fallbackDescription = ''});
  final AdvertDetails d;
  final bool rent;

  /// Shown when the page gave no description (the results page's words).
  final String fallbackDescription;

  @override
  Widget build(BuildContext context) {
    final description = d.description.isEmpty ? fallbackDescription : d.description;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (d.features.isNotEmpty)
          SectionCard(
            title: 'Key features',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [for (final f in d.features) Text('• $f')],
            ),
          ),
        if (d.facts.isNotEmpty)
          SectionCard(
            title: 'Details',
            child: Column(children: [for (final e in d.facts.entries) FigureRow(e.key, e.value)]),
          ),
        if (!rent) LeaseholdCard(readLeasehold(d, thisYear: DateTime.now().year)),
        if (description.isNotEmpty) SectionCard(title: 'Description', child: Text(description)),
        if (d.floorplans.isNotEmpty)
          SectionCard(
            title: 'Floor plans',
            child: Column(
              children: [
                for (final f in d.floorplans)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Image.network(f, errorBuilder: (_, _, _) => const SizedBox()),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// An advert's photos, one at a time.
class PhotoGallery extends StatefulWidget {
  const PhotoGallery(this.photos, {super.key});
  final List<String> photos;

  @override
  State<PhotoGallery> createState() => _PhotoGalleryState();
}

class _PhotoGalleryState extends State<PhotoGallery> {
  final _pages = PageController();
  var _at = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _go(int i) => _pages.animateToPage(i, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);

  @override
  Widget build(BuildContext context) {
    final n = widget.photos.length;
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 16 / 10,
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: _pages,
              itemCount: n,
              onPageChanged: (i) => setState(() => _at = i),
              itemBuilder: (_, i) => Image.network(
                widget.photos[i],
                fit: BoxFit.cover,
                semanticLabel: 'Photo ${i + 1} of $n',
                errorBuilder: (_, _, _) => ColoredBox(color: scheme.surfaceContainerHighest),
              ),
            ),
            if (n > 1) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton.filledTonal(
                  tooltip: 'Previous photo',
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _at == 0 ? null : () => _go(_at - 1),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: IconButton.filledTonal(
                  tooltip: 'Next photo',
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _at == n - 1 ? null : () => _go(_at + 1),
                ),
              ),
              Align(
                alignment: Alignment.bottomRight,
                child: Padding(padding: const EdgeInsets.all(8), child: Capsule('${_at + 1} / $n')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A line of text with a button that copies it.
class CopyLine extends StatelessWidget {
  const CopyLine(this.text, {super.key, required this.what, this.style});
  final String text;

  /// What is copied, for the button's tooltip and message ("address").
  final String what;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(child: Text(text, style: style)),
      IconButton(
        tooltip: 'Copy the $what',
        visualDensity: VisualDensity.compact,
        icon: const Icon(Icons.copy, size: 18),
        onPressed: () => copyText(context, text, what: '${what[0].toUpperCase()}${what.substring(1)} copied.'),
      ),
    ],
  );
}

/// A leasehold home's yearly costs on top of the mortgage, and what the
/// advert leaves out. Nothing for a freehold home.
class LeaseholdCard extends StatelessWidget {
  const LeaseholdCard(this.lease, {super.key});
  final LeaseholdCosts lease;

  @override
  Widget build(BuildContext context) {
    if (!lease.leasehold) return const SizedBox.shrink();
    final t = Theme.of(context).textTheme;
    final monthly = lease.monthly;
    return SectionCard(
      title: 'Leasehold costs',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FigureRow('Tenure', lease.tenure.isEmpty ? 'Share of freehold' : lease.tenure),
          if (lease.serviceChargeYear != null)
            FigureRow('Service charge', '${gbp(lease.serviceChargeYear!)} a year'),
          if (lease.groundRentYear != null)
            FigureRow(
              'Ground rent',
              lease.groundRentYear == 0 ? 'None (peppercorn)' : '${gbp(lease.groundRentYear!)} a year',
            ),
          if (lease.yearsLeft != null) FigureRow('Lease', '${lease.yearsLeft} years left'),
          if (monthly != null) FigureRow('On top of the mortgage', '${gbp(monthly)} a month'),
          if (lease.missing.isNotEmpty) ...[
            const SizedBox(height: 8),
            StatusLabel(
              Status.warning,
              'The advert does not give the ${lease.missing.join(', ')}. Ask the agent.',
            ),
          ],
          for (final w in lease.warnings) ...[const SizedBox(height: 8), StatusLabel(Status.warning, w)],
          const SizedBox(height: 8),
          Text(
            'From the advert. Charges can rise; your solicitor checks the lease itself.',
            style: t.bodySmall,
          ),
        ],
      ),
    );
  }
}
