"""Export all level questions and answers to PDF files.

Creates one PDF per level plus a combined master PDF under dist/question-bank/.

    python -m app.scripts.export_questions_pdf
    python -m app.scripts.export_questions_pdf --output-dir /path/to/out
"""

from __future__ import annotations

import argparse
import sys
from collections import defaultdict
from pathlib import Path

from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.core.database import SessionLocal
from app.models.content import Level, Question

# Matches mobile/lib/features/map/level_chapters.dart
CHAPTERS: list[tuple[str, str, str, int, int]] = [
    ("I", "Genesis", "In the beginning", 1, 20),
    ("II", "Exodus", "Out of Egypt", 21, 40),
    ("III", "Psalms", "Songs of ascent", 41, 60),
    ("IV", "Prophets", "Voices in the wild", 61, 80),
    ("V", "Gospels", "The good news", 81, 100),
]


def chapter_for_level(level_number: int) -> tuple[str, str, str]:
    for numeral, name, tagline, start, end in CHAPTERS:
        if start <= level_number <= end:
            return numeral, name, tagline
    return "I", "Genesis", "In the beginning"


def sanitize(text: str) -> str:
    """Keep PDF text renderable in bundled Unicode fonts."""
    if not text:
        return ""
    replacements = {
        "\u2018": "'",
        "\u2019": "'",
        "\u201c": '"',
        "\u201d": '"',
        "\u2013": "-",
        "\u2014": "-",
        "\u2026": "...",
        "\u00a0": " ",
    }
    for src, dst in replacements.items():
        text = text.replace(src, dst)
    return text.strip()


def load_questions_by_level(db: Session) -> dict[int, list[Question]]:
    rows = (
        db.execute(
            select(Question)
            .options(selectinload(Question.level), selectinload(Question.character))
            .order_by(Question.level_id, Question.variant_type, Question.question_text)
        )
        .scalars()
        .all()
    )
    grouped: dict[int, list[Question]] = defaultdict(list)
    for question in rows:
        grouped[question.level_id].append(question)
    return dict(grouped)


def make_pdf_writer():
    try:
        from fpdf import FPDF
    except ImportError as exc:  # pragma: no cover - CLI guard
        raise SystemExit(
            "fpdf2 is required. Install with: pip install fpdf2"
        ) from exc

    class QuestionPdf(FPDF):
        def __init__(self) -> None:
            super().__init__()
            self.level_title = "Anointed Question Bank"

        def header(self) -> None:
            self.set_font("Helvetica", "B", 10)
            self.set_text_color(80, 60, 30)
            self.cell(0, 8, sanitize(self.level_title), new_x="LMARGIN", new_y="NEXT")
            self.set_draw_color(169, 132, 50)
            self.line(10, self.get_y(), 200, self.get_y())
            self.ln(4)

        def footer(self) -> None:
            self.set_y(-12)
            self.set_font("Helvetica", "I", 8)
            self.set_text_color(120, 120, 120)
            self.cell(0, 8, f"Page {self.page_no()}/{{nb}}", align="C")

        def section_heading(self, text: str) -> None:
            self.set_font("Helvetica", "B", 14)
            self.set_text_color(36, 29, 20)
            self.multi_cell(0, 8, sanitize(text), new_x="LMARGIN", new_y="NEXT")
            self.ln(2)

        def body_text(self, text: str, *, bold: bool = False, size: int = 10) -> None:
            style = "B" if bold else ""
            self.set_font("Helvetica", style, size)
            self.set_text_color(36, 29, 20)
            self.multi_cell(0, 5.5, sanitize(text), new_x="LMARGIN", new_y="NEXT")

        def muted_text(self, text: str) -> None:
            self.set_font("Helvetica", "", 9)
            self.set_text_color(109, 85, 38)
            self.multi_cell(0, 5, sanitize(text), new_x="LMARGIN", new_y="NEXT")

    return QuestionPdf


