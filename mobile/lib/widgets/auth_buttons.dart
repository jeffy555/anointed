import 'package:flutter/material.dart';

import '../core/tokens.dart';
import '../l10n/gen/app_localizations.dart';

/// The shared auth button stack from design-spec §10, used by both M-03 and
/// M-10. Icon + text with kid-friendly labels ("Continue with Google", not
/// "OAuth"), all at equal prominence, phone as the outline variant.
class AuthButtonStack extends StatelessWidget {
  const AuthButtonStack({
    super.key,
    required this.onGoogle,
    required this.onApple,
    required this.onPhone,
    required this.showApple,
    this.busyProvider,
    this.googleLabel,
    this.appleLabel,
    this.phoneLabel,
  });

  final VoidCallback onGoogle;
  final VoidCallback onApple;
  final VoidCallback onPhone;

  /// Sign in with Apple is iOS-only in v1 (App Store policy requires it when
  /// Google is offered; it is hidden on Android).
  final bool showApple;

  /// Which button shows a spinner while its provider sheet is open. The others
  /// are disabled, per design-spec §15 M-10 loading row.
  final String? busyProvider;

  final String? googleLabel;
  final String? appleLabel;
  final String? phoneLabel;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool anyBusy = busyProvider != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _AuthButton(
          label: googleLabel ?? l10n.welcomeContinueWithGoogle,
          icon: Icons.g_mobiledata_rounded,
          busy: busyProvider == 'google',
          onPressed: anyBusy ? null : onGoogle,
          style: _AuthButtonStyle.primary,
        ),
        if (showApple) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          _AuthButton(
            label: appleLabel ?? l10n.welcomeContinueWithApple,
            icon: Icons.apple_rounded,
            busy: busyProvider == 'apple',
            onPressed: anyBusy ? null : onApple,
            style: _AuthButtonStyle.secondary,
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        _AuthButton(
          label: phoneLabel ?? l10n.welcomeContinueWithPhone,
          icon: Icons.phone_iphone_rounded,
          busy: busyProvider == 'phone',
          onPressed: anyBusy ? null : onPhone,
          style: _AuthButtonStyle.outline,
        ),
      ],
    );
  }
}

enum _AuthButtonStyle { primary, secondary, outline }

class _AuthButton extends StatelessWidget {
  const _AuthButton({
    required this.label,
    required this.icon,
    required this.busy,
    required this.onPressed,
    required this.style,
  });

  final String label;
  final IconData icon;
  final bool busy;
  final VoidCallback? onPressed;
  final _AuthButtonStyle style;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Widget leading = busy
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: style == _AuthButtonStyle.outline
                  ? theme.colorScheme.secondary
                  : theme.colorScheme.onPrimary,
            ),
          )
        : Icon(icon, size: 22);

    final Widget content = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        leading,
        const SizedBox(width: AppSpacing.sm),
        Flexible(child: Text(label, textAlign: TextAlign.center)),
      ],
    );

    switch (style) {
      case _AuthButtonStyle.primary:
        return _GradientButton(
          onPressed: onPressed,
          gradient: AppColors.primaryButtonGradient,
          shadowColor: AppColors.primary,
          child: content,
        );
      case _AuthButtonStyle.secondary:
        return _GradientButton(
          onPressed: onPressed,
          gradient: AppColors.secondaryButtonGradient,
          shadowColor: AppColors.secondary,
          child: content,
        );
      case _AuthButtonStyle.outline:
        return OutlinedButton(onPressed: onPressed, child: content);
    }
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.onPressed,
    required this.gradient,
    required this.shadowColor,
    required this.child,
  });

  final VoidCallback? onPressed;
  final Gradient gradient;
  final Color shadowColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: AppRadius.cardRadius,
        boxShadow: onPressed == null
            ? null
            : <BoxShadow>[
                BoxShadow(
                  color: shadowColor.withOpacity(0.45),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: AppRadius.cardRadius,
          child: SizedBox(
            height: kMinTapTarget,
            child: DefaultTextStyle.merge(
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: AppTypeScale.md,
              ),
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
  }
}

/// "or" divider between the auth stack and the secondary link.
class OrDivider extends StatelessWidget {
  const OrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Row(
      children: <Widget>[
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(l10n.welcomeOrDivider,
              style: Theme.of(context).textTheme.bodySmall),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}
