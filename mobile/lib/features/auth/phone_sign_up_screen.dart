import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/responsive.dart';
import '../../core/routes.dart';
import '../../core/tokens.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../models/session.dart';
import '../../state/session_controller.dart';
import '../../widgets/form_fields.dart';
import '../../widgets/state_views.dart';
import 'age_gate.dart';

/// M-04 Phone sign-up (design-spec §10 / §9).
///
/// No OTP in v1: mobile + name + age creates the account directly. Age is
/// captured here rather than after, because the server's response to this call
/// *is* the age-gate decision.
class PhoneSignUpScreen extends StatefulWidget {
  const PhoneSignUpScreen({super.key});

  @override
  State<PhoneSignUpScreen> createState() => _PhoneSignUpScreenState();
}

class _PhoneSignUpScreenState extends State<PhoneSignUpScreen> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _mobile = TextEditingController();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _age = TextEditingController();

  bool _busy = false;
  String? _formError;
  Map<String, String> _fieldErrors = const <String, String>{};

  @override
  void dispose() {
    _mobile.dispose();
    _name.dispose();
    _age.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _formError = null;
      _fieldErrors = const <String, String>{};
    });
    if (!(_form.currentState?.validate() ?? false)) return;

    setState(() => _busy = true);

    final AppLocalizations l10n = AppLocalizations.of(context);
    try {
      final OnboardingStep step = await context.read<SessionController>().phoneSignUp(
            mobile: _mobile.text,
            name: _name.text.trim(),
            age: int.parse(_age.text.trim()),
          );
      if (!mounted) return;
      goToStep(context, step);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _fieldErrors = error.fields;
        // 409 here means the same mobile + name already exists, which is a real
        // account the user should sign in to rather than a validation problem.
        _formError = error.statusCode == 409
            ? l10n.phoneSignUpAccountExists
            : error.isOffline
                ? l10n.errorOfflineBody
                : error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.phoneSignUpTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ContentColumn(
            maxWidth: 440,
            child: Form(
              key: _form,
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(l10n.phoneSignUpSubhead, style: theme.textTheme.bodyMedium),
                    const SizedBox(height: AppSpacing.lg),
                    MobileNumberField(
                      controller: _mobile,
                      enabled: !_busy,
                      autofocus: true,
                      errorText: _fieldErrors['mobile'],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    NameField(
                      controller: _name,
                      enabled: !_busy,
                      errorText: _fieldErrors['name'],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AgeField(
                      controller: _age,
                      enabled: !_busy,
                      errorText: _fieldErrors['age'],
                      onSubmitted: _submit,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      l10n.profileCompletionSubhead,
                      style: theme.textTheme.bodySmall,
                    ),
                    if (_formError != null) ...<Widget>[
                      const SizedBox(height: AppSpacing.md),
                      NoticeBanner(
                        message: _formError!,
                        tone: NoticeTone.error,
                        icon: Icons.error_outline_rounded,
                        actionLabel: l10n.actionSignIn,
                        onAction: () =>
                            Navigator.of(context).pushReplacementNamed(Routes.signIn),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    SubmitButton(
                      label: l10n.phoneSignUpCreateAction,
                      busy: _busy,
                      onPressed: _submit,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
