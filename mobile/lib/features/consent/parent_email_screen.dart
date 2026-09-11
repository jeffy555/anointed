import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/responsive.dart';
import '../../core/routes.dart';
import '../../core/tokens.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../models/consent_status.dart';
import '../../services/consent_repository.dart';
import '../../widgets/form_fields.dart';
import '../../widgets/state_views.dart';
import 'awaiting_email_screen.dart';

/// M-06D Parent email entry (VPC Path B, design-spec §11).
///
/// Sends a signed link valid for 72 hours to the parent's own address. The link
/// itself resolves on a backend web page (M-06F) rather than in the app, so the
/// parent can complete it on their own device.
class ParentEmailScreen extends StatefulWidget {
  const ParentEmailScreen({super.key});

  @override
  State<ParentEmailScreen> createState() => _ParentEmailScreenState();
}

class _ParentEmailScreenState extends State<ParentEmailScreen> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _email = TextEditingController();

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    final AppLocalizations l10n = AppLocalizations.of(context);
    try {
      final ConsentStatus status =
          await context.read<ConsentRepository>().requestParentEmail(_email.text.trim());
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(
        Routes.awaitingEmail,
        arguments: AwaitingEmailArgs(
          maskedEmail: status.parentEmailMasked ?? _email.text.trim(),
          sendCount: status.sendCount,
          expiresAt: status.expiresAt,
          plainEmail: _email.text.trim(),
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.code == 'resend_limit_reached'
            ? l10n.awaitingEmailResendLimit
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
      appBar: AppBar(title: Text(l10n.parentEmailTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ContentColumn(
            maxWidth: 460,
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Icon(
                    Icons.mark_email_read_outlined,
                    size: 56,
                    color: theme.colorScheme.secondary,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(l10n.parentEmailBody, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: AppSpacing.lg),
                  EmailField(
                    controller: _email,
                    label: l10n.parentEmailLabel,
                    enabled: !_busy,
                    autofocus: true,
                    onSubmitted: _send,
                  ),
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
                    label: l10n.parentEmailSend,
                    busy: _busy,
                    onPressed: _send,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => Navigator.of(context)
                            .pushReplacementNamed(Routes.parentOauth),
                    child: Text(l10n.awaitingEmailSwitchToOauth),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
