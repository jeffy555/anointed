"""Curated Bible content for the dev/QA seed script (build order A.3).

This is a development and QA fixture, not the launch content set. The launch target
is ~300 characters and 2,000 authored questions produced through the admin dashboard
(Track A in feature-plan.md); this file exists so gameplay, the practice pack, and
the leaderboard can be exercised end to end before that authoring finishes.

Facts and verse excerpts below are well-known passages. Content is still routed
through the same draft/in-review/approved gate as authored content.
"""

from __future__ import annotations

from typing import TypedDict


class VerseClue(TypedDict):
    reference: str
    excerpt: str


class CharacterSeed(TypedDict):
    name: str
    testament: str
    era_tags: list[str]
    description: str
    facts: list[str]
    verses: list[VerseClue]


# Each entry supplies: identifying facts (become text_qa prompts) and verse excerpts
# (become verse_clue prompts). Distractor options are drawn from other characters in
# the same testament so wrong answers stay plausible.
CHARACTERS: list[CharacterSeed] = [
    {
        "name": "Adam",
        "testament": "old",
        "era_tags": ["creation"],
        "description": "The first man, formed from the dust of the ground.",
        "facts": [
            "Who was the first man God created?",
            "Who named all the animals in the garden of Eden?",
        ],
        "verses": [],
    },
    {
        "name": "Eve",
        "testament": "old",
        "era_tags": ["creation"],
        "description": "The first woman, called the mother of all living.",
        "facts": [
            "Who was called the mother of all the living?",
            "Which woman was tempted by the serpent in the garden?",
        ],
        "verses": [],
    },
    {
        "name": "Noah",
        "testament": "old",
        "era_tags": ["creation", "patriarchs"],
        "description": "Built the ark and survived the flood with his family.",
        "facts": [
            "Who built an ark to survive the great flood?",
            "Who sent out a dove to see if the flood waters had gone down?",
        ],
        "verses": [
            {
                "reference": "Genesis 6:22",
                "excerpt": "He did everything just as God commanded him.",
            }
        ],
    },
    {
        "name": "Abraham",
        "testament": "old",
        "era_tags": ["patriarchs"],
        "description": "Called by God to leave his country; father of many nations.",
        "facts": [
            "Who was told his descendants would be as many as the stars?",
            "Which man was asked to leave his country and go to a land God would show him?",
        ],
        "verses": [
            {
                "reference": "Genesis 12:1",
                "excerpt": "Go from your country, your people and your father's household "
                "to the land I will show you.",
            }
        ],
    },
    {
        "name": "Sarah",
        "testament": "old",
        "era_tags": ["patriarchs"],
        "description": "Wife of Abraham; laughed when told she would have a son in old age.",
        "facts": [
            "Which woman laughed when she heard she would have a son in her old age?",
            "Who was the mother of Isaac?",
        ],
        "verses": [],
    },
    {
        "name": "Isaac",
        "testament": "old",
        "era_tags": ["patriarchs"],
        "description": "The son of promise, born to Abraham and Sarah.",
        "facts": [
            "Whose name means laughter?",
            "Who was the son Abraham was asked to offer on Mount Moriah?",
        ],
        "verses": [],
    },
    {
        "name": "Jacob",
        "testament": "old",
        "era_tags": ["patriarchs"],
        "description": "Renamed Israel; father of the twelve tribes.",
        "facts": [
            "Who wrestled with God and was renamed Israel?",
            "Who dreamed of a ladder reaching to heaven?",
        ],
        "verses": [
            {
                "reference": "Genesis 32:28",
                "excerpt": "Your name will no longer be Jacob, but Israel, because you "
                "have struggled with God and with humans and have overcome.",
            }
        ],
    },
    {
        "name": "Joseph",
        "testament": "old",
        "era_tags": ["patriarchs"],
        "description": "Sold into Egypt by his brothers; rose to govern the land.",
        "facts": [
            "Who was given a richly ornamented coat by his father?",
            "Who interpreted Pharaoh's dream about seven years of plenty and famine?",
        ],
        "verses": [
            {
                "reference": "Genesis 50:20",
                "excerpt": "You intended to harm me, but God intended it for good to "
                "accomplish what is now being done, the saving of many lives.",
            }
        ],
    },
    {
        "name": "Moses",
        "testament": "old",
        "era_tags": ["exodus"],
        "description": "Led Israel out of Egypt and received the Law at Sinai.",
        "facts": [
            "Who led the Israelites out of Egypt?",
            "Who saw a bush that burned but was not consumed?",
            "Who received the Ten Commandments on Mount Sinai?",
        ],
        "verses": [
            {
                "reference": "Exodus 3:14",
                "excerpt": "God said to him, \u201cI AM WHO I AM. This is what you are to "
                "say to the Israelites: I AM has sent me to you.\u201d",
            }
        ],
    },
    {
        "name": "Aaron",
        "testament": "old",
        "era_tags": ["exodus"],
        "description": "Brother of Moses and the first high priest of Israel.",
        "facts": [
            "Who was the brother of Moses and Israel's first high priest?",
            "Whose staff budded and produced almonds?",
        ],
        "verses": [],
    },
    {
        "name": "Miriam",
        "testament": "old",
        "era_tags": ["exodus"],
        "description": "Sister of Moses; led Israel in song after crossing the sea.",
        "facts": [
            "Which sister watched over baby Moses in the reeds of the Nile?",
            "Who led the women with tambourines after Israel crossed the sea?",
        ],
        "verses": [],
    },
    {
        "name": "Joshua",
        "testament": "old",
        "era_tags": ["conquest"],
        "description": "Succeeded Moses and led Israel into the promised land.",
        "facts": [
            "Who led Israel into the promised land after Moses died?",
            "Around whose walls did Israel march for seven days at Jericho?",
        ],
        "verses": [
            {
                "reference": "Joshua 1:9",
                "excerpt": "Be strong and courageous. Do not be afraid; do not be "
                "discouraged, for the LORD your God will be with you wherever you go.",
            }
        ],
    },
    {
        "name": "Rahab",
        "testament": "old",
        "era_tags": ["conquest"],
        "description": "Hid the Israelite spies in Jericho and was spared.",
        "facts": [
            "Who hid the Israelite spies and hung a scarlet cord from her window?",
        ],
        "verses": [],
    },
    {
        "name": "Deborah",
        "testament": "old",
        "era_tags": ["judges"],
        "description": "A prophet who judged Israel and went to battle with Barak.",
        "facts": [
            "Which prophet judged Israel while sitting under a palm tree?",
            "Which woman went into battle alongside Barak?",
        ],
        "verses": [],
    },
    {
        "name": "Gideon",
        "testament": "old",
        "era_tags": ["judges"],
        "description": "Defeated the Midianites with three hundred men.",
        "facts": [
            "Who tested God using a wool fleece and the morning dew?",
            "Who defeated the Midianites with only three hundred men?",
        ],
        "verses": [],
    },
    {
        "name": "Samson",
        "testament": "old",
        "era_tags": ["judges"],
        "description": "A Nazirite judge whose great strength was tied to his hair.",
        "facts": [
            "Whose strength was connected to his uncut hair?",
            "Who tore down the pillars of the Philistine temple?",
        ],
        "verses": [],
    },
    {
        "name": "Ruth",
        "testament": "old",
        "era_tags": ["judges"],
        "description": "A Moabite woman who stayed loyal to Naomi and married Boaz.",
        "facts": [
            "Which Moabite woman refused to leave her mother-in-law Naomi?",
            "Who gleaned grain in the fields of Boaz?",
        ],
        "verses": [
            {
                "reference": "Ruth 1:16",
                "excerpt": "Where you go I will go, and where you stay I will stay. "
                "Your people will be my people and your God my God.",
            }
        ],
    },
    {
        "name": "Samuel",
        "testament": "old",
        "era_tags": ["judges", "monarchy"],
        "description": "Prophet who anointed Israel's first two kings.",
        "facts": [
            "Which boy heard God call his name while serving in the temple?",
            "Which prophet anointed both Saul and David as king?",
        ],
        "verses": [
            {
                "reference": "1 Samuel 3:10",
                "excerpt": "Speak, for your servant is listening.",
            }
        ],
    },
    {
        "name": "Saul",
        "testament": "old",
        "era_tags": ["monarchy"],
        "description": "The first king of Israel.",
        "facts": [
            "Who was the first king of Israel?",
            "Which king was searching for lost donkeys when he met Samuel?",
        ],
        "verses": [],
    },
    {
        "name": "David",
        "testament": "old",
        "era_tags": ["monarchy"],
        "description": "Shepherd, psalmist, and king of Israel.",
        "facts": [
            "Which shepherd boy defeated Goliath with a sling and a stone?",
            "Who wrote many of the psalms and became king after Saul?",
        ],
        "verses": [
            {
                "reference": "Psalm 23:1",
                "excerpt": "The LORD is my shepherd, I lack nothing.",
            }
        ],
    },
    {
        "name": "Goliath",
        "testament": "old",
        "era_tags": ["monarchy"],
        "description": "The Philistine champion from Gath.",
        "facts": [
            "Which Philistine giant challenged the armies of Israel for forty days?",
        ],
        "verses": [],
    },
    {
        "name": "Solomon",
        "testament": "old",
        "era_tags": ["monarchy"],
        "description": "Son of David; asked God for wisdom and built the temple.",
        "facts": [
            "Which king asked God for wisdom instead of riches?",
            "Who built the first temple in Jerusalem?",
        ],
        "verses": [
            {
                "reference": "Proverbs 3:5",
                "excerpt": "Trust in the LORD with all your heart and lean not on your "
                "own understanding.",
            }
        ],
    },
    {
        "name": "Elijah",
        "testament": "old",
        "era_tags": ["prophets"],
        "description": "Prophet who confronted the prophets of Baal on Mount Carmel.",
        "facts": [
            "Which prophet called down fire on Mount Carmel?",
            "Who was taken up to heaven in a whirlwind with a chariot of fire?",
            "Which prophet was fed by ravens beside a brook?",
        ],
        "verses": [],
    },
    {
        "name": "Elisha",
        "testament": "old",
        "era_tags": ["prophets"],
        "description": "Successor of Elijah who received a double portion of his spirit.",
        "facts": [
            "Who received Elijah's cloak and a double portion of his spirit?",
            "Which prophet told Naaman to wash seven times in the Jordan?",
        ],
        "verses": [],
    },
    {
        "name": "Isaiah",
        "testament": "old",
        "era_tags": ["prophets"],
        "description": "Prophet who saw the Lord high and exalted in the temple.",
        "facts": [
            "Which prophet saw the Lord seated on a throne, high and exalted?",
            "Who answered God's call by saying, \u201cHere am I. Send me!\u201d",
        ],
        "verses": [
            {
                "reference": "Isaiah 6:8",
                "excerpt": "Then I heard the voice of the Lord saying, \u201cWhom shall I "
                "send? And who will go for us?\u201d And I said, \u201cHere am I. Send me!\u201d",
            }
        ],
    },
    {
        "name": "Jeremiah",
        "testament": "old",
        "era_tags": ["prophets"],
        "description": "Called as a prophet while still young; often called the weeping prophet.",
        "facts": [
            "Which prophet said he was too young when God called him?",
            "Which prophet is often called the weeping prophet?",
        ],
        "verses": [
            {
                "reference": "Jeremiah 29:11",
                "excerpt": "For I know the plans I have for you, declares the LORD, "
                "plans to prosper you and not to harm you.",
            }
        ],
    },
    {
        "name": "Daniel",
        "testament": "old",
        "era_tags": ["exile", "prophets"],
        "description": "Served in Babylon and was protected in the lions' den.",
        "facts": [
            "Who was thrown into a den of lions for praying to God?",
            "Who interpreted the writing on the wall at Belshazzar's feast?",
        ],
        "verses": [
            {
                "reference": "Daniel 6:22",
                "excerpt": "My God sent his angel, and he shut the mouths of the lions.",
            }
        ],
    },
    {
        "name": "Esther",
        "testament": "old",
        "era_tags": ["exile"],
        "description": "Queen of Persia who risked her life to save her people.",
        "facts": [
            "Which queen risked her life to save her people from Haman's plot?",
            "Who was told she had come to her royal position for such a time as this?",
        ],
        "verses": [
            {
                "reference": "Esther 4:14",
                "excerpt": "And who knows but that you have come to your royal position "
                "for such a time as this?",
            }
        ],
    },
    {
        "name": "Nehemiah",
        "testament": "old",
        "era_tags": ["exile"],
        "description": "Cupbearer to the king who rebuilt the walls of Jerusalem.",
        "facts": [
            "Who rebuilt the walls of Jerusalem in fifty-two days?",
            "Which cupbearer to the king wept over the ruined city of Jerusalem?",
        ],
        "verses": [],
    },
    {
        "name": "Jonah",
        "testament": "old",
        "era_tags": ["prophets"],
        "description": "Ran from God's call to Nineveh and was swallowed by a great fish.",
        "facts": [
            "Which prophet was swallowed by a great fish?",
            "Who ran from God's call to preach to Nineveh?",
        ],
        "verses": [
            {
                "reference": "Jonah 2:1",
                "excerpt": "From inside the fish he prayed to the LORD his God.",
            }
        ],
    },
    {
        "name": "Job",
        "testament": "old",
        "era_tags": ["wisdom"],
        "description": "A blameless man who kept his faith through great suffering.",
        "facts": [
            "Which man lost everything yet said the LORD gives and the LORD takes away?",
        ],
        "verses": [
            {
                "reference": "Job 1:21",
                "excerpt": "The LORD gave and the LORD has taken away; may the name of "
                "the LORD be praised.",
            }
        ],
    },
    {
        "name": "Mary",
        "testament": "new",
        "era_tags": ["gospels"],
        "description": "The mother of Jesus.",
        "facts": [
            "Who was told by the angel Gabriel that she would give birth to Jesus?",
            "Who was the mother of Jesus?",
        ],
        "verses": [
            {
                "reference": "Luke 1:38",
                "excerpt": "I am the Lord's servant. May your word to me be fulfilled.",
            }
        ],
    },
    {
        "name": "Joseph of Nazareth",
        "testament": "new",
        "era_tags": ["gospels"],
        "description": "A carpenter, the earthly father of Jesus.",
        "facts": [
            "Which carpenter was told in a dream to take Mary as his wife?",
            "Who was warned in a dream to flee to Egypt with the child?",
        ],
        "verses": [],
    },
    {
        "name": "John the Baptist",
        "testament": "new",
        "era_tags": ["gospels"],
        "description": "Prepared the way for Jesus and baptized him in the Jordan.",
        "facts": [
            "Who baptized Jesus in the Jordan River?",
            "Who ate locusts and wild honey in the wilderness?",
        ],
        "verses": [
            {
                "reference": "John 1:23",
                "excerpt": "I am the voice of one calling in the wilderness, "
                "\u201cMake straight the way for the Lord.\u201d",
            }
        ],
    },
    {
        "name": "Peter",
        "testament": "new",
        "era_tags": ["gospels", "apostles"],
        "description": "A fisherman called by Jesus; leader among the apostles.",
        "facts": [
            "Which disciple walked on water toward Jesus?",
            "Which disciple denied Jesus three times before the rooster crowed?",
            "Whose name means rock?",
        ],
        "verses": [
            {
                "reference": "Matthew 16:16",
                "excerpt": "You are the Messiah, the Son of the living God.",
            }
        ],
    },
    {
        "name": "Andrew",
        "testament": "new",
        "era_tags": ["apostles"],
        "description": "Brother of Peter and one of the first disciples called.",
        "facts": [
            "Which disciple was the brother of Simon Peter?",
            "Who brought the boy with five loaves and two fish to Jesus?",
        ],
        "verses": [],
    },
    {
        "name": "James",
        "testament": "new",
        "era_tags": ["apostles"],
        "description": "Son of Zebedee, brother of John, one of the inner three.",
        "facts": [
            "Which apostle was the brother of John and a son of Zebedee?",
        ],
        "verses": [],
    },
    {
        "name": "John",
        "testament": "new",
        "era_tags": ["apostles"],
        "description": "The disciple whom Jesus loved; wrote a Gospel and Revelation.",
        "facts": [
            "Which disciple is called the one whom Jesus loved?",
            "Which apostle received the vision on the island of Patmos?",
        ],
        "verses": [
            {
                "reference": "John 3:16",
                "excerpt": "For God so loved the world that he gave his one and only Son.",
            }
        ],
    },
    {
        "name": "Thomas",
        "testament": "new",
        "era_tags": ["apostles"],
        "description": "The disciple who doubted until he saw the risen Jesus.",
        "facts": [
            "Which disciple said he would not believe unless he saw the nail marks?",
        ],
        "verses": [
            {
                "reference": "John 20:28",
                "excerpt": "My Lord and my God!",
            }
        ],
    },
    {
        "name": "Matthew",
        "testament": "new",
        "era_tags": ["apostles"],
        "description": "A tax collector who left his booth to follow Jesus.",
        "facts": [
            "Which tax collector left his booth to follow Jesus?",
        ],
        "verses": [],
    },
    {
        "name": "Judas Iscariot",
        "testament": "new",
        "era_tags": ["apostles"],
        "description": "The disciple who betrayed Jesus for thirty pieces of silver.",
        "facts": [
            "Which disciple betrayed Jesus for thirty pieces of silver?",
        ],
        "verses": [],
    },
    {
        "name": "Mary Magdalene",
        "testament": "new",
        "era_tags": ["gospels"],
        "description": "A follower of Jesus and first witness of the resurrection.",
        "facts": [
            "Who was the first to see Jesus after he rose from the dead?",
            "Which woman mistook the risen Jesus for the gardener?",
        ],
        "verses": [],
    },
    {
        "name": "Martha",
        "testament": "new",
        "era_tags": ["gospels"],
        "description": "Sister of Mary and Lazarus, busy serving in her home at Bethany.",
        "facts": [
            "Which sister was worried and upset about many things while serving?",
        ],
        "verses": [],
    },
    {
        "name": "Lazarus",
        "testament": "new",
        "era_tags": ["gospels"],
        "description": "Raised from the dead by Jesus after four days in the tomb.",
        "facts": [
            "Whom did Jesus raise after four days in the tomb?",
        ],
        "verses": [],
    },
    {
        "name": "Zacchaeus",
        "testament": "new",
        "era_tags": ["gospels"],
        "description": "A short chief tax collector who climbed a tree to see Jesus.",
        "facts": [
            "Who climbed a sycamore-fig tree to see Jesus?",
            "Which chief tax collector promised to give half his possessions to the poor?",
        ],
        "verses": [],
    },
    {
        "name": "Nicodemus",
        "testament": "new",
        "era_tags": ["gospels"],
        "description": "A Pharisee who came to Jesus at night with questions.",
        "facts": [
            "Which Pharisee came to Jesus at night and was told he must be born again?",
        ],
        "verses": [],
    },
    {
        "name": "Paul",
        "testament": "new",
        "era_tags": ["apostles", "early church"],
        "description": "Formerly Saul; met Jesus on the Damascus road and wrote many letters.",
        "facts": [
            "Who was blinded by a light on the road to Damascus?",
            "Which apostle wrote letters to the Romans, Corinthians, and Philippians?",
        ],
        "verses": [
            {
                "reference": "Philippians 4:13",
                "excerpt": "I can do all this through him who gives me strength.",
            }
        ],
    },
    {
        "name": "Barnabas",
        "testament": "new",
        "era_tags": ["early church"],
        "description": "Called the son of encouragement; travelled with Paul.",
        "facts": [
            "Whose name means son of encouragement?",
            "Who travelled with Paul on his first missionary journey?",
        ],
        "verses": [],
    },
    {
        "name": "Stephen",
        "testament": "new",
        "era_tags": ["early church"],
        "description": "The first Christian martyr, full of faith and the Holy Spirit.",
        "facts": [
            "Who was the first Christian martyr?",
            "Who saw heaven open and Jesus standing at the right hand of God?",
        ],
        "verses": [],
    },
    {
        "name": "Timothy",
        "testament": "new",
        "era_tags": ["early church"],
        "description": "A young leader mentored by Paul.",
        "facts": [
            "Which young leader was told not to let anyone look down on him for his youth?",
        ],
        "verses": [
            {
                "reference": "1 Timothy 4:12",
                "excerpt": "Don't let anyone look down on you because you are young, but "
                "set an example for the believers.",
            }
        ],
    },
    {
        "name": "Lydia",
        "testament": "new",
        "era_tags": ["early church"],
        "description": "A dealer in purple cloth and the first convert in Philippi.",
        "facts": [
            "Which dealer in purple cloth opened her home to Paul in Philippi?",
        ],
        "verses": [],
    },
    {
        "name": "Cornelius",
        "testament": "new",
        "era_tags": ["early church"],
        "description": "A Roman centurion whose household received the Holy Spirit.",
        "facts": [
            "Which Roman centurion was told in a vision to send for Peter?",
        ],
        "verses": [],
    },
    {
        "name": "Philip",
        "testament": "new",
        "era_tags": ["early church"],
        "description": "An evangelist who explained the Scriptures to an Ethiopian official.",
        "facts": [
            "Who explained the book of Isaiah to an Ethiopian official in a chariot?",
        ],
        "verses": [],
    },
    {
        "name": "Caleb",
        "testament": "old",
        "era_tags": ["exodus", "conquest"],
        "description": "One of the two spies who trusted God's promise about the land.",
        "facts": [
            "Which spy, along with Joshua, brought back a good report of the land?",
        ],
        "verses": [],
    },
    {
        "name": "Hannah",
        "testament": "old",
        "era_tags": ["judges"],
        "description": "Prayed for a son and dedicated Samuel to the Lord.",
        "facts": [
            "Which woman prayed silently at the tabernacle and was thought to be drunk?",
            "Who dedicated her son Samuel to serve the Lord?",
        ],
        "verses": [],
    },
    {
        "name": "Jonathan",
        "testament": "old",
        "era_tags": ["monarchy"],
        "description": "Son of Saul and loyal friend of David.",
        "facts": [
            "Which son of Saul made a covenant of friendship with David?",
        ],
        "verses": [],
    },
    {
        "name": "Naomi",
        "testament": "old",
        "era_tags": ["judges"],
        "description": "Mother-in-law of Ruth who returned to Bethlehem.",
        "facts": [
            "Which woman asked to be called Mara because of her bitterness?",
        ],
        "verses": [],
    },
    {
        "name": "Boaz",
        "testament": "old",
        "era_tags": ["judges"],
        "description": "A kinsman-redeemer of Bethlehem who married Ruth.",
        "facts": [
            "Which landowner of Bethlehem became the kinsman-redeemer of Ruth?",
        ],
        "verses": [],
    },
    {
        "name": "Ezra",
        "testament": "old",
        "era_tags": ["exile"],
        "description": "A priest and scribe who taught the Law after the exile.",
        "facts": [
            "Which priest and scribe read the Law aloud to the people from daybreak till noon?",
        ],
        "verses": [],
    },
    {
        "name": "Melchizedek",
        "testament": "old",
        "era_tags": ["patriarchs"],
        "description": "King of Salem and priest of God Most High who blessed Abraham.",
        "facts": [
            "Which king of Salem brought out bread and wine and blessed Abraham?",
        ],
        "verses": [],
    },
    {
        "name": "Rebekah",
        "testament": "old",
        "era_tags": ["patriarchs"],
        "description": "Wife of Isaac, met at a well by Abraham's servant.",
        "facts": [
            "Which woman drew water for a servant and his ten camels at a well?",
        ],
        "verses": [],
    },
]
