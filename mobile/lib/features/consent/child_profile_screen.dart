import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/responsive.dart';
import '../../core/tokens.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../models/consent_status.dart';
import '../../models/session.dart';
import '../../services/consent_repository.dart';
import '../../services/oauth_provider_service.dart';
import '../../state/session_controller.dart';
import '../../widgets/form_fields.dart';
import '../../widgets/state_views.dart';
import '../auth/age_gate.dart';

class ChildProfileArgs {
  const ChildProfileArgs({
    required this.parentCredential,
    required this.guardianName,
    required this.relationship,
    required this.isParentOrGuardian,
    required this.consentsToDataUse,
  });

  final OAuthCredential parentCredential;
  final String guardianName;
  final ParentRelationship relationship;
  final bool isParentOrGuardian;
  final bool consentsToDataUse;
}

/// M-06C Child profile setup (VPC Path A, design-spec §11).
///
/// The last step of Path A and the one that actually submits: parent OAuth token,
/// attestation, and child profile go to the server in a single request so the
/// consent record cannot end up half-written.
class ChildProfileScreen extends StatefulWidget {
  const ChildProfileScreen({super.key, required this.args});

  final ChildProfileArgs args;

  @override
  State<ChildProfileScreen> createState() => _ChildProfileScreenState();
}

class _ChildProfileScreenState extends State<ChildProfileScreen> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _displayName = TextEditingController();
  final TextEditingController _mobile = TextEditingController();

  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final String? existing = context.read<SessionController>().user?.name;
    if (existing != null && existing.isNotEmpty) _displayName.text = existing;
  }

  @override
  void dispose() {
    _displayName.dispose();
    _mobile.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    final AppLocalizations l10n = AppLocalizations.of(context);
    final ChildProfileArgs args = widget.args;

    try {
      final SessionState state =
          await context.read<ConsentRepository>().completeParentOAuth(
                parentCredential: args.parentCredential,
                parentGuardianName: args.guardianName,
                relationship: args.relationship,
                isParentOrGuardian: args.isParentOrGuardian,
                consentsToDataUse: args.consentsToDataUse,
                childDisplayName: _displayName.text.trim(),
                childMobile: _mobile.text.trim(),
              );
      if (!mounted) return;
      context.read<SessionController>().applySessionState(state);
      goToStep(context, state.nextStep);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        // The one error worth its own copy: the parent signed in with the child's
        // own account, which the server rejects outright.
        _error = error.code == 'parent_account_same_as_child'
            ? l10n.parentOauthSameAccountError
            : error.code == 'attestation_incomplete'
                ? l10n.attestationIncomplete
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
    final int? age = context.read<SessionController>().user?.age;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.childProfileTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ContentColumn(
            maxWidth: 480,
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  NameField(
                    controller: _displayName,
                    label: l10n.childProfileNameLabel,
                    enabled: !_busy,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  // Optional: an under-13 account created through a parent's
                  // Google/Apple sign-in has no mobile number of its own, and the
                  // server only stores one if the field is left blank today.
                  TextFormField(
                    controller: _mobile,
                    enabled: !_busy,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: l10n.childProfileMobileLabel,
                      prefixIcon: const Icon(Icons.phone_rounded),
                    ),
                    validator: (String? value) {
                      final String raw = (value ?? '').trim();
                      if (raw.isEmpty) return null;
                      return MobileNumberField.isValid(raw)
                          ? null
                          : l10n.fieldMobileInvalid;
                    },
                  ),
                  if (age != null) ...<Widget>[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      l10n.childProfileAgeReadOnly(age),
                      style: theme.textTheme.bodySmall,
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
                    label: l10n.childProfileSubmit,
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
    );
  }
}
