import 'package:flutter/material.dart';

/// Which joyful animation plays after a correct Level 1 answer.
enum CreationCelebration {
  light,
  stars,
  plants,
  water,
  animals,
  people,
  rest,
  rainbow,
}

/// Genesis intro + level content models.
class CreationDayIntro {
  const CreationDayIntro({
    required this.day,
    required this.dayLabel,
    required this.narration,
  });

  /// 0 for "Before Day One", then 1–7.
  ///
  /// The scene paints itself from this: everything made on a given day appears
  /// that day and remains for the rest of the week.
  final int day;

  final String dayLabel;
  final String narration;
}

class ListeningQuestion {
  const ListeningQuestion({
    required this.prompt,
    required this.correctAnswer,
    required this.distractors,
    this.celebration = CreationCelebration.light,
  });

  final String prompt;
  final String correctAnswer;

  /// Wrong answers, **ordered most-confusable first**.
  ///
  /// Level 1 narrows the choices as it goes (see [kGenesisLevel1OptionRamp]),
  /// and trims from the end of this list. Keeping the closest near-miss for the
  /// final two-option questions is what makes the ramp harder rather than
  /// easier — otherwise fewer buttons would just mean a better guess.
  final List<String> distractors;

  final CreationCelebration celebration;

  /// Every option this question can show, correct answer first.
  List<String> get allOptions => <String>[correctAnswer, ...distractors];
}

/// How many answer buttons each Level 1 question shows, by position.
///
/// Four choices while the child finds their feet, then three, then a stark
/// two-way decision for the last pair. Fewer buttons makes each tap feel more
/// committing, so tension builds without ever putting a clock on a young player.
const List<int> kGenesisLevel1OptionRamp = <int>[4, 4, 4, 3, 3, 3, 2, 2];

class DayCreationPair {
  const DayCreationPair({
    required this.dayId,
    required this.dayLabel,
    required this.creationLabel,
    required this.icon,
    required this.color,
  });

  final String dayId;
  final String dayLabel;
  final String creationLabel;
  final IconData icon;
  final Color color;
}

class JumbledSentence {
  const JumbledSentence({
    required this.id,
    required this.words,
    required this.hint,
  });

  final String id;
  final List<String> words;
  final String hint;
}

/// Introduction — day-by-day narration with building visuals.
const List<CreationDayIntro> kGenesisIntroDays = <CreationDayIntro>[
  CreationDayIntro(
    day: 0,
    dayLabel: 'Before Day One',
    narration:
        'In the beginning, God made the heavens and the earth. '
        'Everything was dark and quiet. Then God began to create!',
  ),
  CreationDayIntro(
    day: 1,
    dayLabel: 'Day 1',
    narration:
        'On the first day, God said, "Let there be light!" '
        'Light shone into the darkness. God called the light Day and the darkness Night.',
  ),
  CreationDayIntro(
    day: 2,
    dayLabel: 'Day 2',
    narration:
        'On the second day, God made the sky and separated the waters above from the waters below.',
  ),
  CreationDayIntro(
    day: 3,
    dayLabel: 'Day 3',
    narration:
        'On the third day, dry land appeared and plants, flowers, and trees covered the earth.',
  ),
  CreationDayIntro(
    day: 4,
    dayLabel: 'Day 4',
    narration:
        'On the fourth day, God made the sun, moon, and stars to give light to the earth.',
  ),
  CreationDayIntro(
    day: 5,
    dayLabel: 'Day 5',
    narration: 'On the fifth day, God filled the seas with fish and the sky with birds.',
  ),
  CreationDayIntro(
    day: 6,
    dayLabel: 'Day 6',
    narration:
        'On the sixth day, God made land animals and the first person, Adam, in His image.',
  ),
  CreationDayIntro(
    day: 7,
    dayLabel: 'Day 7',
    narration:
        'On the seventh day, God rested. He looked at everything He had made and saw that it was very good!',
  ),
];

/// Level 1 — questions after the intro narration.
///
/// Eight questions walking the creation week in order, so the choice ramp in
/// [kGenesisLevel1OptionRamp] lines up with the story rather than cutting
/// across it. Distractors are listed most-confusable first.
const List<ListeningQuestion> kGenesisLevel1Questions = <ListeningQuestion>[
  ListeningQuestion(
    prompt: 'What did God create on Day 1?',
    correctAnswer: 'Light',
    distractors: <String>['The sun', 'The stars', 'Trees'],
    celebration: CreationCelebration.light,
  ),
  ListeningQuestion(
    prompt: 'What did God make on Day 2?',
    correctAnswer: 'The sky',
    distractors: <String>['The clouds', 'The sea', 'Fish'],
    celebration: CreationCelebration.water,
  ),
  ListeningQuestion(
    prompt: 'What covered the land on Day 3?',
    correctAnswer: 'Plants and trees',
    distractors: <String>['Animals', 'Birds', 'Stars'],
    celebration: CreationCelebration.plants,
  ),
  ListeningQuestion(
    prompt: 'What did God put in the sky on Day 4?',
    correctAnswer: 'The sun, moon and stars',
    distractors: <String>['Clouds and rain', 'Birds', 'Fish'],
    celebration: CreationCelebration.stars,
  ),
  ListeningQuestion(
    prompt: 'What did God create on Day 5?',
    correctAnswer: 'Fish and birds',
    distractors: <String>['Lions and tigers', 'Trees and flowers', 'The moon'],
    celebration: CreationCelebration.water,
  ),
  ListeningQuestion(
    prompt: 'Who did God make on Day 6, along with the animals?',
    correctAnswer: 'Adam',
    distractors: <String>['Noah', 'Moses', 'David'],
    celebration: CreationCelebration.people,
  ),
  ListeningQuestion(
    prompt: 'What did God do on Day 7?',
    correctAnswer: 'He rested',
    distractors: <String>['He kept working', 'He made the moon', 'He planted a garden'],
    celebration: CreationCelebration.rest,
  ),
  ListeningQuestion(
    prompt: 'When God looked at everything He had made, what did He say?',
    correctAnswer: 'It was very good',
    distractors: <String>['It was all finished', 'It was too dark', 'It was very noisy'],
    celebration: CreationCelebration.rainbow,
  ),
];


