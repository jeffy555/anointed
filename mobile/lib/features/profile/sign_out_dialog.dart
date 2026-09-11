import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/analytics_route_observer.dart';
import '../../core/responsive.dart';
import '../../core/screen_ids.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../services/analytics_service.dart';
import '../../state/session_controller.dart';

/// M-30 Sign-out confirmation (design-spec §1F).
///
/// A dialog rather than a screen because it is a two-option confirmation, and
/// the spec's own wording ("You'll need to sign in again…") is the whole content.
/// Returns true once the session has actually been cleared.
Future<bool> showSignOutDialog(BuildContext context) async {
  final AppLocalizations l10n = AppLocalizations.of(context);
  context.read<AnalyticsRouteObserver>().recordScreen(ScreenIds.signOut);

  final bool? confirmed = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) => ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: Layout.dialogMaxWidth),
      child: AlertDialog(
        title: Text(l10n.signOutTitle),
        content: Text(l10n.signOutBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.actionSignOut),
          ),
        ],
      ),
    ),
  );

  if (confirmed != true) return false;
  if (!context.mounted) return false;

  // Emitted (and flushed) before the session is cleared: afterwards the queue
  // has no auth token to post with, so an unflushed event would be dropped.
  context.read<AnalyticsService>().track('sign_out_completed');
  await context.read<AnalyticsService>().flush();

  if (!context.mounted) return false;
  await context.read<SessionController>().signOut();
  return true;
}
