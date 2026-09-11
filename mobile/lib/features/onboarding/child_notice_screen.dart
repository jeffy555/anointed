import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/responsive.dart';
import '../../core/tokens.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../models/session.dart';
import '../../services/consent_repository.dart';
import '../../state/session_controller.dart';
import '../../widgets/form_fields.dart';
import '../../widgets/state_views.dart';
import '../auth/age_gate.dart';

/// M-07 Child privacy notice (design-spec §11 / COPPA direct notice).
///
/// Shown only once parental consent is verified. The copy is deliberately plain
/// language a child can read, and it is a required acknowledgment rather than an
/// informational screen — the server will not advance past it otherwise.
class ChildNoticeScreen extends StatefulWidget {
  const ChildNoticeScreen({super.key});

  @override
  State<ChildNoticeScreen> createState() => _ChildNoticeScreenState();
}

class _ChildNoticeScreenState extends State<ChildNoticeScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _acknowledge() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    final AppLocalizations l10n = AppLocalizations.of(context);
    try {
      // `acknowledged_by: parent` is the honest default: this screen appears
      // immediately after a parent has just completed the VPC flow on this
      // device. analytics-spec §4 calls it a best-effort UI signal.
      final SessionState state = await context
          .read<ConsentRepository>()
          .acknowledgeChildNotice(acknowledgedBy: 'parent');
      if (!mounted) return;
      context.read<SessionController>().applySessionState(state);
      goToStep(context, state.nextStep);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.isOffline ? l10n.errorOfflineBody : error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);

    final List<(IconData, String)> items = <(IconData, String)>[
      (Icons.badge_outlined, l10n.childNoticeItemName),
      (Icons.cake_outlined, l10n.childNoticeItemAge),
      (Icons.emoji_events_outlined, l10n.childNoticeItemProgress),
      (Icons.block_rounded, l10n.childNoticeItemNoAds),
      (Icons.delete_outline_rounded, l10n.childNoticeItemDelete),
    ];

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.childNoticeTitle),
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            child: ContentColumn(
              maxWidth: 520,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(l10n.childNoticeIntro, style: theme.textTheme.bodyLarge),
                  const SizedBox(height: AppSpacing.lg),
                  for (final (IconData icon, String text) in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Icon(icon, size: 22, color: theme.colorScheme.secondary),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(text, style: theme.textTheme.bodyMedium),
                          ),
                        ],
                      ),
                    ),
                  if (_error != null) ...<Widget>[
                    const SizedBox(height: AppSpacing.sm),
                    NoticeBanner(
                      message: _error!,
                      tone: NoticeTone.error,
                      icon: Icons.error_outline_rounded,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  SubmitButton(
                    label: l10n.childNoticeAcknowledge,
                    busy: _busy,
                    onPressed: _acknowledge,
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
