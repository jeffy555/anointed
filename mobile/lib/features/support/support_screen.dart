import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/config.dart';
import '../../core/device_context.dart';
import '../../core/link_launcher.dart';
import '../../core/responsive.dart';
import '../../core/routes.dart';
import '../../core/tokens.dart';
import '../../features/map/parchment_codex_tokens.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../models/account.dart';
import '../../services/account_repository.dart';
import '../../widgets/form_fields.dart';
import '../../widgets/parchment_ui.dart';
import '../../widgets/state_views.dart';

/// A support category. The wire value is stable and untranslated so operators
/// and the admin queue see one consistent label regardless of the app's locale;
/// only the display label goes through ARB.
enum SupportCategory {
  general('general'),
  account('account'),
  purchase('purchase'),
  gameplay('gameplay'),
  privacy('privacy');

  const SupportCategory(this.wireValue);

  final String wireValue;

  static SupportCategory parse(String? raw) => SupportCategory.values.firstWhere(
        (SupportCategory value) => value.wireValue == raw,
        orElse: () => SupportCategory.general,
      );

  String label(AppLocalizations l10n) {
    switch (this) {
      case SupportCategory.general:
        return l10n.supportCategoryGeneral;
      case SupportCategory.account:
        return l10n.supportCategoryAccount;
      case SupportCategory.purchase:
        return l10n.supportCategoryPurchase;
      case SupportCategory.gameplay:
        return l10n.supportCategoryGameplay;
      case SupportCategory.privacy:
        return l10n.supportCategoryPrivacy;
    }
  }
}

