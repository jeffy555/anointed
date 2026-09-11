import 'package:flutter/material.dart';

import '../../core/tokens.dart';
import '../../l10n/gen/app_localizations.dart';
import 'kids_zone_tokens.dart';

/// Two-box chooser on the level map — Main Journey vs Kids Zone for every signed-in user.
class PlayModeChooser extends StatelessWidget {
  const PlayModeChooser({super.key, required this.onKidsZone});

  final VoidCallback onKidsZone;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          l10n.playModeChooserHeading,
          style: KidsZoneText.nunito(size: 14, weight: FontWeight.w700, color: KidsZoneColors.inkMuted),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: <Widget>[
            Expanded(
              child: _ModeBox(
                title: l10n.playModeMainJourneyTitle,
                subtitle: l10n.playModeMainJourneySubtitle,
                icon: Icons.map_rounded,
                accent: const Color(0xFF8D6E63),
                selected: true,
                onTap: () {},
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _ModeBox(
                title: l10n.playModeKidsZoneTitle,
                subtitle: l10n.playModeKidsZoneSubtitle,
                icon: Icons.castle_rounded,
                accent: KidsZoneColors.grass,
                selected: false,
                onTap: onKidsZone,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ModeBox extends StatelessWidget {
  const _ModeBox({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? accent.withOpacity(0.12) : KidsZoneColors.card,
      borderRadius: BorderRadius.circular(16),
      elevation: selected ? 0 : 1,
      shadowColor: accent.withOpacity(0.25),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? accent : accent.withOpacity(0.35),
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(icon, color: accent, size: 28),
              const SizedBox(height: AppSpacing.sm),
              Text(
                title,
                style: KidsZoneText.nunito(size: 15, weight: FontWeight.w800, color: KidsZoneColors.ink),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: KidsZoneText.nunito(size: 11, weight: FontWeight.w600, color: KidsZoneColors.inkMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
