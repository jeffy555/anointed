import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/responsive.dart';
import '../../core/routes.dart';
import '../../core/tokens.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../services/oauth_provider_service.dart';
import '../../widgets/auth_buttons.dart';
import '../../widgets/state_views.dart';
import 'parent_attestation_screen.dart';

/// M-06A Parent OAuth (VPC Path A, design-spec §11).
///
/// The parent authenticates with their *own* Google or Apple account. The
/// account picker is forced so a cached child session cannot be reused silently,
/// and the backend independently rejects a parent whose provider subject matches
/// the child's — the client check here is the friendly half of that pair.
///
/// The credential is not sent yet: Path A submits OAuth + attestation + child
/// profile in one request so the consent record is written atomically, so it is
/// carried forward to M-06B.
class ParentOauthScreen extends StatefulWidget {
  const ParentOauthScreen({super.key});

  @override
  State<ParentOauthScreen> createState() => _ParentOauthScreenState();
}

class _ParentOauthScreenState extends State<ParentOauthScreen> {
  String? _busy;
  String? _error;

  Future<void> _signIn(OAuthProviderKind provider) async {
    setState(() {
      _busy = provider.wireValue;
      _error = null;
    });

    final AppLocalizations l10n = AppLocalizations.of(context);
    try {
      final OAuthCredential credential =
          await context.read<OAuthProviderService>().signIn(
                provider,
                forceAccountPicker: true,
              );
      if (!mounted) return;
      Navigator.of(context).pushNamed(
        Routes.parentAttestation,
        arguments: AttestationArgs(parentCredential: credential),
      );
      setState(() => _busy = null);
    } on OAuthCancelled {
      if (mounted) setState(() => _busy = null);
    } on OAuthFailure {
      if (!mounted) return;
      setState(() {
        _busy = null;
        _error = l10n.welcomeOauthFailed(
          provider == OAuthProviderKind.google
              ? l10n.providerGoogle
              : l10n.providerApple,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final OAuthProviderService oauth = context.read<OAuthProviderService>();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.parentOauthTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ContentColumn(
            maxWidth: 460,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Icon(
                  Icons.admin_panel_settings_outlined,
                  size: 56,
                  color: theme.colorScheme.secondary,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(l10n.parentOauthBody, style: theme.textTheme.bodyLarge),
                const SizedBox(height: AppSpacing.xl),
                AuthButtonStack(
                  showApple: oauth.appleAvailable,
                  busyProvider: _busy,
                  googleLabel: l10n.parentOauthWithGoogle,
                  appleLabel: l10n.parentOauthWithApple,
                  onGoogle: () => _signIn(OAuthProviderKind.google),
                  onApple: () => _signIn(OAuthProviderKind.apple),
                  // Path B is the phone-less alternative for a parent without a
                  // Google/Apple account on this device.
                  phoneLabel: l10n.parentGatePathBTitle,
                  onPhone: () =>
                      Navigator.of(context).pushReplacementNamed(Routes.parentEmail),
                ),
                if (_error != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  NoticeBanner(
                    message: _error!,
                    tone: NoticeTone.error,
                    icon: Icons.error_outline_rounded,
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
