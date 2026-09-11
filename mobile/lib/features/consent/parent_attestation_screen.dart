import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/link_launcher.dart';
import '../../core/responsive.dart';
import '../../core/routes.dart';
import '../../core/tokens.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../models/account.dart';
import '../../models/consent_status.dart';
import '../../services/account_repository.dart';
import '../../services/oauth_provider_service.dart';
import '../../widgets/form_fields.dart';
import '../../widgets/state_views.dart';
import 'child_profile_screen.dart';

class AttestationArgs {
  const AttestationArgs({this.parentCredential});

  /// Present when arriving from M-06A. Absent only if the route is entered
  /// directly, in which case the screen sends the parent back to M-06A rather
  /// than collecting an attestation it could not submit.
  final OAuthCredential? parentCredential;
}

/// M-06B Parent attestation (VPC Path A, design-spec §11).
///
/// Two separate affirmations are required — "I am the parent or guardian" and
/// "I consent to the collection and use of my child's information" — because a
/// single combined checkbox is not a meaningful attestation. Both are unchecked
/// by default and the submit button stays disabled until both are ticked.
class ParentAttestationScreen extends StatefulWidget {
  const ParentAttestationScreen({super.key, required this.args});

  final AttestationArgs args;

  @override
  State<ParentAttestationScreen> createState() => _ParentAttestationScreenState();
}

class _ParentAttestationScreenState extends State<ParentAttestationScreen> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _guardianName = TextEditingController();

  ParentRelationship _relationship = ParentRelationship.parent;
  bool _isGuardian = false;
  bool _consents = false;
  String? _privacyUrl;
  String? _linkError;

  @override
  void initState() {
    super.initState();
    final String? providerName = widget.args.parentCredential?.name;
    if (providerName != null && providerName.trim().isNotEmpty) {
      _guardianName.text = providerName.trim();
    }
    _loadPolicyUrl();
  }

  @override
  void dispose() {
    _guardianName.dispose();
    super.dispose();
  }

  /// Privacy Policy link opens the URL from the backend profile. Attestation wording
  /// is COPPA-oriented draft copy — counsel must finalise before US launch (C-10).
  Future<void> _loadPolicyUrl() async {
    try {
      final UserProfile profile = await context.read<AccountRepository>().profile();
      if (!mounted) return;
      setState(() => _privacyUrl = profile.privacyPolicyUrl);
    } on Object {
      // The link is a secondary action; the form is still usable without it and
      // the cached profile below covers the common case.
      final UserProfile? cached = context.read<AccountRepository>().cachedProfile();
      if (!mounted || cached == null) return;
      setState(() => _privacyUrl = cached.privacyPolicyUrl);
    }
  }

  Future<void> _openPrivacy() async {
    final bool opened = await LinkLauncher.open(_privacyUrl ?? '');
    if (!mounted) return;
    setState(() {
      _linkError = opened ? null : AppLocalizations.of(context).privacyLinkUnavailable;
    });
  }

  void _continue() {
    if (!(_form.currentState?.validate() ?? false)) return;
    final OAuthCredential? credential = widget.args.parentCredential;
    if (credential == null) {
      Navigator.of(context).pushReplacementNamed(Routes.parentOauth);
      return;
    }
    Navigator.of(context).pushNamed(
      Routes.childProfile,
      arguments: ChildProfileArgs(
        parentCredential: credential,
        guardianName: _guardianName.text.trim(),
        relationship: _relationship,
        isParentOrGuardian: _isGuardian,
        consentsToDataUse: _consents,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final bool bothTicked = _isGuardian && _consents;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.attestationTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ContentColumn(
            maxWidth: 520,
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  TextFormField(
                    controller: _guardianName,
                    textCapitalization: TextCapitalization.words,
                    inputFormatters: <TextInputFormatter>[
                      LengthLimitingTextInputFormatter(160),
                    ],
                    decoration: InputDecoration(
                      labelText: l10n.attestationGuardianNameLabel,
                      prefixIcon: const Icon(Icons.badge_outlined),
                    ),
                    // Two characters mirrors the server's own minimum so the
                    // parent is not bounced by a 400 after submitting.
                    validator: (String? value) =>
                        (value ?? '').trim().length < 2
                            ? l10n.attestationGuardianNameRequired
                            : null,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    l10n.attestationRelationshipLabel,
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SegmentedButton<ParentRelationship>(
                    segments: <ButtonSegment<ParentRelationship>>[
                      ButtonSegment<ParentRelationship>(
                        value: ParentRelationship.parent,
                        label: Text(l10n.relationshipParent),
                      ),
                      ButtonSegment<ParentRelationship>(
                        value: ParentRelationship.guardian,
                        label: Text(l10n.relationshipGuardian),
                      ),
                      ButtonSegment<ParentRelationship>(
                        value: ParentRelationship.other,
                        label: Text(l10n.relationshipOther),
                      ),
                    ],
                    selected: <ParentRelationship>{_relationship},
                    onSelectionChanged: (Set<ParentRelationship> selection) =>
                        setState(() => _relationship = selection.first),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  CheckboxListTile(
                    value: _isGuardian,
                    onChanged: (bool? value) =>
                        setState(() => _isGuardian = value ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.attestationIsGuardianCheckbox),
                  ),
                  CheckboxListTile(
                    value: _consents,
                    onChanged: (bool? value) =>
                        setState(() => _consents = value ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.attestationConsentCheckbox),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _openPrivacy,
                      icon: const Icon(Icons.open_in_new_rounded, size: 18),
                      label: Text(l10n.attestationPrivacyLink),
                    ),
                  ),
                  if (_linkError != null)
                    NoticeBanner(
                      message: _linkError!,
                      tone: NoticeTone.warning,
                      icon: Icons.link_off_rounded,
                    ),
                  if (!bothTicked) ...<Widget>[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      l10n.attestationIncomplete,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  SubmitButton(
                    label: l10n.actionContinue,
                    onPressed: bothTicked ? _continue : null,
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
