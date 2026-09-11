// Kids Zone progress used to live only in SharedPreferences, and
// `clearAccountScopedState()` wipes those on sign-out — so the stars a child
// earned were destroyed rather than restored on the next sign-in. These tests
// cover the device half of the fix: that a sync writes the merged result back,
// that a failed one leaves local progress alone, and above all that signing out
// flushes before the wipe.
import 'dart:convert';

import 'package:anointed/core/api_client.dart';
import 'package:anointed/core/device_context.dart';
import 'package:anointed/core/connectivity.dart';
import 'package:anointed/core/local_store.dart';
import 'package:anointed/features/kids_zone/kids_zone_adventures.dart';
import 'package:anointed/services/account_repository.dart';
import 'package:anointed/services/analytics_service.dart';
import 'package:anointed/services/auth_repository.dart';
import 'package:anointed/services/kids_zone_repository.dart';
import 'package:anointed/services/oauth_provider_service.dart';
import 'package:anointed/state/session_controller.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStore store;
  late List<Map<String, dynamic>> sentPayloads;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    store = LocalStore(
      await SharedPreferences.getInstance(),
      const FlutterSecureStorage(),
    );
    sentPayloads = <Map<String, dynamic>>[];
  });

  KidsZoneRepository repositoryReturning(
    List<Map<String, Object?>> stops, {
    int status = 200,
  }) {
    final MockClient http_ = MockClient((http.Request request) async {
      sentPayloads.add(jsonDecode(request.body) as Map<String, dynamic>);
      if (status != 200) {
        return http.Response('{"code":"offline","message":"no"}', status);
      }
      return http.Response(
        jsonEncode(<String, Object?>{'stops': stops}),
        200,
        headers: <String, String>{'content-type': 'application/json'},
      );
    });

    return KidsZoneRepository(
      ApiClient(
        deviceContext: DeviceContext.forTest(),
        httpClient: http_,
        baseUrl: 'https://test.invalid',
      ),
      store,
    );
  }

  Map<String, Object?> row(String stopId, String adventureId, int stars) {
    return <String, Object?>{
      'stop_id': stopId,
      'adventure_id': adventureId,
      'stars': stars,
      'last_completed_at': '2026-09-11T00:00:00Z',
    };
  }

  group('catalogue lookup', () {
    test('every stop resolves to the adventure that contains it', () {
      // The sync payload needs an adventure id per stop, and it is derived
      // rather than stored. A stop the lookup cannot place is silently dropped
      // from the payload, so a gap here would lose progress quietly.
      for (final KidsAdventure adventure in kKidsAdventures) {
        for (final KidsAdventureStop stop in adventure.stops) {
          expect(kidsZoneAdventureForStop(stop.id)?.id, adventure.id,
              reason: '${stop.id} did not resolve back to ${adventure.id}');
        }
      }
    });

    test('an unknown stop id resolves to null rather than guessing', () {
      expect(kidsZoneAdventureForStop('not_a_stop'), isNull);
    });
  });

  group('sync', () {
    test('sends local progress with the adventure id filled in', () async {
      await store.markKidsZoneStopComplete('garden_1', stars: 2);

      await repositoryReturning(<Map<String, Object?>>[
        row('garden_1', 'creation_garden', 2),
      ]).sync();

      expect(sentPayloads, hasLength(1));
      final List<dynamic> stops = sentPayloads.single['stops'] as List<dynamic>;
      expect(stops.single, <String, Object?>{
        'stop_id': 'garden_1',
        'adventure_id': kidsZoneAdventureForStop('garden_1')!.id,
        'stars': 2,
      });
    });

    test('writes the merged result back to the device', () async {
      // The restore case: nothing local, the server still has the stars.
      expect(store.kidsZoneCompletedStops, isEmpty);

      final Map<String, int>? merged = await repositoryReturning(
        <Map<String, Object?>>[
          row('garden_1', 'creation_garden', 3),
          row('siddim_1', 'battle_of_siddim', 1),
        ],
      ).sync();

      expect(merged, <String, int>{'garden_1': 3, 'siddim_1': 1});
      expect(store.kidsZoneCompletedStops,
          <String>{'garden_1', 'siddim_1'});
      expect(store.kidsZoneStarsFor('garden_1'), 3);
      expect(store.kidsZoneStarsFor('siddim_1'), 1);
    });

    test('a failed sync returns null and leaves local progress playable',
        () async {
      await store.markKidsZoneStopComplete('garden_1', stars: 2);

      final Map<String, int>? merged =
          await repositoryReturning(<Map<String, Object?>>[], status: 503)
              .sync();

      expect(merged, isNull);
      // Kids Zone is the part most likely to be played offline; a network
      // failure must never cost a child the stars already on the device.
      expect(store.kidsZoneStarsFor('garden_1'), 2);
      expect(store.isKidsZoneStopComplete('garden_1'), isTrue);
    });

    test('drops a stop the catalogue no longer contains', () async {
      await store.markKidsZoneStopComplete('retired_stop', stars: 3);
      await store.markKidsZoneStopComplete('garden_1', stars: 1);

      await repositoryReturning(<Map<String, Object?>>[
        row('garden_1', 'creation_garden', 1),
      ]).sync();

      final List<dynamic> stops = sentPayloads.single['stops'] as List<dynamic>;
      final Set<String> sentIds = <String>{
        for (final dynamic s in stops) (s as Map<String, dynamic>)['stop_id'] as String,
      };
      // Better to drop it than to invent an adventure id the server would then
      // store indefinitely.
      expect(sentIds, <String>{'garden_1'});
    });
  });

  group('sign-out', () {
    test('flushes progress before clearAccountScopedState wipes it', () async {
      // The ordering in SessionController.signOut is the whole guard. Local
      // stars are the only copy until a sync lands, so a sign-out that wiped
      // first and uploaded after would upload nothing — which is exactly the
      // data loss this feature was added to stop.
      await store.markKidsZoneStopComplete('garden_1', stars: 3);

      final _RecordingKidsZone kidsZone = _RecordingKidsZone(store);
      final ApiClient api = ApiClient(
        deviceContext: DeviceContext.forTest(),
        httpClient: MockClient(
          (http.Request request) async => http.Response('{}', 200),
        ),
        baseUrl: 'https://test.invalid',
      );
      final SessionController session = SessionController(
        api: api,
        auth: AuthRepository(api),
        account: AccountRepository(api, store),
        store: store,
        analytics: AnalyticsService(
          api: api,
          store: store,
          connectivity: ConnectivityService(),
        ),
        oauth: OAuthProviderService(store),
        kidsZone: kidsZone,
      );

      await session.signOut();

      expect(kidsZone.sawStopsAtSyncTime, <String>{'garden_1'},
          reason: 'sync() ran after the local wipe, so it had nothing to send');
      expect(store.kidsZoneCompletedStops, isEmpty,
          reason: 'the wipe itself must still happen');
    });
  });

  group('applyKidsZoneProgress', () {
    test('replaces rather than unions, because the caller merged already',
        () async {
      await store.markKidsZoneStopComplete('retired_stop', stars: 3);

      await store.applyKidsZoneProgress(<String, int>{'garden_1': 2});

      expect(store.kidsZoneCompletedStops, <String>{'garden_1'});
      expect(store.kidsZoneStarsFor('retired_stop'), 0);
    });
  });
}

/// Captures what was still on the device at the moment [sync] was called, which
/// is the only way to tell a flush-then-wipe from a wipe-then-flush.
class _RecordingKidsZone extends KidsZoneRepository {
  _RecordingKidsZone(this._store) : super(_unusedApi, _store);

  static final ApiClient _unusedApi =
      ApiClient(deviceContext: DeviceContext.forTest());

  final LocalStore _store;
  Set<String> sawStopsAtSyncTime = <String>{};

  @override
  Future<Map<String, int>?> sync() async {
    sawStopsAtSyncTime = _store.kidsZoneCompletedStops;
    return null;
  }
}
