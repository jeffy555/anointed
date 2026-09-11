// The adventure catalogue and the ARB are two lists that have to agree, and
// nothing in the type system makes them. The resolvers return an empty string
// for an id they do not know, so a stop added to the catalogue without its
// strings renders a blank row rather than failing — which is exactly the kind
// of thing that reaches a device. These tests are the missing link.
import 'package:anointed/features/kids_zone/kids_zone_adventures.dart';
import 'package:anointed/features/kids_zone/kids_zone_strings.dart';
import 'package:anointed/l10n/gen/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  test('every adventure has a name and a subtitle', () {
    for (final KidsAdventure adventure in kKidsAdventures) {
      expect(kidsZoneAdventureTitle(l10n, adventure.id), isNotEmpty,
          reason: 'no title for adventure "${adventure.id}"');
      expect(kidsZoneAdventureSubtitle(l10n, adventure.id), isNotEmpty,
          reason: 'no subtitle for adventure "${adventure.id}"');
    }
  });

  test('every stop has a name and a teaser', () {
    for (final KidsAdventure adventure in kKidsAdventures) {
      for (final KidsAdventureStop stop in adventure.stops) {
        expect(kidsZoneStopTitle(l10n, stop.id), isNotEmpty,
            reason: 'no title for stop "${stop.id}"');
        expect(kidsZoneStopTeaser(l10n, stop.id), isNotEmpty,
            reason: 'no teaser for stop "${stop.id}"');
      }
    }
  });

  test('an id the ARB does not cover resolves to empty, not to a crash', () {
    // The blank is deliberate: a missing string should degrade to a quiet gap
    // in a child's screen, not take the whole zone down with it. The tests
    // above are what stop that blank ever shipping.
    expect(kidsZoneStopTitle(l10n, 'not_a_stop'), isEmpty);
    expect(kidsZoneAdventureTitle(l10n, 'not_an_adventure'), isEmpty);
  });

  test('the copy is real English, not a key echoed back', () {
    // Guards against a resolver that "works" by returning its own id.
    expect(kidsZoneAdventureTitle(l10n, 'creation_garden'), 'Creation Garden');
    expect(kidsZoneStopTitle(l10n, 'moses_3'), 'Level 3 - Crossing the Sea');
    expect(kidsZoneStopTeaser(l10n, 'ark_1'), 'Drag the timber into place');
  });
}
