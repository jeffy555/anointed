import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/config.dart';
import '../../core/connectivity.dart';
import '../../core/responsive.dart';
import '../../core/tokens.dart';
import '../../features/map/parchment_codex_tokens.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../models/leaderboard.dart';
import '../../services/analytics_service.dart';
import '../../services/leaderboard_repository.dart';
import '../../widgets/parchment_ui.dart';
import '../../widgets/state_views.dart';

/// M-17 Leaderboard (design-spec §1E, §21).
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({
    super.key,
    required this.entrySource,
    this.active = true,
  });

  final String entrySource;

  /// Whether this tab is the one on screen.
  ///
  /// The shell keeps all four tabs alive in an `IndexedStack` and stays mounted
  /// under every pushed route, so without this the refresh poll ran forever —
  /// through ranked gameplay, ad breaks and the whole Kids Zone. A leaderboard
  /// nobody is looking at does not need refreshing.
  final bool active;

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with WidgetsBindingObserver {
  LeaderboardWindow _window = LeaderboardWindow.allTime;
  LeaderboardPage? _page;
  bool _loading = true;
  bool _stale = false;
  DateTime? _cachedAt;
  String? _error;
  Timer? _refresh;
  bool _viewTracked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _page = context.read<LeaderboardRepository>().cached();
    _cachedAt = context.read<LeaderboardRepository>().cachedAt;
    if (widget.active) {
      _load();
      _startPolling();
    }
  }

  @override
  void didUpdateWidget(LeaderboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active == oldWidget.active) return;
    if (widget.active) {
      // Coming back to the tab: show what is there, then bring it up to date.
      _load(showSpinner: _page == null);
      _startPolling();
    } else {
      _stopPolling();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      if (widget.active) _startPolling();
    } else if (state != AppLifecycleState.inactive) {
      // Backgrounded: stop spending the user's data on a screen they cannot see.
      _stopPolling();
    }
  }

  void _startPolling() {
    _refresh ??= Timer.periodic(
      AppConfig.leaderboardRefreshInterval,
      (_) => _load(showSpinner: false),
    );
  }

  void _stopPolling() {
    _refresh?.cancel();
    _refresh = null;
  }

  @override
  void dispose() {
    _stopPolling();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _load({bool showSpinner = true}) async {
    if (showSpinner && _page == null) setState(() => _loading = true);

    final LeaderboardRepository repo = context.read<LeaderboardRepository>();
    try {
      final LeaderboardPage page = await repo.fetch(
        window: _window,
        entrySource: widget.entrySource,
      );
      if (!mounted) return;
      setState(() {
        _page = page;
        _loading = false;
        _stale = false;
        _error = null;
        _cachedAt = DateTime.now();
      });
      _trackViewOnce(page.yourRank.rank);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _stale = _page != null;
        _error = _page != null
            ? null
            : error.isOffline
                ? null
                : error.message;
      });
      _trackViewOnce(_page?.yourRank.rank);
    }
  }

  void _trackViewOnce(int? rank) {
    if (_viewTracked) return;
    if (context.read<ConnectivityService>().isOnline && !_stale) return;
    _viewTracked = true;
    context.read<AnalyticsService>().track(
      'leaderboard_viewed',
      properties: <String, Object?>{
        'connectivity': context.read<ConnectivityService>().label,
        'entry_source': widget.entrySource,
        'user_rank': rank,
      },
    );
  }

  Future<void> _switchWindow(LeaderboardWindow window) async {
    if (window == _window) return;
    setState(() {
      _window = window;
      _page = window == LeaderboardWindow.allTime
          ? context.read<LeaderboardRepository>().cached()
          : null;
    });
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool offline = !context.watch<ConnectivityService>().isOnline;
    final LeaderboardPage? page = _page;

    return ColoredBox(
      color: ParchmentColors.page,
      child: Scaffold(
        backgroundColor: ParchmentColors.page,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ParchmentScreenHeader(
              eyebrow: 'ANOINTED',
              title: l10n.leaderboardTitle,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
              child: ParchmentWindowPicker<LeaderboardWindow>(
                segments: <ButtonSegment<LeaderboardWindow>>[
                  ButtonSegment<LeaderboardWindow>(
                    value: LeaderboardWindow.allTime,
                    label: Text(l10n.leaderboardWindowAllTime),
                  ),
                  ButtonSegment<LeaderboardWindow>(
                    value: LeaderboardWindow.weekly,
                    label: Text(l10n.leaderboardWindowWeekly),
                  ),
                  ButtonSegment<LeaderboardWindow>(
                    value: LeaderboardWindow.daily,
                    label: Text(l10n.leaderboardWindowDaily),
                  ),
                ],
                selected: <LeaderboardWindow>{_window},
                onChanged: _switchWindow,
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                color: ParchmentColors.gold,
                onRefresh: () => _load(showSpinner: false),
                child: _body(context, l10n, page, offline),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    AppLocalizations l10n,
    LeaderboardPage? page,
    bool offline,
  ) {
    if (_loading && page == null) return const SkeletonList(rows: 8);

    if (page == null) {
      return ListView(
        children: <Widget>[
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.18),
          if (offline || _error == null)
            EmptyView(
              message: l10n.leaderboardOffline,
              icon: Icons.wifi_off_rounded,
              actionLabel: l10n.actionRetry,
              onAction: _load,
            )
          else
            EmptyView(
              message: _error!,
              icon: Icons.error_outline_rounded,
              actionLabel: l10n.actionRetry,
              onAction: _load,
            ),
        ],
      );
    }

    if (page.isEmpty) {
      return ListView(
        children: <Widget>[
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.18),
          EmptyView(message: l10n.leaderboardEmpty, icon: Icons.emoji_events_outlined),
        ],
      );
    }

    return ListView.builder(
      padding: Layout.pagePadding(context),
      itemCount: page.rows.length + 1,
      itemBuilder: (BuildContext context, int index) {
        if (index == 0) return _header(l10n, page);
        final LeaderboardRow row = page.rows[index - 1];
        return _RowTile(row: row, l10n: l10n);
      },
    );
  }

  Widget _header(AppLocalizations l10n, LeaderboardPage page) {
    final YourRank you = page.yourRank;
    final DateTime? at = _cachedAt;
    final int minutes =
        at == null ? 0 : DateTime.now().difference(at).inMinutes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (_stale)
          ParchmentNoticeBanner(
            message: l10n.leaderboardError,
            tone: ParchmentNoticeTone.warning,
            icon: Icons.sync_problem_rounded,
            actionLabel: l10n.actionRetry,
            onAction: () => _load(showSpinner: false),
          ),
        const SizedBox(height: AppSpacing.sm),
        ParchmentCard(
          title: l10n.leaderboardYourRank,
          child: Text(
            you.rank != null && you.score != null
                ? l10n.leaderboardYourRankValue(you.rank!, you.score!)
                : l10n.leaderboardYourRankNone,
            style: ParchmentText.cormorant(size: 22),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          minutes <= 0
              ? l10n.leaderboardUpdatedJustNow
              : l10n.leaderboardUpdatedAgo(minutes),
          style: ParchmentText.karla(size: 12, color: ParchmentColors.inkMuted()),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: <Widget>[
            SizedBox(
              width: 48,
              child: Text(
                l10n.leaderboardColumnRank,
                style: ParchmentText.karla(size: 11, weight: FontWeight.w700),
              ),
            ),
            Expanded(
              child: Text(
                l10n.leaderboardColumnPlayer,
                style: ParchmentText.karla(size: 11, weight: FontWeight.w700),
              ),
            ),
            Text(
              l10n.leaderboardColumnScore,
              style: ParchmentText.karla(size: 11, weight: FontWeight.w700),
            ),
          ],
        ),
        Divider(color: ParchmentColors.inkBorder(0.15)),
      ],
    );
  }
}

