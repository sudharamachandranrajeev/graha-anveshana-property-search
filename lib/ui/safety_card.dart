import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/search_controller.dart';
import '../domain/safety.dart';
import '../domain/search_request.dart';
import 'common.dart';

/// A safety score for the area around a home or postcode, with its reasons
/// and what insurers look at. Nothing is sent until the user taps Check;
/// then only the map point.
class SafetyCard extends ConsumerStatefulWidget {
  const SafetyCard({super.key, required this.at, this.rough = false});
  final LatLon at;

  /// Only the postcode district is known: the point is its middle.
  final bool rough;

  @override
  ConsumerState<SafetyCard> createState() => _SafetyCardState();
}

class _SafetyCardState extends ConsumerState<SafetyCard> {
  SafetyReport? _report;
  var _busy = false;

  Future<void> _check() async {
    setState(() => _busy = true);
    final r = await ref.read(safetyChecksProvider).report(widget.at);
    if (mounted) {
      setState(() {
        _report = r;
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final r = _report;
    final score = r?.score;
    return Card(
      margin: const EdgeInsets.only(top: 8),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: const Icon(Icons.shield_outlined),
        title: Text(score == null ? 'Safety' : 'Safety: $score out of 10'),
        subtitle: const Text('Crime, road collisions, flood risk and insurance'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (r == null) ...[
            Text(
              'Scores the area from 1 to 10 from government data. Tapping Check sends this map point to '
              'the crime index, road collision and flood map services.',
              style: t.bodySmall,
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _busy ? null : _check,
                icon: _busy
                    ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.shield_outlined, size: 18),
                label: const Text('Check'),
              ),
            ),
          ] else ...[
            if (score != null)
              Row(
                children: [
                  Text('$score', style: t.displaySmall?.copyWith(color: _colour(score, scheme))),
                  Text(' / 10', style: t.titleMedium),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('10 is the safest. Mostly the crime index, less for flood and road risk.'),
                  ),
                ],
              )
            else
              Text(
                'No crime index covers this place (Northern Ireland is not included), so there is no score.',
                style: t.bodySmall,
              ),
            for (final reason in r.reasons)
              Padding(padding: const EdgeInsets.only(top: 6), child: Text('• $reason')),
            if (widget.rough)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'This is for the middle of the postcode district, not the home itself.',
                  style: t.bodySmall,
                ),
              ),
            for (final n in r.notes) Text(n, style: t.bodySmall),
            const Divider(height: 24),
            Text('Home insurance', style: t.titleSmall),
            for (final f in r.insuranceFactors) FigureRow(f.factor, '${f.level} · ${f.why}'),
            Text(
              'What insurers weigh that this data shows. Your price also depends on the home (age, '
              'build, locks), its value and your claims, so get a quote.',
              style: t.bodySmall,
            ),
            if (r.flood == FloodBand.high || r.flood == FloodBand.medium)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.water_outlined),
                title: const Text('Flood Re'),
                subtitle: const Text('Helps homes built before 2009 at flood risk get affordable cover.'),
                trailing: const Icon(Icons.open_in_new),
                onTap: () => openUri(context, Uri.parse(floodReUrl)),
              ),
            Wrap(
              spacing: 8,
              children: [
                for (final (name, url) in insuranceQuoteSites)
                  ActionChip(label: Text(name), onPressed: () => openUri(context, Uri.parse(url))),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static Color _colour(int score, ColorScheme s) =>
      score >= 7 ? Colors.green.shade700 : (score >= 4 ? Colors.orange.shade800 : s.error);
}
