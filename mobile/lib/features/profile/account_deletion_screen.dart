import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/responsive.dart';
import '../../core/routes.dart';
import '../../core/tokens.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../models/account.dart';
import '../../services/account_repository.dart';
import '../../state/session_controller.dart';
import '../../widgets/form_fields.dart';
import '../../widgets/state_views.dart';

enum _DeletionStep { warning, disclosure, finalCheck, done }

/// M-29 Account deletion (design-spec §1F, §13).
///
/// Three deliberate steps — warning, server-authored disclosure, and a checkbox
/// confirmation — because this is an irreversible hard delete required by App
/// Store guideline 5.1.1(v). The disclosure copy comes from
/// `/v1/account/deletion-preview` rather than ARB so the retention statement can
/// be corrected without an app release.
///
/// `account_deletion_started` and `account_deleted` are both emitted server-side
/// by the delete endpoint, so this screen deliberately emits neither.
class AccountDeletionScreen extends StatefulWidget {
  const AccountDeletionScreen({super.key});

  @override
  State<AccountDeletionScreen> createState() => _AccountDeletionScreenState();
}

class _AccountDeletionScreenState extends State<AccountDeletionScreen> {
  _DeletionStep _step = _DeletionStep.warning;
  DeletionPreview? _preview;
  bool _busy = false;
  bool _acknowledged = false;
  String? _error;

  Future<void> _loadPreview() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final DeletionPreview preview =
          await context.read<AccountRepository>().deletionPreview();
      if (!mounted) return;
      setState(() {
        _preview = preview;
        _step = _DeletionStep.disclosure;
        _busy = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.isOffline
            ? AppLocalizations.of(context).errorOfflineBody
            : error.message;
      });
    }
  }

  Future<void> _delete() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<SessionController>().deleteAccount();
      if (!mounted) return;
      setState(() {
        _step = _DeletionStep.done;
        _busy = false;
      });
      // Long enough to read the confirmation, short enough that nobody is stuck
      // on a screen with no account behind it.
      await Future<void>.delayed(const Duration(seconds: 3));
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(
        Routes.welcome,
        (Route<dynamic> route) => false,
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      final AppLocalizations l10n = AppLocalizations.of(context);
      setState(() {
        _busy = false;
        _error = error.isOffline ? l10n.errorOfflineBody : l10n.deleteAccountFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return PopScope(
      // Once the account is gone there is nothing to go back to.
      canPop: _step != _DeletionStep.done && !_busy,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.deleteAccountTitle),
          automaticallyImplyLeading: _step != _DeletionStep.done,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            child: ContentColumn(child: _buildStep(l10n)),
          ),
        ),
      ),
    );
  }

  Widget _buildStep(AppLocalizations l10n) {
    final ThemeData theme = Theme.of(context);

    switch (_step) {
      case _DeletionStep.warning:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Icon(
              Icons.warning_amber_rounded,
              size: 56,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(l10n.deleteAccountBody, style: theme.textTheme.bodyLarge),
            if (_error != null) ...<Widget>[
              const SizedBox(height: AppSpacing.lg),
              NoticeBanner(
                message: _error!,
                tone: NoticeTone.error,
                actionLabel: l10n.actionRetry,
                onAction: _loadPreview,
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            SubmitButton(
              label: l10n.deleteAccountFirstAction,
              busy: _busy,
              destructive: true,
              onPressed: _loadPreview,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: _busy ? null : () => Navigator.of(context).pop(),
              child: Text(l10n.actionCancel),
            ),
          ],
        );

      case _DeletionStep.disclosure:
        final DeletionPreview preview = _preview!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (preview.isUnder13)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: NoticeBanner(
                  message: l10n.deleteAccountChildNote,
                  tone: NoticeTone.warning,
                ),
              ),
            _DisclosureList(
              heading: l10n.deleteAccountRemovedHeading,
              items: preview.removed,
              icon: Icons.remove_circle_outline_rounded,
              iconColor: theme.colorScheme.error,
            ),
            const SizedBox(height: AppSpacing.lg),
            _DisclosureList(
              heading: l10n.deleteAccountRetainedHeading,
              items: preview.retainedAnonymized,
              icon: Icons.shield_outlined,
              iconColor: theme.colorScheme.primary,
            ),
            const SizedBox(height: AppSpacing.lg),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    l10n.deleteAccountStatLevels(preview.levelsCompleted),
                    style: theme.textTheme.bodyMedium,
                  ),
                  if (preview.hasUnlock) ...<Widget>[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      l10n.deleteAccountPurchaseNote,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  if (preview.warning.isNotEmpty) ...<Widget>[
                    const SizedBox(height: AppSpacing.sm),
                    Text(preview.warning, style: theme.textTheme.bodySmall),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: () => setState(() => _step = _DeletionStep.finalCheck),
              child: Text(l10n.actionContinue),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.actionCancel),
            ),
          ],
        );

      case _DeletionStep.finalCheck:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(l10n.deleteAccountFinalTitle, style: theme.textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.md),
            CheckboxListTile(
              value: _acknowledged,
              onChanged: _busy
                  ? null
                  : (bool? value) =>
                      setState(() => _acknowledged = value ?? false),
              title: Text(l10n.deleteAccountAcknowledge),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              NoticeBanner(
                message: _error!,
                tone: NoticeTone.error,
                actionLabel: l10n.actionContactSupport,
                onAction: () => Navigator.of(context).pushNamed(
                  Routes.support,
                  arguments: const SupportArgs(
                    entrySource: 'M-29_deletion_error',
                    presetCategory: 'account',
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            SubmitButton(
              label: l10n.deleteAccountConfirmAction,
              busy: _busy,
              destructive: true,
              onPressed: _acknowledged ? _delete : null,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: _busy ? null : () => Navigator.of(context).pop(),
              child: Text(l10n.actionCancel),
            ),
          ],
        );

      case _DeletionStep.done:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const SizedBox(height: AppSpacing.xl),
            Icon(
              Icons.check_circle_outline_rounded,
              size: 56,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              l10n.deleteAccountDoneTitle,
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.deleteAccountDoneBody,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        );
    }
  }
}

class _DisclosureList extends StatelessWidget {
  const _DisclosureList({
    required this.heading,
    required this.items,
    required this.icon,
    required this.iconColor,
  });

  final String heading;
  final List<String> items;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(heading, style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        for (final String item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(icon, size: 18, color: iconColor),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(item, style: theme.textTheme.bodyMedium),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