def render_level_pdf(
    pdf_cls,
    *,
    level_number: int,
    level: Level | None,
    questions: list[Question],
) -> "QuestionPdf":
    numeral, chapter_name, tagline = chapter_for_level(level_number)
    tier = getattr(level.difficulty_tier, "value", level.difficulty_tier) if level else "unknown"
    timer = level.timer_seconds if level else "?"

    pdf = pdf_cls()
    pdf.alias_nb_pages()
    pdf.level_title = f"Anointed — Level {level_number:03d}"
    pdf.add_page()

    pdf.section_heading(f"Level {level_number} of 100")
    pdf.muted_text(
        f"Chapter {numeral}: {chapter_name} — {tagline}  |  "
        f"Difficulty: {tier}  |  Timer: {timer}s  |  Questions: {len(questions)}"
    )
    pdf.ln(4)

    for index, question in enumerate(questions, start=1):
        if pdf.get_y() > 250:
            pdf.add_page()

        pdf.body_text(f"Q{index}. {question.question_text}", bold=True, size=11)
        pdf.muted_text(f"Type: {getattr(question.variant_type, 'value', question.variant_type).replace('_', ' ')}")

        if question.verse_reference or question.verse_excerpt:
            verse_bits = [bit for bit in (question.verse_reference, question.verse_excerpt) if bit]
            pdf.muted_text("Verse: " + " — ".join(verse_bits))

        labels = ("A", "B", "C", "D")
        for label, option in zip(labels, question.answer_options, strict=False):
            marker = " *" if option == question.correct_answer else ""
            pdf.body_text(f"  {label}) {option}{marker}")

        pdf.body_text(f"Correct answer: {question.correct_answer}", bold=True, size=10)
        if question.character:
            pdf.muted_text(f"Character: {question.character.name}")
        pdf.ln(3)

    return pdf


def export_pdfs(output_dir: Path) -> tuple[int, int]:
    pdf_cls = make_pdf_writer()
    output_dir.mkdir(parents=True, exist_ok=True)

    with SessionLocal() as db:
        by_level = load_questions_by_level(db)
        levels = {
            level.level_number: level
            for level in db.execute(select(Level)).scalars().all()
        }

    if not by_level:
        raise SystemExit("No questions found in the database.")

    master = pdf_cls()
    master.alias_nb_pages()
    master.level_title = "Anointed — All Levels Question Bank"
    master.add_page()
    master.section_heading("Anointed Bible Quiz — Complete Question Bank")
    master.body_text(
        f"This document contains all questions and answers across {len(by_level)} levels "
        f"({sum(len(qs) for qs in by_level.values())} questions total).",
    )
    master.ln(4)

    level_files = 0
    for level_number in range(1, 101):
        questions = by_level.get(level_number, [])
        if not questions:
            continue

        level_pdf = render_level_pdf(
            pdf_cls,
            level_number=level_number,
            level=levels.get(level_number),
            questions=questions,
        )
        level_path = output_dir / f"level-{level_number:03d}.pdf"
        level_pdf.output(str(level_path))
        level_files += 1

        if level_number > 1:
            master.add_page()
        numeral, chapter_name, tagline = chapter_for_level(level_number)
        master.section_heading(f"Level {level_number} — Chapter {numeral}: {chapter_name}")
        master.muted_text(tagline)
        master.ln(2)

        for index, question in enumerate(questions, start=1):
            if master.get_y() > 250:
                master.add_page()
            master.body_text(f"L{level_number} Q{index}. {question.question_text}", bold=True)
            labels = ("A", "B", "C", "D")
            for label, option in zip(labels, question.answer_options, strict=False):
                marker = " *" if option == question.correct_answer else ""
                master.body_text(f"  {label}) {option}{marker}")
            master.body_text(f"Answer: {question.correct_answer}", bold=True)
            master.ln(2)

    master_path = output_dir / "anointed-all-levels.pdf"
    master.output(str(master_path))

    readme = output_dir / "README.txt"
    readme.write_text(
        "Anointed question bank PDF export\n"
        f"Levels exported: {level_files}\n"
        f"Total questions: {sum(len(by_level.get(n, [])) for n in range(1, 101))}\n\n"
        "Files:\n"
        "  anointed-all-levels.pdf  — every level in one document\n"
        "  level-001.pdf … level-100.pdf  — one PDF per level\n\n"
        "Correct answers are marked with * in the option list and repeated on the Answer line.\n",
        encoding="utf-8",
    )

    return level_files, sum(len(by_level.get(n, [])) for n in range(1, 101))


def main(argv: list[str] | None = None) -> None:
    parser = argparse.ArgumentParser(description="Export Anointed questions to PDF files.")
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path(__file__).resolve().parents[3] / "dist" / "question-bank",
        help="Directory for PDF output (default: repo/dist/question-bank)",
    )
    args = parser.parse_args(argv)

    level_files, question_count = export_pdfs(args.output_dir)
    print(f"Exported {question_count} questions across {level_files} level PDFs")
    print(f"Output: {args.output_dir.resolve()}")


if __name__ == "__main__":
    main(sys.argv[1:])
