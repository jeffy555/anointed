import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../core/device_context.dart';
import '../../core/link_launcher.dart';
import '../../core/local_store.dart';
import '../../core/responsive.dart';
import '../../core/routes.dart';
import '../../core/tokens.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../models/account.dart';
import '../../services/account_repository.dart';
import '../../services/analytics_service.dart';
import '../../services/notification_service.dart';
import '../../state/session_controller.dart';
import '../../state/settings_controller.dart';
import '../../widgets/state_views.dart';
import 'sign_out_dialog.dart';

/// M-27 Settings (design-spec §1F, §21).
///
/// Notification, appearance, legal, and account rows. The notification toggle is
/// the only one with a real OS dependency: turning it on when permission was
/// previously denied cannot succeed from inside the app, so that case routes the
/// user to system settings instead of silently failing.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _togglingNotifications = false;

  Future<void> _setNotifications(bool enabled) async {
    setState(() => _togglingNotifications = true);
    final AppLocalizations l10n = AppLocalizations.of(context);
    final NotificationService notifications = context.read<NotificationService>();
    final AnalyticsService analytics = context.read<AnalyticsService>();

    if (!enabled) {
      await notifications.setOptIn(false);
      analytics.track(
        'notification_permission_denied',
        properties: <String, Object?>{'prompt_source': 'M-27_settings'},
      );
      if (mounted) setState(() => _togglingNotifications = false);
      return;
    }

    final bool granted = await notifications.requestPermission();
    if (!mounted) return;

    analytics.track(
      granted
          ? 'notification_permission_granted'
          : 'notification_permission_denied',
      properties: <String, Object?>{'prompt_source': 'M-27_settings'},
    );

    if (granted) {
      await notifications.setOptIn(true);
      if (!mounted) return;
      final int currentLevel = context.read<LocalStore>().currentLevel;
      await notifications.rescheduleForActiveSession(
        currentLevel: currentLevel,
        reminder3dTitle: l10n.notification3dTitle,
        reminder3dBody: l10n.notification3dBody(currentLevel),
        reminder7dTitle: l10n.notification7dTitle,
        reminder7dBody: l10n.notification7dBody,
        channelName: l10n.notificationChannelName,
        channelDescription: l10n.notificationChannelDescription,
      );
      if (mounted) setState(() => _togglingNotifications = false);
      return;
    }

    setState(() => _togglingNotifications = false);

    // The OS declined, and it will not show the system prompt again — system
    // settings is the only remaining path.
    final bool? open = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(l10n.settingsPlayReminders),
        content: Text(l10n.settingsRemindersBlocked),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.settingsOpenDeviceSettings),
          ),
        ],
      ),
    );
    if (open == true) await LinkLauncher.openNotificationSettings();
  }

  Future<void> _signOut() async {
    final bool done = await showSignOutDialog(context);
    if (!done || !mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      Routes.welcome,
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final SettingsController settings = context.watch<SettingsController>();
    final NotificationService notifications = context.watch<NotificationService>();
    final DeviceContext device = context.read<DeviceContext>();
    // The legal URLs are server-owned (design-spec §21) and already cached by
    // M-26, so Settings reads the cache rather than re-fetching the profile.
    final UserProfile? profile = context.read<AccountRepository>().cachedProfile();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        padding: Layout.pagePadding(context),
        children: <Widget>[
          _SectionHeader(label: l10n.settingsSectionReminders),
          Card(
            child: Column(
              children: <Widget>[
                SwitchListTile(
                  value: notifications.optedIn,
                  onChanged: _togglingNotifications ? null : _setNotifications,
                  title: Text(l10n.settingsPlayReminders),
                  subtitle: Text(
                    notifications.permissionBlocked && !notifications.optedIn
                        ? l10n.settingsRemindersBlocked
                        : l10n.settingsPlayRemindersSubtitle,
                  ),
                  secondary: const Icon(Icons.notifications_active_outlined),
                ),
                if (_togglingNotifications)
                  const Padding(
                    padding: EdgeInsets.only(bottom: AppSpacing.sm),
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _SectionHeader(label: l10n.settingsSectionDisplay),
          Card(
            child: Column(
              children: <Widget>[
                AppearanceRow(
                  themeMode: settings.themeMode,
                  onThemeModeChanged: settings.setThemeMode,
                ),
                const Divider(height: 1),
                SwitchListTile(
                  value: settings.largeText,
                  onChanged: settings.setLargeText,
                  title: Text(l10n.settingsLargeText),
                  subtitle: Text(l10n.settingsLargeTextSubtitle),
                  secondary: const Icon(Icons.format_size_rounded),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _SectionHeader(label: l10n.settingsSectionAbout),
          Card(
            child: Column(
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: Text(l10n.privacyPolicyLink),
                  trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                  onTap: () => _openLegal(
                    _urlOrFallback(
                      profile?.privacyPolicyUrl,
                      AppConfig.fallbackPrivacyUrl,
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.gavel_rounded),
                  title: Text(l10n.termsLink),
                  trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                  onTap: () => _openLegal(
                    _urlOrFallback(
                      profile?.termsOfServiceUrl,
                      AppConfig.fallbackTermsUrl,
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.help_outline_rounded),
                  title: Text(l10n.supportTitle),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).pushNamed(
                    Routes.support,
                    arguments: const SupportArgs(entrySource: 'M-27_settings'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _SectionHeader(label: l10n.settingsSectionPurchases),
          Card(
            child: ListTile(
              leading: const Icon(Icons.restore_rounded),
              title: Text(l10n.restorePurchaseTitle),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () async {
                final SessionController session =
                    context.read<SessionController>();
                final ScaffoldMessengerState messenger =
                    ScaffoldMessenger.of(context);
                final bool? restored = await Navigator.of(context)
                    .pushNamed<bool>(Routes.restorePurchase);
                if (restored != true) return;
                session.applyUnlock();
                messenger
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                      SnackBar(content: Text(l10n.restorePurchaseSuccess)));
              },
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _SectionHeader(label: l10n.settingsSectionAccount),
          Card(
            child: Column(
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.logout_rounded),
                  title: Text(l10n.actionSignOut),
                  onTap: _signOut,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(
                    Icons.delete_outline_rounded,
                    color: theme.colorScheme.error,
                  ),
                  title: Text(
                    l10n.profileLinkDelete,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () =>
                      Navigator.of(context).pushNamed(Routes.accountDeletion),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: Text(
              l10n.settingsAppVersion(device.appVersion, device.buildNumber),
              style: theme.textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  /// The profile cache can be empty on a cold start straight into Settings, and
  /// the build-time fallback keeps the legal links tappable in that case.
  String _urlOrFallback(String? url, String fallback) =>
      (url == null || url.isEmpty) ? fallback : url;

  Future<void> _openLegal(String url) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool opened = await LinkLauncher.open(url);
    if (!opened && mounted) {
      showAppSnack(context, l10n.errorLinkFailed(url));
    }
  }

}

/// The theme-mode row: an icon-led title/subtitle line, then the light/dark/
/// system picker on its own full-width line underneath.
///
/// Deliberately not a `ListTile` with the picker as `trailing`. A three-segment
/// `SegmentedButton` with real-word labels ("Match device" is the long one)
/// does not fit `ListTile.trailing`'s width budget on an ordinary phone --
/// Flutter's own `ListTile` throws "Trailing widget consumes entire tile
/// width" for exactly this shape, even at default text scale, not only at a
/// large one. In a release/profile build with no debug overlay to show that
/// assertion, what got painted instead was every letter of "Appearance" and
/// "Match device" on its own line. Stacking the picker under the title removes
/// the width fight outright, rather than chasing a size threshold that would
/// only move with the next locale or font size anyway. Covered by
/// test/settings_appearance_row_test.dart across five text scales.
class AppearanceRow extends StatelessWidget {
  const AppearanceRow({
    super.key,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  String _themeLabel(AppLocalizations l10n, ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return l10n.settingsThemeSystem;
      case ThemeMode.light:
        return l10n.settingsThemeLight;
      case ThemeMode.dark:
        return l10n.settingsThemeDark;
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.brightness_6_outlined),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(l10n.settingsThemeMode,
                        style: Theme.of(context).textTheme.bodyLarge),
                    Text(
                      _themeLabel(l10n, themeMode),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          SegmentedButton<ThemeMode>(
            showSelectedIcon: false,
            segments: <ButtonSegment<ThemeMode>>[
              ButtonSegment<ThemeMode>(
                value: ThemeMode.system,
                label: Text(l10n.settingsThemeSystem),
              ),
              ButtonSegment<ThemeMode>(
                value: ThemeMode.light,
                label: Text(l10n.settingsThemeLight),
              ),
              ButtonSegment<ThemeMode>(
                value: ThemeMode.dark,
                label: Text(l10n.settingsThemeDark),
              ),
            ],
            selected: <ThemeMode>{themeMode},
            onSelectionChanged: (Set<ThemeMode> selection) {
              onThemeModeChanged(selection.first);
            },
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.xs,
        bottom: AppSpacing.sm,
      ),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              letterSpacing: 0.8,
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}