/// Level 2 — match each day to its creation.
/// Colours double as the wire colour on the board, so each day's line reads as
/// the thing it made: light yellow for Day 1, sun orange for Day 4, sea teal
/// for Day 5. A finished board is then a colour summary of the whole week.
const List<DayCreationPair> kGenesisDayCreations = <DayCreationPair>[
  DayCreationPair(
    dayId: 'day1',
    dayLabel: 'Day 1',
    creationLabel: 'Light',
    icon: Icons.wb_sunny_rounded,
    color: Color(0xFFFFD54F),
  ),
  DayCreationPair(
    dayId: 'day2',
    dayLabel: 'Day 2',
    creationLabel: 'Sky',
    icon: Icons.cloud_rounded,
    color: Color(0xFF64B5F6),
  ),
  DayCreationPair(
    dayId: 'day3',
    dayLabel: 'Day 3',
    creationLabel: 'Plants',
    icon: Icons.park_rounded,
    color: Color(0xFF66BB6A),
  ),
  DayCreationPair(
    dayId: 'day4',
    dayLabel: 'Day 4',
    creationLabel: 'Sun, moon & stars',
    icon: Icons.wb_twilight_rounded,
    color: Color(0xFFFFA726),
  ),
  DayCreationPair(
    dayId: 'day5',
    dayLabel: 'Day 5',
    creationLabel: 'Fish & birds',
    icon: Icons.water_rounded,
    color: Color(0xFF26C6DA),
  ),
  DayCreationPair(
    dayId: 'day6',
    dayLabel: 'Day 6',
    creationLabel: 'Animals & people',
    icon: Icons.pets_rounded,
    color: Color(0xFF8D6E63),
  ),
  DayCreationPair(
    dayId: 'day7',
    dayLabel: 'Day 7',
    creationLabel: 'Rest',
    icon: Icons.favorite_rounded,
    color: Color(0xFF9575CD),
  ),
];

/// Things that belong to no day of the creation week.
///
/// Mixed into the right-hand column so the level asks a judgment — *was this
/// part of creation?* — rather than only testing recall of a fixed list of
/// seven. Their ids deliberately match no day, so wiring one up is always
/// wrong.
const List<DayCreationPair> kGenesisCreationDistractors = <DayCreationPair>[
  DayCreationPair(
    dayId: 'not_created_cars',
    dayLabel: '',
    creationLabel: 'Cars',
    icon: Icons.directions_car_rounded,
    color: Color(0xFF78909C),
  ),
  DayCreationPair(
    dayId: 'not_created_buildings',
    dayLabel: '',
    creationLabel: 'Buildings',
    icon: Icons.apartment_rounded,
    color: Color(0xFF90A4AE),
  ),
  DayCreationPair(
    dayId: 'not_created_planes',
    dayLabel: '',
    creationLabel: 'Aeroplanes',
    icon: Icons.flight_rounded,
    color: Color(0xFFB0BEC5),
  ),
];


/// Level 3 — unscramble creation sentences.
const List<JumbledSentence> kGenesisJumbledSentences = <JumbledSentence>[
  JumbledSentence(
    id: 'j1',
    hint: 'Day 1',
    words: <String>['God', 'created', 'light', 'on', 'Day', '1'],
  ),
  JumbledSentence(
    id: 'j2',
    hint: 'Day 3',
    words: <String>['Plants', 'grew', 'on', 'the', 'land', 'on', 'Day', '3'],
  ),
  JumbledSentence(
    id: 'j3',
    hint: 'Day 5',
    words: <String>['God', 'made', 'fish', 'and', 'birds', 'on', 'Day', '5'],
  ),
  JumbledSentence(
    id: 'j4',
    hint: 'Day 6',
    words: <String>['God', 'created', 'animals', 'on', 'Day', '6'],
  ),
];

/// Legacy listen-and-answer story parts (unused when intro + quiz flow is active).
const List<StoryListenPart> kGenesisCreationStory = <StoryListenPart>[];

const List<ListeningQuestion> kGenesisCreationQuestions = kGenesisLevel1Questions;

class StoryListenPart {
  const StoryListenPart({
    required this.title,
    required this.text,
    required this.icon,
    required this.color,
  });

  final String title;
  final String text;
  final IconData icon;
  final Color color;
}
