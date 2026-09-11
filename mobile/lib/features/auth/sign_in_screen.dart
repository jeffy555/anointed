import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/responsive.dart';
import '../../core/routes.dart';
import '../../core/tokens.dart';
import '../../features/map/parchment_codex_tokens.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../models/session.dart';
import '../../services/oauth_provider_service.dart';
import '../../state/session_controller.dart';
import '../../widgets/auth_buttons.dart';
import '../../widgets/form_fields.dart';
import '../../widgets/parchment_ui.dart';
import 'age_gate.dart';

/// M-10 Sign-in (design-spec §10).
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _mobile = TextEditingController();
  final TextEditingController _name = TextEditingController();

  String? _busy;
  bool _phoneFormOpen = false;
  String? _formError;
  bool _showRecoveryHelp = false;

  @override
  void dispose() {
    _mobile.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _oauth(OAuthProviderKind provider) async {
    setState(() {
      _busy = provider.wireValue;
      _formError = null;
      _showRecoveryHelp = false;
    });

    final AppLocalizations l10n = AppLocalizations.of(context);
    final OAuthProviderService oauth = context.read<OAuthProviderService>();
    final SessionController session = context.read<SessionController>();
    try {
      final OAuthCredential credential = await oauth.signIn(provider);
      final OnboardingStep step = await session.signInWithOAuth(credential);
      if (!mounted) return;
      goToStep(context, step);
    } on OAuthCancelled {
      if (mounted) setState(() => _busy = null);
    } on OAuthFailure catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = null;
        _formError = error.detail ??
            l10n.welcomeOauthFailed(
              provider == OAuthProviderKind.google
                  ? l10n.providerGoogle
                  : l10n.providerApple,
            );
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = null;
        _formError = error.isOffline ? l10n.errorOfflineBody : error.message;
      });
    }
  }

  Future<void> _phoneSignIn() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = 'phone';
      _formError = null;
      _showRecoveryHelp = false;
    });

    final AppLocalizations l10n = AppLocalizations.of(context);
    try {
      final OnboardingStep step = await context.read<SessionController>().phoneSignIn(
            mobile: _mobile.text,
            name: _name.text.trim(),
          );
      if (!mounted) return;
      goToStep(context, step);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = null;
        _showRecoveryHelp = error.statusCode == 404;
        _formError = error.statusCode == 404
            ? l10n.signInAccountNotFound
            : error.isOffline
                ? l10n.errorOfflineBody
                : error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final OAuthProviderService oauth = context.read<OAuthProviderService>();

    return ColoredBox(
      color: ParchmentColors.page,
      child: Scaffold(
        backgroundColor: ParchmentColors.page,
        appBar: AppBar(
          backgroundColor: ParchmentColors.page,
          elevation: 0,
          foregroundColor: ParchmentColors.ink,
          title: Text(
            l10n.actionSignIn,
            style: ParchmentText.cormorant(size: 22),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            child: ContentColumn(
              maxWidth: 440,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(l10n.signInTitle, style: ParchmentText.cormorant(size: 28)),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    l10n.signInSubhead,
                    style: ParchmentText.karla(size: 14, height: 1.4),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AuthButtonStack(
                    showApple: oauth.appleAvailable,
                    busyProvider: _busy,
                    onGoogle: () => _oauth(OAuthProviderKind.google),
                    onApple: () => _oauth(OAuthProviderKind.apple),
                    onPhone: () => setState(() {
                      _phoneFormOpen = true;
                      _showRecoveryHelp = false;
                    }),
                  ),
                  if (_phoneFormOpen) ...<Widget>[
                    const SizedBox(height: AppSpacing.lg),
                    ParchmentCard(
                      title: l10n.signInWithPhoneTitle,
                      child: Form(
                        key: _form,
                        child: AutofillGroup(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              Text(
                                l10n.signInPhoneRecoveryHint,
                                style: ParchmentText.karla(
                                  size: 12,
                                  color: ParchmentColors.inkMuted(0.7),
                                  height: 1.35,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              MobileNumberField(
                                controller: _mobile,
                                enabled: _busy == null,
                                autofocus: true,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              NameField(
                                controller: _name,
                                enabled: _busy == null,
                                onSubmitted: _phoneSignIn,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              SubmitButton(
                                label: l10n.actionSignIn,
                                busy: _busy == 'phone',
                                onPressed: _phoneSignIn,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (_formError != null) ...<Widget>[
                    const SizedBox(height: AppSpacing.md),
                    ParchmentNoticeBanner(
                      message: _formError!,
                      tone: ParchmentNoticeTone.error,
                      icon: Icons.error_outline_rounded,
                    ),
                  ],
                  if (_showRecoveryHelp || _phoneFormOpen) ...<Widget>[
                    const SizedBox(height: AppSpacing.lg),
                    ParchmentCard(
                      title: l10n.signInRecoveryTitle,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Text(
                            _showRecoveryHelp
                                ? l10n.signInRecoveryBody
                                : l10n.signInRecoveryPrevent,
                            style: ParchmentText.karla(size: 13, height: 1.4),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          ParchmentSecondaryButton(
                            label: l10n.signInNeedHelp,
                            onPressed: () => Navigator.of(context).pushNamed(
                              Routes.support,
                              arguments: const SupportArgs(
                                entrySource: 'M-10_sign_in',
                                presetCategory: 'account',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  TextButton(
                    onPressed: _busy != null
                        ? null
                        : () => Navigator.of(context)
                            .pushReplacementNamed(Routes.phoneSignUp),
                    child: Text(l10n.signInCreateAccountLink),
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
