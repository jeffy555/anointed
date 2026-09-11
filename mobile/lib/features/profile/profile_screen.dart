import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/responsive.dart';
import '../../core/routes.dart';
import '../../core/tokens.dart';
import '../../features/map/parchment_codex_tokens.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../models/account.dart';
import '../../models/session.dart';
import '../../services/account_repository.dart';
import '../../state/session_controller.dart';
import '../../widgets/parchment_ui.dart';
import '../../widgets/state_views.dart';
import 'sign_out_dialog.dart';

/// M-26 Profile (design-spec §1F).
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserProfile? _profile;
  bool _loading = true;
  bool _refreshFailed = false;

  @override
  void initState() {
    super.initState();
    _profile = context.read<AccountRepository>().cachedProfile();
    _load();
  }

  Future<void> _load() async {
    try {
      final UserProfile profile = await context.read<AccountRepository>().profile();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _loading = false;
        _refreshFailed = false;
      });
      context.read<SessionController>().applyProfile(profile);
    } on ApiException {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _refreshFailed = true;
      });
    }
  }

  Future<void> _signOut() async {
    final bool confirmed = await showSignOutDialog(context);
    if (!confirmed || !mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      Routes.welcome,
      (Route<dynamic> route) => false,
    );
  }

  String _ageGroupLabel(AppLocalizations l10n, AgeGroup? group) {
    switch (group) {
      case AgeGroup.kid:
        return l10n.profileAgeGroupKid;
      case AgeGroup.youth:
        return l10n.profileAgeGroupYouth;
      case AgeGroup.adult:
        return l10n.profileAgeGroupAdult;
      case AgeGroup.elder:
        return l10n.profileAgeGroupElder;
      case null:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final UserProfile? profile = _profile;

    if (_loading && profile == null) {
      return ColoredBox(
        color: ParchmentColors.page,
        child: Scaffold(
          backgroundColor: ParchmentColors.page,
          body: Column(
            children: <Widget>[
              ParchmentScreenHeader(eyebrow: 'ANOINTED', title: l10n.profileTitle),
              const Expanded(child: LoadingView()),
            ],
          ),
        ),
      );
    }

    if (profile == null) {
      return ColoredBox(
        color: ParchmentColors.page,
        child: Scaffold(
          backgroundColor: ParchmentColors.page,
          body: Column(
            children: <Widget>[
              ParchmentScreenHeader(eyebrow: 'ANOINTED', title: l10n.profileTitle),
              Expanded(
                child: ErrorView(
                  title: l10n.errorGenericTitle,
                  message: l10n.errorGenericBody,
                  onRetry: _load,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ColoredBox(
      color: ParchmentColors.page,
      child: Scaffold(
        backgroundColor: ParchmentColors.page,
        body: Column(
          children: <Widget>[
            ParchmentScreenHeader(eyebrow: 'ANOINTED', title: l10n.profileTitle),
            Expanded(
              child: RefreshIndicator(
                color: ParchmentColors.gold,
                onRefresh: _load,
                child: ListView(
                  padding: Layout.pagePadding(context),
                  children: <Widget>[
                    if (_refreshFailed)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: ParchmentNoticeBanner(
                          message: l10n.profileRefreshFailed,
                          tone: ParchmentNoticeTone.warning,
                          icon: Icons.sync_problem_rounded,
                          actionLabel: l10n.actionRetry,
                          onAction: _load,
                        ),
                      ),
                    Row(
                      children: <Widget>[
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: ParchmentColors.ink,
                          child: Text(
                            _initials(profile.name),
                            style: ParchmentText.cormorant(
                              size: 28,
                              color: ParchmentColors.goldLight,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                profile.name ?? l10n.appName,
                                style: ParchmentText.cormorant(size: 24),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                _ageGroupLabel(l10n, profile.ageGroup),
                                style: ParchmentText.karla(
                                  size: 12,
                                  color: ParchmentColors.inkMuted(),
                                ),
                              ),
                              if (profile.authProvider != null)
                                Text(
                                  l10n.profileSignedInWith(profile.authProvider!),
                                  style: ParchmentText.karla(
                                    size: 12,
                                    color: ParchmentColors.inkMuted(),
                                  ),
                                ),
                              if (profile.memberSince != null)
                                Text(
                                  l10n.profileMemberSince(
                                    DateFormat.yMMMM().format(profile.memberSince!.toLocal()),
                                  ),
                                  style: ParchmentText.karla(
                                    size: 12,
                                    color: ParchmentColors.inkMuted(),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: ParchmentStatChip(
                            label: l10n.profileStatLevels,
                            value: '${profile.levelsCompleted}',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ParchmentStatChip(
                            label: l10n.profileStatHighest,
                            value: '${profile.highestLevelCompleted}',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ParchmentStatChip(
                            label: l10n.profileStatScore,
                            value: '${profile.totalScore}',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    ParchmentCard(
                      child: Row(
                        children: <Widget>[
                          Icon(
                            profile.hasUnlock
                                ? Icons.lock_open_rounded
                                : Icons.lock_outline_rounded,
                            color: profile.hasUnlock
                                ? const Color(0xFF3D7A4A)
                                : ParchmentColors.ink,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              profile.hasUnlock
                                  ? l10n.profilePurchaseUnlocked
                                  : l10n.profilePurchaseLocked,
                              style: ParchmentText.karla(size: 14),
                            ),
                          ),
                          if (!profile.hasUnlock)
                            TextButton(
                              onPressed: () => Navigator.of(context).pushNamed(
                                Routes.iapUnlock,
                                arguments:
                                    const IapArgs(trigger: IapTrigger.lockedLevelTap),
                              ),
                              child: Text(l10n.profileUnlockAction),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Container(
                      decoration: BoxDecoration(
                        color: ParchmentColors.cream,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: ParchmentColors.inkBorder(0.1)),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: <Widget>[
                          ParchmentListTile(
                            title: l10n.profileLinkSettings,
                            leading: const Icon(Icons.settings_outlined),
                            onTap: () => Navigator.of(context).pushNamed(Routes.settings),
                          ),
                          Divider(height: 1, color: ParchmentColors.inkBorder(0.08)),
                          ParchmentListTile(
                            title: l10n.profileLinkSupport,
                            leading: const Icon(Icons.help_outline_rounded),
                            onTap: () => Navigator.of(context).pushNamed(
                              Routes.support,
                              arguments: const SupportArgs(entrySource: 'M-26_profile'),
                            ),
                          ),
                          Divider(height: 1, color: ParchmentColors.inkBorder(0.08)),
                          ParchmentListTile(
                            title: l10n.actionSignOut,
                            leading: const Icon(Icons.logout_rounded),
                            onTap: _signOut,
                          ),
                          Divider(height: 1, color: ParchmentColors.inkBorder(0.08)),
                          ParchmentListTile(
                            title: l10n.profileLinkDelete,
                            leading: const Icon(Icons.delete_outline_rounded),
                            destructive: true,
                            onTap: () =>
                                Navigator.of(context).pushNamed(Routes.accountDeletion),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _initials(String? name) {
    final String trimmed = (name ?? '').trim();
    if (trimmed.isEmpty) return '?';
    final List<String> parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }
}
