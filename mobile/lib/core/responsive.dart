import 'package:flutter/material.dart';

import 'tokens.dart';

/// Tablet / landscape layout helpers for design-spec §12.
///
/// The breakpoint is on the shortest side rather than width so a phone held in
/// landscape stays a phone (stacked layout) while a tablet is a tablet in both
/// orientations — which is what the spec's "two-column where natural" rule wants.
class Layout {
  const Layout._();

  static const double tabletBreakpoint = 600;

  /// Max dialog/bottom-sheet width on tablet, per design-spec §12.
  static const double dialogMaxWidth = 480;

  static const double contentMaxWidth = 560;

  static bool isTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).shortestSide >= tabletBreakpoint;

  static bool isLandscape(BuildContext context) =>
      MediaQuery.orientationOf(context) == Orientation.landscape;

  /// True when the two-column treatment applies: a tablet, or any device wide
  /// enough that a single column would leave the content stranded.
  static bool useWideLayout(BuildContext context) =>
      isTablet(context) && MediaQuery.sizeOf(context).width >= 840;

  /// design-spec §12: bottom tab bars collapse to a left navigation rail on tablet.
  static bool useNavigationRail(BuildContext context) => isTablet(context);

  /// The gutter between page content and the screen edge, on one side.
  ///
  /// Exists because `pagePadding(context).horizontal` reads like "the horizontal
  /// padding" but is `EdgeInsets.horizontal` — left *plus* right. Several screens
  /// fed that sum back in as a single-side value and quietly ran at double the
  /// intended gutter, which is why the map and practice tabs did not line up.
  /// Reach for this when a single number is what is wanted.
  static double pageInset(BuildContext context) =>
      isTablet(context) ? AppSpacing.xl : AppSpacing.md;

  static EdgeInsets pagePadding(BuildContext context) => EdgeInsets.symmetric(
        horizontal: pageInset(context),
        vertical: AppSpacing.md,
      );
}

/// Centres and width-caps a column of content so forms and prose stay readable
/// on tablet instead of stretching edge to edge.
class ContentColumn extends StatelessWidget {
  const ContentColumn({
    super.key,
    required this.child,
    this.maxWidth = Layout.contentMaxWidth,
    this.padding,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding ?? Layout.pagePadding(context),
          child: child,
        ),
      ),
    );
  }
}

/// Renders [wide] as two columns on tablet/landscape and [narrow] stacked
/// elsewhere. Used by M-13 gameplay, M-26 profile, and M-17 leaderboard.
class AdaptiveTwoPane extends StatelessWidget {
  const AdaptiveTwoPane({
    super.key,
    required this.primary,
    required this.secondary,
    this.primaryFlex = 1,
    this.secondaryFlex = 1,
    this.spacing = AppSpacing.lg,
  });

  final Widget primary;
  final Widget secondary;
  final int primaryFlex;
  final int secondaryFlex;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    if (!Layout.useWideLayout(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          primary,
          SizedBox(height: spacing),
          secondary,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(flex: primaryFlex, child: primary),
        SizedBox(width: spacing),
        Expanded(flex: secondaryFlex, child: secondary),
      ],
    );
  }
}