/// M-31 Support (design-spec §1F, §14).
///
/// FAQ accordion plus a contact form. Both `/v1/account/faq` and
/// `/v1/account/support` require a session, so the screen has a genuine
/// unauthenticated path: design-spec §14 links here from M-10 precisely when a
/// user cannot sign in, and in that case the only useful thing to offer is a
/// direct mail link.
///
/// `support_faq_viewed` and `support_contact_sent` are both emitted server-side
/// by those endpoints, so this screen emits neither.
class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key, required this.args});

  final SupportArgs args;

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _message = TextEditingController();
  final TextEditingController _replyTo = TextEditingController();

  FaqBundle? _faq;
  bool _loading = true;
  String? _loadError;
  bool _needsSignIn = false;
  bool _sending = false;
  bool _sent = false;
  late SupportCategory _category;

  @override
  void initState() {
    super.initState();
    _category = SupportCategory.parse(widget.args.presetCategory);
    _loadFaq();
  }

  @override
  void dispose() {
    _message.dispose();
    _replyTo.dispose();
    super.dispose();
  }

  String get _supportEmail {
    final String fromServer = _faq?.supportEmail ?? '';
    return fromServer.isEmpty ? AppConfig.fallbackSupportEmail : fromServer;
  }

  Future<void> _loadFaq() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final FaqBundle faq = await context.read<AccountRepository>().faq();
      if (!mounted) return;
      setState(() {
        _faq = faq;
        _loading = false;
        _needsSignIn = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _needsSignIn = error.isUnauthorized;
        _loadError = error.isOffline
            ? AppLocalizations.of(context).errorOfflineBody
            : error.message;
      });
    }
  }

  Future<void> _send() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _sending = true);
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String replyTo = _replyTo.text.trim();

    try {
      await context.read<AccountRepository>().submitSupportRequest(
            subjectCategory: _category.wireValue,
            message: _message.text.trim(),
            replyTo: replyTo.isEmpty ? null : replyTo,
            entrySource: widget.args.entrySource,
          );
      if (!mounted) return;
      setState(() {
        _sending = false;
        _sent = true;
      });
      _message.clear();
      showAppSnack(context, l10n.supportSendSuccess);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _needsSignIn = error.isUnauthorized;
      });
      // The mail fallback is the actionable part of this failure, so it goes in
      // the message rather than a bare "try again".
      showAppSnack(context, l10n.supportSendFailed(_supportEmail));
    }
  }

  Future<void> _mailDirect() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final DeviceContext device = context.read<DeviceContext>();
    final bool opened = await LinkLauncher.email(
      address: _supportEmail,
      subject: '[Anointed] ${_category.wireValue}',
      body: '\n\n---\n'
          'App version: ${device.appVersion} (${device.buildNumber})\n'
          'Platform: ${device.platform}\n'
          'Entry: ${widget.args.entrySource}\n',
    );
    if (!opened && mounted) {
      showAppSnack(context, l10n.supportEmailCopyHint(_supportEmail));
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final DeviceContext device = context.read<DeviceContext>();

    if (_loading) {
      return ColoredBox(
        color: ParchmentColors.page,
        child: Scaffold(
          backgroundColor: ParchmentColors.page,
          body: Column(
            children: <Widget>[
              ParchmentScreenHeader(eyebrow: 'ANOINTED', title: l10n.supportTitle),
              const Expanded(child: LoadingView()),
            ],
          ),
        ),
      );
    }

    return ColoredBox(
      color: ParchmentColors.page,
      child: Scaffold(
        backgroundColor: ParchmentColors.page,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ParchmentScreenHeader(eyebrow: 'ANOINTED', title: l10n.supportTitle),
            Expanded(
              child: ListView(
                padding: Layout.pagePadding(context),
                children: <Widget>[
          if (_needsSignIn)
            ParchmentNoticeBanner(
              message: l10n.supportSignInRequired,
              tone: ParchmentNoticeTone.info,
              icon: Icons.mail_outline_rounded,
              actionLabel: l10n.supportEmailUsAction,
              onAction: _mailDirect,
            )
          else if (_loadError != null)
            ParchmentNoticeBanner(
              message: _loadError!,
              tone: ParchmentNoticeTone.warning,
              actionLabel: l10n.actionRetry,
              onAction: _loadFaq,
            ),
          if (_needsSignIn || _loadError != null)
            const SizedBox(height: AppSpacing.lg),

          if (!_needsSignIn) ...<Widget>[
            Text(
              l10n.supportFaqHeading,
              style: ParchmentText.cormorant(size: 20),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (_faq == null || _faq!.items.isEmpty)
              Text(
                l10n.supportFaqEmpty,
                style: ParchmentText.karla(size: 14),
              )
            else
              // Grouped by the server's own categories so the accordion headings
              // stay in step with whatever the backend publishes.
              for (final MapEntry<String, List<FaqItem>> group
                  in _faq!.byCategory.entries) ...<Widget>[
                Padding(
                  padding: const EdgeInsets.only(
                    top: AppSpacing.md,
                    bottom: AppSpacing.xs,
                  ),
                  child: Text(
                    group.key,
                    style: ParchmentText.karla(
                      size: 12,
                      weight: FontWeight.w700,
                      color: ParchmentColors.brown,
                    ),
                  ),
                ),
                ParchmentCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: <Widget>[
                      for (final FaqItem item in group.value)
                        ExpansionTile(
                          title: Text(
                            item.question,
                            style: ParchmentText.karla(
                              size: 14,
                              weight: FontWeight.w600,
                            ),
                          ),
                          childrenPadding: const EdgeInsets.fromLTRB(
                            AppSpacing.md,
                            0,
                            AppSpacing.md,
                            AppSpacing.md,
                          ),
                          expandedAlignment: Alignment.topLeft,
                          expandedCrossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              item.answer,
                              style: ParchmentText.karla(size: 13, height: 1.4),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            const SizedBox(height: AppSpacing.xl),
          ],

          Text(
            l10n.supportContactHeading,
            style: ParchmentText.cormorant(size: 20),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.supportContactSubhead,
            style: ParchmentText.karla(
              size: 12,
              color: ParchmentColors.inkMuted(),
              height: 1.35,
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          if (_needsSignIn)
            ParchmentSecondaryButton(
              label: l10n.supportEmailUsAction,
              onPressed: _mailDirect,
            )
          else
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  DropdownButtonFormField<SupportCategory>(
                    value: _category,
                    decoration: InputDecoration(
                      labelText: l10n.supportCategoryLabel,
                    ),
                    items: SupportCategory.values
                        .map(
                          (SupportCategory value) =>
                              DropdownMenuItem<SupportCategory>(
                            value: value,
                            child: Text(value.label(l10n)),
                          ),
                        )
                        .toList(),
                    onChanged: _sending
                        ? null
                        : (SupportCategory? value) => setState(
                              () => _category = value ?? SupportCategory.general,
                            ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _message,
                    enabled: !_sending,
                    maxLines: 5,
                    maxLength: 4000,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: l10n.supportMessageLabel,
                      alignLabelWithHint: true,
                    ),
                    // 5 characters is the server's floor; 10 is ours, because a
                    // three-word report is not actionable.
                    validator: (String? value) =>
                        (value ?? '').trim().length < 10
                            ? l10n.supportMessageRequired
                            : null,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  EmailField(
                    controller: _replyTo,
                    label: l10n.supportReplyToLabel,
                    enabled: !_sending,
                    required: false,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SubmitButton(
                    label: l10n.supportSendAction,
                    icon: Icons.send_rounded,
                    busy: _sending,
                    onPressed: _send,
                  ),
                  if (_sent) ...<Widget>[
                    const SizedBox(height: AppSpacing.md),
                    ParchmentNoticeBanner(
                      message: l10n.supportSendSuccess,
                      tone: ParchmentNoticeTone.success,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  TextButton.icon(
                    onPressed: _sending ? null : _mailDirect,
                    icon: const Icon(Icons.mail_outline_rounded, size: 18),
                    label: Text(l10n.supportEmailUsAction),
                  ),
                ],
              ),
            ),

          const SizedBox(height: AppSpacing.lg),
          Center(
            child: Text(
              l10n.settingsAppVersion(device.appVersion, device.buildNumber),
              style: ParchmentText.karla(
                size: 11,
                color: ParchmentColors.inkMuted(),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
