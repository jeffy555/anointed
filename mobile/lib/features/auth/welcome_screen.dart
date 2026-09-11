import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/config.dart';
import '../../core/responsive.dart';
import '../../core/routes.dart';
import '../../core/tokens.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../models/session.dart';
import '../map/parchment_codex_tokens.dart';
import '../../services/oauth_provider_service.dart';
import '../../state/session_controller.dart';
import '../../widgets/auth_buttons.dart';
import '../../widgets/state_views.dart';
import 'age_gate.dart';

/// M-03 Welcome / sign-up (design-spec §10).
///
/// All three providers sit at equal prominence, and the same OAuth endpoint
/// serves sign-up and sign-in — so a returning user who taps "Continue with
/// Google" here lands back on their existing account rather than an error.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  String? _busy;

  Future<void> _oauth(OAuthProviderKind provider) async {
    setState(() => _busy = provider.wireValue);

    final AppLocalizations l10n = AppLocalizations.of(context);
    final OAuthProviderService oauth = context.read<OAuthProviderService>();
    final SessionController session = context.read<SessionController>();

    try {
      final OAuthCredential credential = await oauth.signIn(provider);
      final OnboardingStep step = await session.signInWithOAuth(credential);
      if (!mounted) return;
      goToStep(context, step);
    } on OAuthCancelled {
      // design-spec §15 M-10: returning from a dismissed provider sheet is not an
      // error and gets no toast.
      if (mounted) setState(() => _busy = null);
    } on OAuthFailure catch (error) {
      if (!mounted) return;
      setState(() => _busy = null);
      showAppSnack(
        context,
        error.detail ??
            l10n.welcomeOauthFailed(_providerLabel(l10n, provider)),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _busy = null);
      showAppSnack(
        context,
        error.isOffline ? l10n.errorOfflineBody : error.message,
      );
    }
  }

  String _providerLabel(AppLocalizations l10n, OAuthProviderKind provider) {
    return provider == OAuthProviderKind.google
        ? l10n.providerGoogle
        : l10n.providerApple;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final OAuthProviderService oauth = context.read<OAuthProviderService>();

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: ContentColumn(
            maxWidth: 440,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const SizedBox(height: AppSpacing.xl),
                Center(
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: ParchmentColors.cream,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(
                        color: ParchmentColors.gold.withOpacity(0.45),
                        width: 2,
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: ParchmentColors.ink.withOpacity(0.12),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.auto_stories_rounded,
                      size: 44,
                      color: ParchmentColors.gold,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  l10n.welcomeHeadline,
                  style: theme.textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.welcomeSubhead,
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xl),
                AuthButtonStack(
                  showApple: oauth.appleAvailable,
                  busyProvider: _busy,
                  onGoogle: () => _oauth(OAuthProviderKind.google),
                  onApple: () => _oauth(OAuthProviderKind.apple),
                  onPhone: () => Navigator.of(context).pushNamed(Routes.phoneSignUp),
                ),
                const SizedBox(height: AppSpacing.md),
                Center(
                  child: Text(
                    l10n.welcomeSaveProgressNote,
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                const OrDivider(),
                const SizedBox(height: AppSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(l10n.welcomeAlreadyHaveAccount,
                        style: theme.textTheme.bodyMedium),
                    TextButton(
                      onPressed: _busy != null
                          ? null
                          : () => Navigator.of(context).pushNamed(Routes.signIn),
                      child: Text(l10n.welcomeSignInLink),
                    ),
                  ],
                ),
                if (AppConfig.devOAuthFallback) ...<Widget>[
                  const SizedBox(height: AppSpacing.lg),
                  NoticeBanner(
                    message: l10n.devSignInBadge,
                    tone: NoticeTone.warning,
                    icon: Icons.construction_rounded,
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
