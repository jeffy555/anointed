import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/responsive.dart';
import '../../core/tokens.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../models/session.dart';
import '../../state/session_controller.dart';
import '../../widgets/form_fields.dart';
import '../../widgets/state_views.dart';
import 'age_gate.dart';

/// Profile completion for the OAuth paths (design-spec §1B "M-03 → age capture").
///
/// Google and Apple never supply an age, so the account exists but is unusable
/// until this is submitted. The response's `next_step` is the M-05 age-gate
/// verdict, which is why there is no local under-13 branch here.
class ProfileCompletionScreen extends StatefulWidget {
  const ProfileCompletionScreen({super.key});

  @override
  State<ProfileCompletionScreen> createState() => _ProfileCompletionScreenState();
}

class _ProfileCompletionScreenState extends State<ProfileCompletionScreen> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _age = TextEditingController();

  bool _busy = false;
  String? _formError;

  @override
  void initState() {
    super.initState();
    // Prefill from the provider profile when it gave us one, so most users only
    // have to type an age.
    final String? name = context.read<SessionController>().user?.name;
    if (name != null && name.isNotEmpty) _name.text = name;
  }

  @override
  void dispose() {
    _name.dispose();
    _age.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _formError = null);
    if (!(_form.currentState?.validate() ?? false)) return;

    setState(() => _busy = true);
    final AppLocalizations l10n = AppLocalizations.of(context);

    try {
      final OnboardingStep step =
          await context.read<SessionController>().completeProfile(
                name: _name.text.trim(),
                age: int.parse(_age.text.trim()),
              );
      if (!mounted) return;
      goToStep(context, step);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _formError = error.isOffline ? l10n.errorOfflineBody : error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);

    return PopScope(
      // Onboarding is forward-only: backing out would leave an account with no
      // age, which the server treats as unusable.
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.profileCompletionTitle),
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            child: ContentColumn(
              maxWidth: 440,
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      l10n.profileCompletionSubhead,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    NameField(controller: _name, enabled: !_busy),
                    const SizedBox(height: AppSpacing.md),
                    AgeField(
                      controller: _age,
                      enabled: !_busy,
                      onSubmitted: _submit,
                    ),
                    if (_formError != null) ...<Widget>[
                      const SizedBox(height: AppSpacing.md),
                      NoticeBanner(
                        message: _formError!,
                        tone: NoticeTone.error,
                        icon: Icons.error_outline_rounded,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    SubmitButton(
                      label: l10n.actionContinue,
                      busy: _busy,
                      onPressed: _submit,
                    ),
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
