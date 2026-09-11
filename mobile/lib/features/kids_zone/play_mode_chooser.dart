import 'package:flutter/material.dart';

import '../../core/tokens.dart';
import '../../l10n/gen/app_localizations.dart';
import '../map/parchment_codex_tokens.dart';
import 'kids_zone_tokens.dart';

/// Two-box chooser on the level map — Main Journey vs Kids Zone for every signed-in user.
///
/// Parchment-styled, not Kids-Zone-styled: this sits on the level map, which is
/// a Parchment screen. It previously used KidsZoneText/KidsZoneColors
/// throughout, which put that palette's blue ink on cream paper. The one thing
/// kept from Kids Zone is the green accent on its own box, which is signalling
/// where the box leads rather than styling the map.
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
          style: ParchmentText.karla(
            size: 13,
            weight: FontWeight.w700,
            color: ParchmentColors.brown,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: <Widget>[
            Expanded(
              child: _ModeBox(
                title: l10n.playModeMainJourneyTitle,
                subtitle: l10n.playModeMainJourneySubtitle,
                icon: Icons.map_rounded,
                accent: ParchmentColors.brown,
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
      color: selected ? accent.withOpacity(0.10) : ParchmentColors.cream,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
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
                style: ParchmentText.cormorant(size: 18),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: ParchmentText.karla(
                  size: 11,
                  weight: FontWeight.w600,
                  color: ParchmentColors.inkMuted(0.6),
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
