import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/responsive.dart';
import '../../core/routes.dart';
import '../../core/tokens.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../models/consent_status.dart';
import '../../models/session.dart';
import '../../services/analytics_service.dart';
import '../../services/consent_repository.dart';
import '../../state/session_controller.dart';
import '../../widgets/state_views.dart';
import '../auth/age_gate.dart';
import 'awaiting_email_screen.dart';

/// M-06 Parent gate (design-spec §11).
///
/// A hard block for an under-13 account: no skip, no back, and gameplay stays
/// unreachable until the server reports `consented`. The screen's only job is to
/// hand the device to an adult and let them pick Path A or Path B.
class ParentGateScreen extends StatefulWidget {
  const ParentGateScreen({super.key});

  @override
  State<ParentGateScreen> createState() => _ParentGateScreenState();
}

class _ParentGateScreenState extends State<ParentGateScreen> {
  ConsentStatus? _status;
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final SessionUser? user = context.read<SessionController>().user;
      context.read<AnalyticsService>().track(
        'vpc_parent_gate_viewed',
        properties: <String, Object?>{
          'auth_method': user?.primaryAuthProvider ?? 'phone',
        },
      );
    });
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final ConsentStatus status = await context.read<ConsentRepository>().status();
      if (!mounted) return;

      // Already granted while the app was closed (parent used the emailed link on
      // their own device): skip straight to whatever comes next.
      if (status.isVerified) {
        goToStep(context, status.nextStep);
        return;
      }
      setState(() {
        _status = status;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = error.isOffline ? null : error.message;
      });
    }
  }

  void _selectPath(ConsentMethod method) {
    final SessionUser? user = context.read<SessionController>().user;
    context.read<AnalyticsService>().track(
      'vpc_path_selected',
      properties: <String, Object?>{
        'vpc_path': method.wireValue,
        'auth_method': user?.primaryAuthProvider ?? 'phone',
      },
    );

    switch (method) {
      case ConsentMethod.oauthParentAttestation:
        Navigator.of(context).pushNamed(Routes.parentOauth);
      case ConsentMethod.emailPlusConfirmation:
        Navigator.of(context).pushNamed(Routes.parentEmail);
    }
  }

  /// A Path B record that is still pending: the parent may simply not have opened
  /// the email yet, so offer to go back to the wait screen instead of forcing a
  /// second send.
  void _resumePendingEmail(ConsentStatus status) {
    Navigator.of(context).pushNamed(
      Routes.awaitingEmail,
      arguments: AwaitingEmailArgs(
        maskedEmail: status.parentEmailMasked ?? '',
        sendCount: status.sendCount,
        expiresAt: status.expiresAt,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final ConsentStatus? status = _status;

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.parentGateTitle),
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(
          child: _loading
              ? const LoadingView()
              : SingleChildScrollView(
                  child: ContentColumn(
                    maxWidth: 520,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Icon(
                          Icons.family_restroom_rounded,
                          size: 56,
                          color: theme.colorScheme.secondary,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text(l10n.parentGateBody, style: theme.textTheme.bodyLarge),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          l10n.parentGateNoSkipNote,
                          style: theme.textTheme.bodySmall,
                        ),
                        if (_loadError != null) ...<Widget>[
                          const SizedBox(height: AppSpacing.md),
                          NoticeBanner(
                            message: _loadError!,
                            tone: NoticeTone.warning,
                            actionLabel: l10n.actionRetry,
                            onAction: _load,
                          ),
                        ],
                        if (status?.consentStatus == ConsentRecordStatus.expired) ...<Widget>[
                          const SizedBox(height: AppSpacing.md),
                          NoticeBanner(
                            message: l10n.parentGateStatusExpired,
                            tone: NoticeTone.warning,
                            icon: Icons.schedule_rounded,
                          ),
                        ],
                        if (status?.consentStatus == ConsentRecordStatus.denied) ...<Widget>[
                          const SizedBox(height: AppSpacing.md),
                          NoticeBanner(
                            message: l10n.parentGateStatusDenied,
                            tone: NoticeTone.error,
                            icon: Icons.block_rounded,
                          ),
                        ],
                        if (status != null &&
                            status.consentStatus == ConsentRecordStatus.pending &&
                            status.method == ConsentMethod.emailPlusConfirmation &&
                            (status.parentEmailMasked ?? '').isNotEmpty) ...<Widget>[
                          const SizedBox(height: AppSpacing.md),
                          NoticeBanner(
                            message: l10n.awaitingEmailBody(status.parentEmailMasked!),
                            tone: NoticeTone.info,
                            icon: Icons.mark_email_unread_outlined,
                            actionLabel: l10n.actionContinue,
                            onAction: () => _resumePendingEmail(status),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.xl),
                        _PathCard(
                          title: l10n.parentGatePathATitle,
                          body: l10n.parentGatePathABody,
                          icon: Icons.verified_user_outlined,
                          recommended: true,
                          onTap: () => _selectPath(ConsentMethod.oauthParentAttestation),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _PathCard(
                          title: l10n.parentGatePathBTitle,
                          body: l10n.parentGatePathBBody,
                          icon: Icons.mail_outline_rounded,
                          recommended: false,
                          onTap: () => _selectPath(ConsentMethod.emailPlusConfirmation),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _PathCard extends StatelessWidget {
  const _PathCard({
    required this.title,
    required this.body,
    required this.icon,
    required this.recommended,
    required this.onTap,
  });

  final String title;
  final String body;
  final IconData icon;
  final bool recommended;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.cardRadius,
        child: Container(
          constraints: const BoxConstraints(minHeight: kMinTapTarget),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: AppRadius.cardRadius,
            border: recommended
                ? Border.all(color: theme.colorScheme.primary, width: 2)
                : null,
          ),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 28, color: theme.colorScheme.primary),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.xs),
                    Text(body, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
