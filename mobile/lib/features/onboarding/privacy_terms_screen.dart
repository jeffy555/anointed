import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/link_launcher.dart';
import '../../core/responsive.dart';
import '../../core/tokens.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../models/account.dart';
import '../../models/session.dart';
import '../../services/account_repository.dart';
import '../../state/session_controller.dart';
import '../../widgets/form_fields.dart';
import '../../widgets/state_views.dart';
import '../auth/age_gate.dart';

/// M-08 Privacy policy and Terms acknowledgment (design-spec §1B).
///
/// "Continue" *is* the acceptance — there is no separate checkbox, matching the
/// spec's copy. The document URLs come from the API rather than being compiled
/// in, so legal pages can be moved without an app release.
class PrivacyTermsScreen extends StatefulWidget {
  const PrivacyTermsScreen({super.key});

  @override
  State<PrivacyTermsScreen> createState() => _PrivacyTermsScreenState();
}

class _PrivacyTermsScreenState extends State<PrivacyTermsScreen> {
  UserProfile? _profile;
  bool _busy = false;
  String? _error;
  String? _linkError;

  @override
  void initState() {
    super.initState();
    _profile = context.read<AccountRepository>().cachedProfile();
    _loadUrls();
  }

  Future<void> _loadUrls() async {
    try {
      final UserProfile profile = await context.read<AccountRepository>().profile();
      if (!mounted) return;
      setState(() => _profile = profile);
    } on ApiException {
      // The links degrade to the cached copy (or to disabled buttons on a first
      // run with no cache); acceptance itself does not depend on them.
    }
  }

  Future<void> _open(String url) async {
    final bool opened = await LinkLauncher.open(url);
    if (!mounted) return;
    setState(() {
      _linkError = opened ? null : AppLocalizations.of(context).privacyLinkUnavailable;
    });
  }

  Future<void> _accept() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    final AppLocalizations l10n = AppLocalizations.of(context);
    try {
      final OnboardingStep step =
          await context.read<SessionController>().acceptPrivacy();
      if (!mounted) return;
      goToStep(context, step);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.isOffline ? l10n.errorOfflineBody : error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final UserProfile? profile = _profile;

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.privacyTitle),
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            child: ContentColumn(
              maxWidth: 480,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Icon(
                    Icons.shield_outlined,
                    size: 56,
                    color: theme.colorScheme.secondary,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(l10n.privacyBody, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: AppSpacing.lg),
                  OutlinedButton.icon(
                    onPressed: profile == null || profile.privacyPolicyUrl.isEmpty
                        ? null
                        : () => _open(profile.privacyPolicyUrl),
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: Text(l10n.privacyPolicyLink),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton.icon(
                    onPressed: profile == null || profile.termsOfServiceUrl.isEmpty
                        ? null
                        : () => _open(profile.termsOfServiceUrl),
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: Text(l10n.termsLink),
                  ),
                  if (_linkError != null) ...<Widget>[
                    const SizedBox(height: AppSpacing.md),
                    NoticeBanner(
                      message: _linkError!,
                      tone: NoticeTone.warning,
                      icon: Icons.link_off_rounded,
                    ),
                  ],
                  if (_error != null) ...<Widget>[
                    const SizedBox(height: AppSpacing.md),
                    NoticeBanner(
                      message: _error!,
                      tone: NoticeTone.error,
                      icon: Icons.error_outline_rounded,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  SubmitButton(
                    label: l10n.actionContinue,
                    busy: _busy,
                    onPressed: _accept,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
