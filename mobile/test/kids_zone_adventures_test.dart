import 'package:anointed/features/kids_zone/games/animal_matching_game.dart';
import 'package:anointed/features/kids_zone/kids_zone_adventures.dart';
import 'package:anointed/features/kids_zone/kids_zone_game_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Kids Zone adventure catalog', () {
    test('every stop has a playable game definition', () {
      for (final KidsAdventure adventure in kKidsAdventures) {
        for (final KidsAdventureStop stop in adventure.stops) {
          final KidsZoneGameDefinition? game = kidsZoneGameForStop(stop.id);
          expect(game, isNotNull, reason: 'no game for ${stop.id}');
          expect(game!.kind, stop.gameKind, reason: 'kind mismatch on ${stop.id}');
        }
      }
    });

    test('stop ids are unique across adventures', () {
      final List<String> ids = <String>[
        for (final KidsAdventure a in kKidsAdventures)
          for (final KidsAdventureStop s in a.stops) s.id,
      ];
      expect(ids.toSet().length, ids.length);
    });
  });

  group('Battle of Siddim', () {
    KidsAdventure siddim() => kidsZoneAdventureById('battle_of_siddim')!;

    test('is the second adventure, after Creation Garden', () {
      expect(kKidsAdventures[0].id, 'creation_garden');
      expect(kKidsAdventures[1].id, 'battle_of_siddim');
    });

    test('opens with a narrated intro then three archery levels', () {
      expect(siddim().stops.map((KidsAdventureStop s) => s.gameKind).toList(), <
          KidsZoneGameKind>[
        KidsZoneGameKind.battleIntro,
        KidsZoneGameKind.archery,
        KidsZoneGameKind.archery,
        KidsZoneGameKind.archery,
      ]);
    });

    test('archery levels cover rounds 1 through 6 in order', () {
      final List<int> rounds = <int>[
        for (final KidsAdventureStop stop in siddim().stops)
          ...?kidsZoneGameForStop(stop.id)
              ?.archeryWaves
              .map((ArcheryWave w) => w.round),
      ];
      expect(rounds, <int>[1, 2, 3, 4, 5, 6]);
    });

    test('rounds escalate in speed and shrink the hitbox', () {
      final List<ArcheryWave> waves = <ArcheryWave>[
        for (final KidsAdventureStop stop in siddim().stops)
          ...?kidsZoneGameForStop(stop.id)?.archeryWaves,
      ];
      for (int i = 1; i < waves.length; i++) {
        expect(waves[i].speed, greaterThan(waves[i - 1].speed),
            reason: 'round ${waves[i].round} is not faster');
        expect(waves[i].hitRadius, lessThan(waves[i - 1].hitRadius),
            reason: 'round ${waves[i].round} is not tighter');
      }
    });

    test('only the final round is the King\'s Round', () {
      final List<ArcheryWave> waves = <ArcheryWave>[
        for (final KidsAdventureStop stop in siddim().stops)
          ...?kidsZoneGameForStop(stop.id)?.archeryWaves,
      ];
      expect(waves.where((ArcheryWave w) => w.isKingRound).length, 1);
      expect(waves.last.isKingRound, isTrue);
      expect(waves.last.hitsToTurnBack, greaterThan(1));
    });

    test('every Siddim intro scene has narration a screen reader can speak', () {
      final KidsZoneGameDefinition intro =
          kidsZoneGameForStop('siddim_intro')!;
      expect(intro.battleScenes, isNotEmpty);
      for (final BattleIntroScene scene in intro.battleScenes) {
        expect(scene.sceneLabel, isNotEmpty);
        expect(scene.narration.length, greaterThan(20));
      }
    });
  });

  group('Noah\'s Ark', () {
    KidsAdventure ark() => kidsZoneAdventureById('noahs_ark')!;

    test('is the third adventure', () {
      expect(kKidsAdventures[2].id, 'noahs_ark');
    });

    test('opens with a narrated intro then the three brief levels', () {
      expect(
        ark().stops.map((KidsAdventureStop s) => s.gameKind).toList(),
        <KidsZoneGameKind>[
          KidsZoneGameKind.noahIntro,
          KidsZoneGameKind.arkBuilder,
          KidsZoneGameKind.animalMatching,
          KidsZoneGameKind.animalCare,
        ],
      );
    });

    test('every intro scene has narration a screen reader can speak', () {
      final KidsZoneGameDefinition intro = kidsZoneGameForStop('ark_intro')!;
      expect(intro.arkScenes, isNotEmpty);
      for (final ArkIntroScene scene in intro.arkScenes) {
        expect(scene.sceneLabel, isNotEmpty);
        expect(scene.narration.length, greaterThan(20));
      }
    });

    test('build stages grow in piece count and every piece fits on screen', () {
      final List<ArkBuildStage> stages =
          kidsZoneGameForStop('ark_1')!.arkStages;
      expect(stages.length, 4);
      for (int i = 1; i < stages.length; i++) {
        expect(
          stages[i].pieces.length,
          greaterThanOrEqualTo(stages[i - 1].pieces.length),
          reason: 'stage ${stages[i].stage} should not shrink',
        );
      }
      for (final ArkBuildStage stage in stages) {
        for (final ArkPiece piece in stage.pieces) {
          expect(piece.targetLeft, inInclusiveRange(0.0, 1.0));
          expect(piece.targetTop, inInclusiveRange(0.0, 1.0));
          // A piece centred at its target must not overflow the build area.
          expect(piece.targetLeft - piece.width / 2, greaterThanOrEqualTo(-0.01));
          expect(piece.targetLeft + piece.width / 2, lessThanOrEqualTo(1.01));
        }
      }
    });

    test('piece ids are unique so placement cannot collide', () {
      final List<String> ids = <String>[
        for (final ArkBuildStage stage in kidsZoneGameForStop('ark_1')!.arkStages)
          for (final ArkPiece piece in stage.pieces) piece.id,
      ];
      expect(ids.toSet().length, ids.length);
    });

    test('the dealt board fills whole rows and fits one screen', () {
      final List<ArkAnimalPair> animals =
          kidsZoneGameForStop('ark_2')!.arkAnimals;

      // The catalogue is deliberately larger than one game, so replays vary.
      expect(animals.length, greaterThan(kArkPairsPerGame));
      expect(
        animals.map((ArkAnimalPair a) => a.id).toSet().length,
        animals.length,
      );

      // Cards dealt must fill complete rows — no ragged last row.
      const int cards = kArkPairsPerGame * 2;
      expect(cards % kArkGridColumns, 0);
      // Four rows keeps the board on screen without scrolling.
      expect(cards ~/ kArkGridColumns, 4);
    });

    test('every animal card shows a distinct picture, not a placeholder', () {
      final List<ArkAnimalPair> animals =
          kidsZoneGameForStop('ark_2')!.arkAnimals;
      for (final ArkAnimalPair animal in animals) {
        expect(animal.emoji, isNotEmpty, reason: '${animal.label} has no art');
        // A bare ASCII string would mean a glyph slipped in instead of emoji.
        expect(
          animal.emoji.runes.first,
          greaterThan(0x7F),
          reason: '${animal.label} should render as a picture',
        );
      }
      // Two cards of the same animal must be tellable apart from other pairs.
      expect(
        animals.map((ArkAnimalPair a) => a.emoji).toSet().length,
        animals.length,
        reason: 'each animal needs its own picture',
      );
    });

    test('care stalls show pictures too', () {
      for (final ArkCareRound round
          in kidsZoneGameForStop('ark_3')!.arkCareRounds) {
        for (final ArkStall stall in round.stalls) {
          expect(stall.emoji, isNotEmpty);
          expect(stall.emoji.runes.first, greaterThan(0x7F));
        }
      }
    });

    test('care rounds escalate in animals, tasks and urgency', () {
      final List<ArkCareRound> rounds =
          kidsZoneGameForStop('ark_3')!.arkCareRounds;
      expect(rounds.length, 3);
      for (int i = 1; i < rounds.length; i++) {
        expect(rounds[i].stalls.length,
            greaterThanOrEqualTo(rounds[i - 1].stalls.length));
        expect(rounds[i].tasksToComplete,
            greaterThan(rounds[i - 1].tasksToComplete));
        expect(rounds[i].spawnInterval, lessThan(rounds[i - 1].spawnInterval));
        expect(
            rounds[i].patienceSeconds, lessThan(rounds[i - 1].patienceSeconds));
      }
    });

    test('a round never demands more tasks than it can spawn needs for', () {
      for (final ArkCareRound round in kidsZoneGameForStop('ark_3')!.arkCareRounds) {
        expect(round.stalls, isNotEmpty);
        expect(round.tasksToComplete, greaterThan(0));
        expect(round.stalls.map((ArkStall s) => s.id).toSet().length,
            round.stalls.length);
      }
    });
  });
}
