import 'package:flutter/material.dart';

import '../features/map/parchment_codex_tokens.dart';

/// Shared Parchment Codex chrome for tab screens and modals.
abstract final class ParchmentUi {
  static const EdgeInsets screenPadding =
      EdgeInsets.symmetric(horizontal: 18, vertical: 12);
}

class ParchmentScreenHeader extends StatelessWidget {
  const ParchmentScreenHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    this.trailing,
  });

  final String eyebrow;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ParchmentColors.page,
        border: Border(
          bottom: BorderSide(color: ParchmentColors.inkBorder(0.09)),
        ),
      ),
      child: Padding(
        // The top inset adds the real status-bar height on top of the fixed
        // 14px — not a fallback, the default case. This header is meant to sit
        // as the very first thing in a screen's body, and targeting SDK 35+
        // means Android draws edge-to-edge whether the screen asks for it or
        // not: with no SafeArea anywhere above it, "ANOINTED" painted straight
        // under the clock and status icons (support_screen.dart, the one
        // screen using this header as a standalone route rather than inside
        // HomeShell's tab stack).
        //
        // Self-cancelling where it isn't needed: for a header already sitting
        // inside an ancestor SafeArea — the three HomeShell tabs that also use
        // this header — that ancestor already zeroed the inset for everything
        // below it, so MediaQuery.paddingOf(context).top reads 0 right here
        // and this adds nothing. One fix, no call site has to remember it.
        padding: EdgeInsets.fromLTRB(
          18,
          14 + MediaQuery.paddingOf(context).top,
          18,
          12,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    eyebrow,
                    style: ParchmentText.karla(
                      size: 10,
                      weight: FontWeight.w700,
                      color: ParchmentColors.gold,
                      letterSpacing: 2.2,
                    ),
                  ),
                  Text(title, style: ParchmentText.cormorant(size: 21)),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

class ParchmentCard extends StatelessWidget {
  const ParchmentCard({
    super.key,
    required this.child,
    this.title,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final String? title;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: ParchmentColors.cream,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ParchmentColors.inkBorder(0.1)),
      ),
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (title != null) ...<Widget>[
            Text(
              title!,
              style: ParchmentText.karla(
                size: 13,
                weight: FontWeight.w700,
                color: ParchmentColors.brown,
              ),
            ),
            const SizedBox(height: 10),
          ],
          child,
        ],
      ),
    );
  }
}

class ParchmentStatChip extends StatelessWidget {
  const ParchmentStatChip({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: ParchmentColors.creamDark,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ParchmentColors.gold.withOpacity(0.35)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            value,
            style: ParchmentText.karla(size: 16, weight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: ParchmentText.karla(
              size: 10,
              weight: FontWeight.w600,
              color: ParchmentColors.inkMuted(0.55),
            ),
          ),
        ],
      ),
    );
  }
}

enum ParchmentNoticeTone { info, warning, success, error }

class ParchmentNoticeBanner extends StatelessWidget {
  const ParchmentNoticeBanner({
    super.key,
    required this.message,
    this.tone = ParchmentNoticeTone.info,
    this.icon,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final ParchmentNoticeTone tone;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  Color _accent() {
    switch (tone) {
      case ParchmentNoticeTone.warning:
        return ParchmentColors.current;
      case ParchmentNoticeTone.success:
        return const Color(0xFF3D7A4A);
      case ParchmentNoticeTone.error:
        return const Color(0xFF9B3A3A);
      case ParchmentNoticeTone.info:
        return ParchmentColors.brown;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color accent = _accent();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 20, color: accent),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              message,
              style: ParchmentText.karla(size: 13, height: 1.35),
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}

class ParchmentPrimaryButton extends StatelessWidget {
  const ParchmentPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: busy ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: ParchmentColors.ink,
        foregroundColor: ParchmentColors.goldLight,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (icon != null) ...<Widget>[
                  Icon(icon, size: 20),
                  const SizedBox(width: 8),
                ],
                Text(
                  label,
                  style: ParchmentText.karla(
                    size: 14,
                    weight: FontWeight.w700,
                    color: ParchmentColors.goldLight,
                  ),
                ),
              ],
            ),
    );
  }
}

class ParchmentSecondaryButton extends StatelessWidget {
  const ParchmentSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: ParchmentColors.ink,
        side: BorderSide(color: ParchmentColors.inkBorder(0.25)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Text(
        label,
        style: ParchmentText.karla(size: 14, weight: FontWeight.w600),
      ),
    );
  }
}

class ParchmentWindowPicker<T extends Object> extends StatelessWidget {
  const ParchmentWindowPicker({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  final List<ButtonSegment<T>> segments;
  final Set<T> selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<T>(
      segments: segments,
      selected: selected,
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith<Color?>(
          (Set<WidgetState> states) {
            if (states.contains(WidgetState.selected)) {
              return ParchmentColors.ink;
            }
            return ParchmentColors.creamDark;
          },
        ),
        foregroundColor: WidgetStateProperty.resolveWith<Color?>(
          (Set<WidgetState> states) {
            if (states.contains(WidgetState.selected)) {
              return ParchmentColors.goldLight;
            }
            return ParchmentColors.ink;
          },
        ),
        side: WidgetStatePropertyAll<BorderSide>(
          BorderSide(color: ParchmentColors.inkBorder(0.15)),
        ),
      ),
      onSelectionChanged: (Set<T> value) => onChanged(value.first),
    );
  }
}

class ParchmentPracticeTile extends StatelessWidget {
  const ParchmentPracticeTile({
    super.key,
    required this.levelNumber,
    required this.ready,
    required this.onTap,
  });

  final int levelNumber;
  final bool ready;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Level $levelNumber',
      excludeSemantics: true,
      child: SizedBox(
        width: 52,
        height: 52,
        child: Material(
          color: ready ? ParchmentColors.cream : ParchmentColors.lockedFill,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: ready ? ParchmentColors.ink : ParchmentColors.inkBorder(0.2),
              width: ready ? 2 : 1,
            ),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Center(
              child: Text(
                '$levelNumber',
                style: ParchmentText.karla(
                  size: 17,
                  weight: FontWeight.w700,
                  color: ready ? ParchmentColors.ink : ParchmentColors.inkMuted(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ParchmentListTile extends StatelessWidget {
  const ParchmentListTile({
    super.key,
    required this.title,
    required this.onTap,
    this.leading,
    this.destructive = false,
  });

  final String title;
  final VoidCallback onTap;
  final Widget? leading;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final Color color =
        destructive ? const Color(0xFF9B3A3A) : ParchmentColors.ink;
    return Material(
      color: ParchmentColors.cream,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: <Widget>[
              if (leading != null) ...<Widget>[
                IconTheme(
                  data: IconThemeData(color: color, size: 22),
                  child: leading!,
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  title,
                  style: ParchmentText.karla(
                    size: 14,
                    weight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: ParchmentColors.inkMuted()),
            ],
          ),
        ),
      ),
    );
  }
}
