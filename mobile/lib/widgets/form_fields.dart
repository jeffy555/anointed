import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/gen/app_localizations.dart';

/// Mobile number field.
///
/// The backend normalises to digits only and matches sign-in on that normalised
/// value (see backend `_clean_mobile`), so the keyboard and the input formatter
/// here restrict input to digits rather than accepting `+`/spaces that would be
/// silently stripped later. 6–15 digits mirrors the server's own bounds.
class MobileNumberField extends StatelessWidget {
  const MobileNumberField({
    super.key,
    required this.controller,
    this.label,
    this.errorText,
    this.enabled = true,
    this.autofocus = false,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String? label;
  final String? errorText;
  final bool enabled;
  final bool autofocus;
  final VoidCallback? onSubmitted;

  static bool isValid(String raw) {
    final String digits = raw.replaceAll(RegExp(r'\D'), '');
    return digits.length >= 6 && digits.length <= 15;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return TextFormField(
      controller: controller,
      enabled: enabled,
      autofocus: autofocus,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.next,
      autofillHints: const <String>[AutofillHints.telephoneNumber],
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(15),
      ],
      decoration: InputDecoration(
        labelText: label ?? l10n.fieldMobileLabel,
        hintText: l10n.fieldMobileHint,
        errorText: errorText,
        prefixIcon: const Icon(Icons.phone_rounded),
      ),
      validator: (String? value) =>
          isValid(value ?? '') ? null : l10n.fieldMobileInvalid,
      onFieldSubmitted: (_) => onSubmitted?.call(),
    );
  }
}

class NameField extends StatelessWidget {
  const NameField({
    super.key,
    required this.controller,
    this.label,
    this.errorText,
    this.enabled = true,
    this.autofocus = false,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String? label;
  final String? errorText;
  final bool enabled;
  final bool autofocus;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return TextFormField(
      controller: controller,
      enabled: enabled,
      autofocus: autofocus,
      textCapitalization: TextCapitalization.words,
      textInputAction: TextInputAction.next,
      autofillHints: const <String>[AutofillHints.name],
      inputFormatters: <TextInputFormatter>[LengthLimitingTextInputFormatter(120)],
      decoration: InputDecoration(
        labelText: label ?? l10n.fieldNameLabel,
        errorText: errorText,
        prefixIcon: const Icon(Icons.person_outline_rounded),
      ),
      validator: (String? value) =>
          (value ?? '').trim().isEmpty ? l10n.fieldNameRequired : null,
      onFieldSubmitted: (_) => onSubmitted?.call(),
    );
  }
}

/// Age field. 4–120 matches the server's `MIN_AGE`/`MAX_AGE`; the under-13
/// decision itself is made server-side (see features/auth/age_gate.dart).
class AgeField extends StatelessWidget {
  const AgeField({
    super.key,
    required this.controller,
    this.errorText,
    this.enabled = true,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String? errorText;
  final bool enabled;
  final VoidCallback? onSubmitted;

  static const int minAge = 4;
  static const int maxAge = 120;

  static bool isValid(String raw) {
    final int? age = int.tryParse(raw.trim());
    return age != null && age >= minAge && age <= maxAge;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.done,
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(3),
      ],
      decoration: InputDecoration(
        labelText: l10n.fieldAgeLabel,
        errorText: errorText,
        prefixIcon: const Icon(Icons.cake_outlined),
      ),
      validator: (String? value) =>
          isValid(value ?? '') ? null : l10n.fieldAgeInvalid,
      onFieldSubmitted: (_) => onSubmitted?.call(),
    );
  }
}

class EmailField extends StatelessWidget {
  const EmailField({
    super.key,
    required this.controller,
    required this.label,
    this.errorText,
    this.enabled = true,
    this.autofocus = false,
    this.required = true,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String? errorText;
  final bool enabled;
  final bool autofocus;
  final bool required;
  final VoidCallback? onSubmitted;

  static final RegExp _pattern = RegExp(r'^[^@\s]+@[^@\s.]+\.[^@\s]+$');

  static bool isValid(String raw) => _pattern.hasMatch(raw.trim());

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return TextFormField(
      controller: controller,
      enabled: enabled,
      autofocus: autofocus,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.done,
      autofillHints: const <String>[AutofillHints.email],
      inputFormatters: <TextInputFormatter>[LengthLimitingTextInputFormatter(254)],
      decoration: InputDecoration(
        labelText: label,
        errorText: errorText,
        prefixIcon: const Icon(Icons.alternate_email_rounded),
      ),
      validator: (String? value) {
        final String raw = (value ?? '').trim();
        if (raw.isEmpty) return required ? l10n.parentEmailInvalid : null;
        return isValid(raw) ? null : l10n.parentEmailInvalid;
      },
      onFieldSubmitted: (_) => onSubmitted?.call(),
    );
  }
}

/// Full-width primary submit button with an inline busy state, so a form never
/// has to build its own spinner swap.
class SubmitButton extends StatelessWidget {
  const SubmitButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.icon,
    this.destructive = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final IconData? icon;

  /// Paints the button in the error colour for irreversible actions (M-29).
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return FilledButton(
      style: destructive
          ? FilledButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: colors.onError,
            )
          : null,
      onPressed: busy ? null : onPressed,
      child: busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                if (icon != null) ...<Widget>[
                  Icon(icon, size: 20),
                  const SizedBox(width: 8),
                ],
                Flexible(child: Text(label, textAlign: TextAlign.center)),
              ],
            ),
    );
  }
}
