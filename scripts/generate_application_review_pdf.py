"""Generate the Anointed application review PDF."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path


def sanitize(text: str) -> str:
    replacements = {
        "\u2018": "'",
        "\u2019": "'",
        "\u201c": '"',
        "\u201d": '"',
        "\u2013": "-",
        "\u2014": "-",
        "\u2022": "-",
        "\u2192": "->",
        "\u00d7": "x",
    }
    for src, dst in replacements.items():
        text = text.replace(src, dst)
    return text


def make_pdf(output_path: Path) -> None:
    try:
        from fpdf import FPDF
    except ImportError as exc:
        raise SystemExit("Install fpdf2: pip install fpdf2") from exc

    class ReviewPdf(FPDF):
        def footer(self) -> None:
            self.set_y(-12)
            self.set_font("Helvetica", "I", 8)
            self.set_text_color(120, 120, 120)
            self.cell(0, 8, f"Page {self.page_no()}/{{nb}}", align="C")

    pdf = ReviewPdf()
    pdf.alias_nb_pages()
    pdf.set_auto_page_break(auto=True, margin=18)
    pdf.add_page()

    def title(text: str) -> None:
        pdf.set_font("Helvetica", "B", 18)
        pdf.set_text_color(36, 29, 20)
        pdf.multi_cell(0, 9, sanitize(text), new_x="LMARGIN", new_y="NEXT")
        pdf.ln(2)

    def h2(text: str) -> None:
        if pdf.get_y() > 250:
            pdf.add_page()
        pdf.set_font("Helvetica", "B", 13)
        pdf.set_text_color(169, 132, 50)
        pdf.multi_cell(0, 7, sanitize(text), new_x="LMARGIN", new_y="NEXT")
        pdf.ln(1)

    def h3(text: str) -> None:
        if pdf.get_y() > 255:
            pdf.add_page()
        pdf.set_font("Helvetica", "B", 11)
        pdf.set_text_color(36, 29, 20)
        pdf.multi_cell(0, 6, sanitize(text), new_x="LMARGIN", new_y="NEXT")

    def body(text: str) -> None:
        pdf.set_font("Helvetica", "", 10)
        pdf.set_text_color(36, 29, 20)
        pdf.multi_cell(0, 5.5, sanitize(text), new_x="LMARGIN", new_y="NEXT")
        pdf.ln(1)

    def bullet(text: str) -> None:
        pdf.set_font("Helvetica", "", 10)
        pdf.set_text_color(36, 29, 20)
        pdf.multi_cell(0, 5.5, sanitize(f"  - {text}"), new_x="LMARGIN", new_y="NEXT")

    title("Anointed Application Review")
    body("Date: 4 September 2026")
    body(
        "Scope: Engineering completeness, launch readiness, UX gaps, missing features, "
        "and recommended improvements for the Bible character quiz app (kids 6-12)."
    )
    pdf.ln(2)

    h2("Overall Assessment")
    body(
        "The engineering scaffold is in good shape: all 10 critical user flows are wired "
        "(auth, consent, map, gameplay, leaderboard, IAP, practice, profile). Backend "
        "tests pass and the Parchment Codex map is the active design."
    )
    body(
        "The app is NOT launch-ready yet. The biggest gaps are content, legal, store assets, "
        "and real-device QA - not missing screens."
    )

    h2("1. Must Change Before Launch")
    h3("1.1 Content (biggest blocker)")
    bullet("Target: 100 levels x ~20 questions (~2,000 total)")
    bullet("Today: dev seed content (~2,100 auto-generated questions) and a 5-level / 60-question offline practice pack")
    bullet("Action: Author and publish real questions via /admin. Do not ship seed script output as final content.")

    h3("1.2 Legal and COPPA")
    bullet("Privacy Policy and Terms are draft HTML only - need counsel review and live URLs")
    bullet("Parental consent (VPC) email/web copy is draft - needs legal sign-off")
    bullet("AdMob production settings need a COPPA audit before live ads (docs/admob_coppa_checklist.md)")

    h3("1.3 Store identity")
    bullet("Bundle ID mismatch: requirements say com.anointed.app; app uses com.anointed.anointed")
    bullet("App icon, splash, and screenshots still placeholders")

    h3("1.4 QA on real devices")
    bullet("Backend: ~95 automated tests")
    bullet("Mobile: essentially no automated tests; full manual test plan not executed")
    bullet("Deploy/install issues suggest QA should be part of every release")

    h3("1.5 IAP hardening (medium priority)")
    bullet("Purchase flow works, but App Store Server Notifications V2 (refunds/revocations) is not implemented")

    h2("2. UX and Polish Worth Fixing")
    bullet("Visual consistency: Map uses Parchment Codex; Leaderboard, Practice, Profile still use older arcade styling")
    bullet("Dead code: Stained Glass map widgets (stained_glass_*.dart) are unused")
    bullet("Splash / brand: Material icon placeholder instead of final wordmark")
    bullet("Level complete: Static trophy; design spec calls for celebration animation")
    bullet("image_clue: UI exists but shows alt-text placeholders - no real character images")
    bullet("Kids 6-12: No read-aloud/TTS for question text")
    bullet("FAQ / support copy: Functional but placeholder wording")
    bullet("Phone recovery: New device + phone sign-in is weak; users may need support")

    h2("3. Features From Spec Not Fully Built")
    bullet("Launch content bank (2,000 curated questions)")
    bullet("Adaptive difficulty - performance data collected but never used")
    bullet("image_clue with real assets - deferred post-launch")
    bullet("Tamil localization - infrastructure exists, no translations")
    bullet("Church/group leaderboards - only global leaderboard exists")
    bullet("Firebase Crashlytics - optional; not configured in repo")

    h2("4. New Features That Would Fit Well")
    bullet("Adaptive difficulty - use UserPerformanceSummary to tweak timer/difficulty (high impact, data already exists)")
    bullet("Character learn cards - short bio unlocked after completing a level")
    bullet("Streaks and gentle achievements - pairs with local notification nudges")
    bullet("Audio read-aloud (TTS) - helps younger kids without mic permissions")
    bullet("Church/small-group leaderboards - join your church code")
    bullet("Tamil - when church stakeholders are ready")
    bullet("Admin PDF export - export_questions_pdf.py could become an admin button")
    bullet("image_clue asset pipeline - admin upload + CDN when ready")

    h2("5. Technical Cleanup")
    bullet("Remove or archive orphaned Stained Glass code")
    bullet("Align bundle ID across Android, iOS, and backend config")
    bullet("Add basic mobile widget/integration tests")
    bullet("Set production legal URLs in backend config")
    bullet("Consider CI for backend tests + Flutter analyze")

    h2("6. Recommended Priority Order")
    h3("Now")
    bullet("Finalize bundle ID, fix deploy scripts, device QA on phone + emulator")
    h3("Before beta")
    bullet("Legal docs, launch content (Track A), app icon/splash")
    h3("Before store submit")
    bullet("AdMob COPPA audit, Firebase/Crashlytics, store screenshots")
    h3("Post-launch v1.1")
    bullet("Adaptive difficulty, visual polish on other tabs, TTS, achievements")

    h2("Bottom Line")
    body(
        "The app works end-to-end as a prototype. To ship, you mainly need real content, "
        "legal sign-off, store assets, and device QA."
    )
    body(
        "Highest-value engineering improvements: unify UI (Parchment across all tabs), "
        "use adaptive difficulty data already collected, and clean up bundle ID + dead code."
    )

    pdf.ln(4)
    body("Generated from the Anointed spec pipeline and codebase review.")

    output_path.parent.mkdir(parents=True, exist_ok=True)
    pdf.output(str(output_path))


def main(argv: list[str] | None = None) -> None:
    repo_root = Path(__file__).resolve().parent
    while repo_root != repo_root.parent and not (repo_root / "mobile").is_dir():
        repo_root = repo_root.parent
    default_out = repo_root / "dist" / "anointed-application-review.pdf"

    parser = argparse.ArgumentParser(description="Generate application review PDF.")
    parser.add_argument(
        "--output",
        type=Path,
        default=default_out,
        help="Output PDF path",
    )
    args = parser.parse_args(argv)
    make_pdf(args.output)
    print(f"Wrote {args.output.resolve()}")


if __name__ == "__main__":
    main(sys.argv[1:])
