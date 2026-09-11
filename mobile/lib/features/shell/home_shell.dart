import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/analytics_route_observer.dart';
import '../../core/responsive.dart';
import '../../core/routes.dart';
import '../../core/screen_ids.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../widgets/state_views.dart';
import '../leaderboard/leaderboard_screen.dart';
import '../map/level_map_screen.dart';
import '../map/parchment_codex_tokens.dart';
import '../map/parchment_codex_widgets.dart';
import '../practice/practice_hub_screen.dart';
import '../profile/profile_screen.dart';

/// The signed-in shell holding M-11, M-17, M-18, and M-26 (design-spec §12).
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.args});

  final HomeArgs args;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  static const List<String> _screenIds = <String>[
    ScreenIds.levelMap,
    ScreenIds.leaderboard,
    ScreenIds.practiceHub,
    ScreenIds.profile,
  ];

  late int _index = widget.args.tab.index;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AnalyticsRouteObserver>().recordScreen(_screenIds[_index]);
      if (widget.args.showSyncFailedToast) {
        showAppSnack(context, AppLocalizations.of(context).levelMapSyncFailed);
      }
    });
  }

  void _select(int next) {
    if (next == _index) return;
    setState(() => _index = next);
    context.read<AnalyticsRouteObserver>().recordScreen(_screenIds[next]);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    // Icons paired with their labels rather than derived from them: the rail is
    // the layout where the icon is largest and the label smallest, and all four
    // destinations previously drew the same circle, so only the text told them
    // apart. Outline for resting, filled for selected — the pairing is what
    // reads as "this one", not the colour alone.
    const List<(IconData, IconData)> tabIcons = <(IconData, IconData)>[
      (Icons.map_outlined, Icons.map_rounded),
      (Icons.emoji_events_outlined, Icons.emoji_events_rounded),
      (Icons.school_outlined, Icons.school_rounded),
      (Icons.person_outline_rounded, Icons.person_rounded),
    ];

    final List<String> tabLabels = <String>[
      l10n.navMap,
      l10n.navLeaderboard,
      l10n.navPractice,
      l10n.navProfile,
    ];

    final Widget body = IndexedStack(
      index: _index,
      children: <Widget>[
        const LevelMapScreen(),
        // Told when it is the visible tab, so its refresh poll runs only then.
        LeaderboardScreen(
          entrySource: 'nav_tab',
          active: _index == HomeTab.leaderboard.index,
        ),
        const PracticeHubScreen(),
        const ProfileScreen(),
      ],
    );

    if (Layout.useNavigationRail(context)) {
      return ColoredBox(
        color: ParchmentColors.page,
        child: Scaffold(
          backgroundColor: ParchmentColors.page,
          body: SafeArea(
            child: Row(
              children: <Widget>[
                NavigationRail(
                backgroundColor: ParchmentColors.cream,
                indicatorColor: ParchmentColors.strip,
                selectedIconTheme: const IconThemeData(color: ParchmentColors.current),
                unselectedIconTheme:
                    IconThemeData(color: ParchmentColors.inkMuted(0.35)),
                selectedLabelTextStyle: ParchmentText.karla(
                  size: 12,
                  weight: FontWeight.w700,
                  color: ParchmentColors.ink,
                ),
                unselectedLabelTextStyle: ParchmentText.karla(
                  size: 12,
                  weight: FontWeight.w500,
                  color: ParchmentColors.inkMuted(0.5),
                ),
                selectedIndex: _index,
                onDestinationSelected: _select,
                labelType: NavigationRailLabelType.all,
                destinations: <NavigationRailDestination>[
                  for (int i = 0; i < tabLabels.length; i++)
                    NavigationRailDestination(
                      icon: Icon(tabIcons[i].$1),
                      selectedIcon: Icon(tabIcons[i].$2),
                      label: Text(tabLabels[i]),
                    ),
                ],
              ),
              Container(width: 1, color: ParchmentColors.inkBorder(0.1)),
              Expanded(child: body),
            ],
          ),
        ),
        ),
      );
    }

    return ColoredBox(
      color: ParchmentColors.page,
      child: Scaffold(
        backgroundColor: ParchmentColors.page,
        // The rail branch above has always had this; the phone branch did not,
        // and it stopped mattering only because the system used to inset the
        // app for us. Targeting SDK 35+ means Android draws edge-to-edge
        // whether the app asks or not, so on Android 15 and 16 the level map's
        // wordmark came up underneath the clock and the status icons.
        //
        // Top only: the bottom is the tab bar's own, and it already pads itself
        // clear of the gesture handle.
        body: SafeArea(bottom: false, child: body),
        bottomNavigationBar: ParchmentTabBar(
          selectedIndex: _index,
          onSelected: _select,
          labels: tabLabels,
        ),
      ),
    );
  }
}
