// Kids Zone progress is device-local, so LocalStore is the whole contract:
// what a child earned, what survives a replay, and what leaves with the account.
import 'package:anointed/core/local_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStore store;

  Future<void> freshStore() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    store = LocalStore(
      await SharedPreferences.getInstance(),
      const FlutterSecureStorage(),
    );
  }

  setUp(freshStore);

  group('stars', () {
    test('a finished stop records the stars it was finished with', () async {
      await store.markKidsZoneStopComplete('garden_1', stars: 2);

      expect(store.isKidsZoneStopComplete('garden_1'), isTrue);
      expect(store.kidsZoneStarsFor('garden_1'), 2);
    });

    test('a stop never played has no stars and is not complete', () {
      expect(store.isKidsZoneStopComplete('garden_1'), isFalse);
      expect(store.kidsZoneStarsFor('garden_1'), 0);
    });

    test('replaying keeps the best result, not the latest', () async {
      await store.markKidsZoneStopComplete('ark_1', stars: 3);
      // A child who goes back for fun and does worse should not be punished for
      // it — the star they already earned is theirs.
      await store.markKidsZoneStopComplete('ark_1', stars: 1);

      expect(store.kidsZoneStarsFor('ark_1'), 3);
    });

    test('a better replay does raise it', () async {
      await store.markKidsZoneStopComplete('ark_1', stars: 1);
      await store.markKidsZoneStopComplete('ark_1', stars: 3);

      expect(store.kidsZoneStarsFor('ark_1'), 3);
    });

    test('stops are recorded independently', () async {
      await store.markKidsZoneStopComplete('moses_1', stars: 1);
      await store.markKidsZoneStopComplete('moses_2', stars: 3);

      expect(store.kidsZoneStars,
          <String, int>{'moses_1': 1, 'moses_2': 3});
      expect(store.kidsZoneCompletedStops, <String>{'moses_1', 'moses_2'});
    });
  });

  group('signing out', () {
    test('takes the whole Kids Zone record with it', () async {
      await store.markKidsZoneStopComplete('garden_1', stars: 3);
      await store.markKidsZoneStopComplete('garden_2', stars: 2);
      await store.markKidsZoneTutorialSeen('ark_animal_care');
      await store.setCurrentLevel(12);

      await store.clearAccountScopedState();

      // Otherwise the next child on a shared family device finds someone
      // else's adventures already finished and unlocked.
      expect(store.kidsZoneCompletedStops, isEmpty);
      expect(store.kidsZoneStars, isEmpty);
      expect(store.kidsZoneStarsFor('garden_1'), 0);
      expect(store.isKidsZoneTutorialSeen('ark_animal_care'), isFalse);
      expect(store.currentLevel, 1);
    });

    test('leaves the install id alone', () async {
      final String before = store.installId();

      await store.markKidsZoneStopComplete('garden_1', stars: 3);
      await store.clearAccountScopedState();

      // Not personal data and not account-scoped: regenerating it on every
      // sign-out would break the abuse controls it exists for.
      expect(store.installId(), before);
    });
  });
}
