import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/config.dart';
import '../../core/responsive.dart';
import '../../core/routes.dart';
import '../../core/tokens.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../models/consent_status.dart';
import '../../services/consent_repository.dart';
import '../../widgets/state_views.dart';
import '../auth/age_gate.dart';

class AwaitingEmailArgs {
  const AwaitingEmailArgs({
    required this.maskedEmail,
    required this.sendCount,
    this.expiresAt,
    this.plainEmail,
  });

  final String maskedEmail;
  final int sendCount;
  final DateTime? expiresAt;

  /// The unmasked address, available only when this screen was reached straight
  /// from M-06D. Resuming a pending record from M-06 has just the masked form, so
  /// "Resend" there has to go back through M-06D to re-confirm the address.
  final String? plainEmail;
}

/// M-06E Awaiting parent email confirmation (VPC Path B, design-spec §11).
///
/// Polls `GET /v1/consent/status` every 5 seconds until the parent approves on
/// the backend web page. Polling is used rather than push because v1 has no FCM
/// and the wait is bounded by the screen being open.
class AwaitingEmailScreen extends StatefulWidget {
  const AwaitingEmailScreen({super.key, required this.args});

  final AwaitingEmailArgs args;

  @override
  State<AwaitingEmailScreen> createState() => _AwaitingEmailScreenState();
}

class _AwaitingEmailScreenState extends State<AwaitingEmailScreen> {
  Timer? _poll;
  Timer? _cooldownTick;

  late String _maskedEmail = widget.args.maskedEmail;
  late DateTime? _expiresAt = widget.args.expiresAt;
  int _resendCooldown = 0;
  bool _resending = false;
  String? _notice;
  String? _error;

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(AppConfig.consentPollInterval, (_) => _check());
    _cooldownTick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_resendCooldown <= 0) return;
      setState(() => _resendCooldown -= 1);
    });
    _check();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _cooldownTick?.cancel();
    super.dispose();
  }

  Future<void> _check() async {
    try {
      final ConsentStatus status = await context.read<ConsentRepository>().status();
      if (!mounted) return;

      if (status.isVerified) {
        _poll?.cancel();
        goToStep(context, status.nextStep);
        return;
      }

      setState(() {
        _error = null;
        _resendCooldown = status.resendCooldownSeconds;
        if ((status.parentEmailMasked ?? '').isNotEmpty) {
          _maskedEmail = status.parentEmailMasked!;
        }
        _expiresAt = status.expiresAt ?? _expiresAt;
      });

      // A record that expired or was declined cannot be recovered from here; the
      // parent gate is where a fresh attempt starts.
      if (status.consentStatus == ConsentRecordStatus.expired ||
          status.consentStatus == ConsentRecordStatus.denied) {
        _poll?.cancel();
        if (!mounted) return;
        Navigator.of(context).pushNamedAndRemoveUntil(
          Routes.parentGate,
          (Route<dynamic> route) => false,
        );
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      // Keep polling through a transient failure: the parent may approve at any
      // moment and a single failed poll is not a reason to stop waiting.
      setState(() {
        _error = error.isOffline
            ? AppLocalizations.of(context).errorOfflineBody
            : error.message;
      });
    }
  }

  Future<void> _resend() async {
    final String? address = widget.args.plainEmail;
    if (address == null || address.isEmpty) {
      Navigator.of(context).pushReplacementNamed(Routes.parentEmail);
      return;
    }

    setState(() {
      _resending = true;
      _notice = null;
      _error = null;
    });

    final AppLocalizations l10n = AppLocalizations.of(context);
    try {
      final ConsentStatus status =
          await context.read<ConsentRepository>().requestParentEmail(address);
      if (!mounted) return;
      setState(() {
        _resending = false;
        _notice = l10n.awaitingEmailResendSent;
        _resendCooldown = status.resendCooldownSeconds;
        _expiresAt = status.expiresAt ?? _expiresAt;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _resending = false;
        _resendCooldown = error.retryAfter?.inSeconds ?? _resendCooldown;
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
      appBar: AppBar(title: Text(l10n.awaitingEmailTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ContentColumn(
            maxWidth: 480,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const SizedBox(height: AppSpacing.lg),
                Center(
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: CircularProgressIndicator(
                      strokeWidth: 4,
                      color: theme.colorScheme.secondary,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    l10n.awaitingEmailChecking,
                    style: theme.textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  l10n.awaitingEmailBody(_maskedEmail),
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                if (_expiresAt != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    l10n.awaitingEmailExpiresAt(
                      DateFormat.yMMMd().add_jm().format(_expiresAt!.toLocal()),
                    ),
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
                if (_notice != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  NoticeBanner(message: _notice!, tone: NoticeTone.success),
                ],
                if (_error != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  NoticeBanner(
                    message: _error!,
                    tone: NoticeTone.warning,
                    icon: Icons.sync_problem_rounded,
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                OutlinedButton(
                  onPressed: _resending || _resendCooldown > 0 ? null : _resend,
                  child: Text(
                    _resendCooldown > 0
                        ? l10n.awaitingEmailResendIn(_resendCooldown)
                        : l10n.awaitingEmailResend,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextButton(
                  onPressed: () =>
                      Navigator.of(context).pushReplacementNamed(Routes.parentOauth),
                  child: Text(l10n.awaitingEmailSwitchToOauth),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
