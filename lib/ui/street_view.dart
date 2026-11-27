import 'package:brahma_core/brahma_core.dart' show SectionCard;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'browser_page.dart' show hasWebView, openInApp;

/// Google's Street View at a point, without a key: the embed Google Maps
/// itself uses. It is not a documented API, so if Google changes it the
/// panel goes blank and the button still opens Google Maps.
Uri streetViewEmbed(double lat, double lon) => Uri.parse(
  'https://maps.google.com/maps?layer=c&cbll=$lat,$lon&cbp=11,0,0,0,0&source=embed&output=svembed',
);

/// Street View in Google Maps (its documented link), for the browser.
Uri streetViewLink(double lat, double lon) =>
    Uri.parse('https://www.google.com/maps/@?api=1&map_action=pano&viewpoint=$lat,$lon');

/// Street View of a home, inside the page. Nothing is sent to Google until
/// the user taps Show; then only the map point.
class StreetViewPanel extends StatefulWidget {
  const StreetViewPanel({super.key, required this.lat, required this.lon, this.rough = false});
  final double lat, lon;

  /// Only the postcode district is known: the view is of its middle.
  final bool rough;

  @override
  State<StreetViewPanel> createState() => _StreetViewPanelState();
}

class _StreetViewPanelState extends State<StreetViewPanel> {
  var _shown = false;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final open = TextButton.icon(
      onPressed: () => openInApp(context, streetViewLink(widget.lat, widget.lon), title: 'Street View'),
      icon: const Icon(Icons.open_in_new, size: 18),
      label: const Text('Open in Google Maps'),
    );
    return SectionCard(
      title: 'Street View',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.rough)
            Text('The advert gives only the postcode district, so this is its middle, not the home.', style: t.bodySmall),
          if (!hasWebView)
            Text('This build has no in-app browser to show Street View in.', style: t.bodySmall)
          else if (!_shown)
            Text('Look at the street from the road. Tapping Show sends this map point to Google.', style: t.bodySmall)
          else
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 320,
                  child: InAppWebView(
                    initialUrlRequest: URLRequest(url: WebUri.uri(streetViewEmbed(widget.lat, widget.lon))),
                    initialSettings: InAppWebViewSettings(
                      javaScriptEnabled: true,
                      // Links in the panel open Google Maps outside the app,
                      // not inside the small panel.
                      useShouldOverrideUrlLoading: true,
                      supportZoom: false,
                    ),
                    // Dragging turns the view instead of scrolling the page.
                    gestureRecognizers: {Factory<OneSequenceGestureRecognizer>(EagerGestureRecognizer.new)},
                    shouldOverrideUrlLoading: (_, action) async {
                      final u = action.request.url;
                      if (u == null || !action.isForMainFrame || (u.host.endsWith('google.com') && u.path == '/maps')) {
                        return NavigationActionPolicy.ALLOW;
                      }
                      if (context.mounted) await openInApp(context, u.uriValue);
                      return NavigationActionPolicy.CANCEL;
                    },
                  ),
                ),
              ),
            ),
          Wrap(
            spacing: 8,
            children: [
              if (hasWebView && !_shown)
                FilledButton.tonalIcon(
                  onPressed: () => setState(() => _shown = true),
                  icon: const Icon(Icons.streetview),
                  label: const Text('Show'),
                ),
              open,
            ],
          ),
        ],
      ),
    );
  }
}
