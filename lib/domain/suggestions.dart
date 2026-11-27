/// Suggestions under the Search bar as the user types: their own past and
/// saved searches that contain the words, and places (from postcodes.io)
/// that finish the place being typed.
library;

import 'package:http/http.dart' as http;

import 'research.dart';

/// The place being typed: the words after the last "in", "near" or
/// "around", or the whole text when it is only a place. [before] is the
/// text kept in front of it.
({String before, String place})? placeBeingTyped(String text) {
  final m = RegExp(r'^(.*\b(?:in|near|around|at)\s+)([^,£]{2,})$', caseSensitive: false).firstMatch(text);
  if (m != null) return (before: m.group(1)!, place: m.group(2)!.trim());
  // A lone word or two with no number is likely a place ("Leed", "LS6").
  final t = text.trim();
  if (t.length >= 2 && t.split(RegExp(r'\s+')).length <= 3 && !RegExp(r'\b\d+\s*bed|£|\bunder\b').hasMatch(t)) {
    return (before: '', place: t);
  }
  return null;
}

/// Past or saved searches holding every word typed, most recent first.
List<String> pastMatches(String text, Iterable<String> past, {int max = 4}) {
  final words = text.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return const [];
  return {
    for (final p in past)
      if (words.every(p.toLowerCase().contains) && p.toLowerCase() != text.toLowerCase().trim()) p,
  }.take(max).toList();
}

/// Places starting with [typed]: towns and villages ("Leeds, West
/// Yorkshire"), or postcodes when it looks like one.
Future<List<({String name, String label})>> placesStarting(http.Client client, String typed, {int max = 6}) async {
  final q = typed.trim();
  if (q.length < 2) return const [];
  final postcode = RegExp(r'^[A-Za-z]{1,2}\d').hasMatch(q);
  final r = await Research(client: client).placesLike(q, postcode: postcode);
  return r.take(max).toList();
}

/// One line under the Search bar: what it shows, and the search it fills in.
typedef Suggestion = ({String shown, String text, bool past});