class _RowTile extends StatelessWidget {
  const _RowTile({required this.row, required this.l10n});

  final LeaderboardRow row;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${l10n.leaderboardColumnRank} ${row.rank}, '
          '${row.displayName}, ${row.score}',
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: kMinTapTarget),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: row.isCurrentUser
              ? ParchmentColors.goldPale.withOpacity(0.45)
              : null,
          borderRadius: BorderRadius.circular(12),
          border: row.isCurrentUser
              ? Border.all(color: ParchmentColors.gold.withOpacity(0.45))
              : null,
        ),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 48,
              child: Row(
                children: <Widget>[
                  if (row.isCurrentUser)
                    const Icon(
                      Icons.person_rounded,
                      size: 14,
                      color: ParchmentColors.current,
                    ),
                  Text('${row.rank}', style: ParchmentText.karla(size: 14)),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(row.displayName, style: ParchmentText.karla(size: 15)),
                  if (row.levelId > 0)
                    Text(
                      l10n.leaderboardLevelLabel(row.levelId),
                      style: ParchmentText.karla(
                        size: 11,
                        color: ParchmentColors.inkMuted(),
                      ),
                    ),
                ],
              ),
            ),
            Text(
              '${row.score}',
              style: ParchmentText.karla(size: 16, weight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
