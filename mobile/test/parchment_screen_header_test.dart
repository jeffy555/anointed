// support_screen.dart pushed ParchmentScreenHeader as the very first thing in
// an unprotected Scaffold body. Targeting SDK 35+ draws edge-to-edge whether a
// screen asks for it or not, so the header's fixed 14px top padding wasn't
// enough to clear the status bar — "ANOINTED" painted straight under the
// clock. The fix makes the header add the real inset itself, and — the part
// worth a test — do nothing extra when an ancestor SafeArea already consumed
// it, which is the situation on every other screen that uses this header.
import 'package:anointed/widgets/parchment_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const double statusBarHeight = 40;

  Widget wordmark() =>
      const ParchmentScreenHeader(eyebrow: 'ANOINTED', title: 'Help & Support');

  double topPaddingOf(WidgetTester tester) {
    final Padding padding = tester.widget<Padding>(
      find.descendant(
        of: find.byType(ParchmentScreenHeader),
        matching: find.byType(Padding),
      ),
    );
    return (padding.padding as EdgeInsets).top;
  }

  testWidgets(
      'standalone (support_screen.dart\'s case): adds the real status-bar inset',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (BuildContext context, Widget? child) => MediaQuery(
          data: const MediaQueryData(
            padding: EdgeInsets.only(top: statusBarHeight),
          ),
          child: child!,
        ),
        // No SafeArea — exactly how support_screen.dart mounts it, as the
        // first child of Scaffold.body.
        home: Scaffold(body: wordmark()),
      ),
    );

    expect(topPaddingOf(tester), 14 + statusBarHeight);
  });

  testWidgets(
      'behind an ancestor SafeArea (the three HomeShell-tab screens): adds nothing extra',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (BuildContext context, Widget? child) => MediaQuery(
          data: const MediaQueryData(
            padding: EdgeInsets.only(top: statusBarHeight),
          ),
          child: child!,
        ),
        // Matches HomeShell's phone body: SafeArea wraps the tab stack once,
        // above where each tab's own Scaffold and header sit.
        home: Scaffold(body: SafeArea(child: wordmark())),
      ),
    );

    // The ancestor SafeArea already zeroed MediaQuery.padding.top for
    // everything beneath it, so the header's own addition is 0 — not
    // statusBarHeight again. A regression here would mean Leaderboard,
    // Practice and Profile all gained a second, stacked status-bar gap.
    expect(topPaddingOf(tester), 14);
  });
}
