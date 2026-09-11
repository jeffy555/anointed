"""Parchment-style SVG portraits for ``image_clue`` questions."""

from __future__ import annotations

import hashlib
import html
import re


def slugify(name: str) -> str:
    cleaned = re.sub(r"[^a-z0-9]+", "-", name.strip().lower())
    return cleaned.strip("-") or "character"


def asset_key_for_character(name: str) -> str:
    return f"character/{slugify(name)}"


def _palette(seed: str) -> tuple[str, str, str]:
    digest = hashlib.sha256(seed.encode()).hexdigest()
    robes = ("#6D5526", "#A98432", "#D97B2B", "#8B5E3C", "#5C4A2E")
    accents = ("#E0B75E", "#F2D79A", "#FFFAF0", "#EFE3CA")
    idx = int(digest[:2], 16)
    return robes[idx % len(robes)], accents[idx % len(accents)], "#241D14"


def portrait_svg(*, name: str, alt_text: str | None = None) -> str:
    """Deterministic parchment portrait for a Bible character."""
    label = (alt_text or name).strip() or name
    initial = html.escape(label[0].upper())
    safe_name = html.escape(name)
    robe, accent, ink = _palette(name)
    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 320 240" role="img" aria-label="{html.escape(label)}">
  <rect width="320" height="240" fill="#FFFAF0"/>
  <rect x="8" y="8" width="304" height="224" rx="16" fill="#F2E7D2" stroke="{accent}" stroke-width="3"/>
  <ellipse cx="160" cy="92" rx="34" ry="38" fill="#E8C9A0"/>
  <path d="M126 78 Q160 44 194 78 L194 92 Q160 68 126 92 Z" fill="{ink}" opacity="0.85"/>
  <path d="M88 220 Q160 130 232 220 Z" fill="{robe}"/>
  <path d="M118 220 Q160 150 202 220 Z" fill="{accent}" opacity="0.55"/>
  <text x="160" y="102" text-anchor="middle" font-family="Georgia, serif" font-size="34" font-weight="700" fill="{ink}">{initial}</text>
  <text x="160" y="206" text-anchor="middle" font-family="Karla, sans-serif" font-size="14" font-weight="700" fill="{ink}">{safe_name}</text>
</svg>"""


def resolve_asset(asset_key: str, *, character_names: dict[str, str] | None = None) -> str | None:
    """Return SVG body for a known asset key, or ``None`` when unknown."""
    if not asset_key.startswith("character/"):
        return None
    slug = asset_key.split("/", 1)[1]
    if character_names:
        for name, key in character_names.items():
            if key == asset_key or slugify(name) == slug:
                return portrait_svg(name=name)
    # Best-effort title-case fallback from slug.
    display = slug.replace("-", " ").title()
    return portrait_svg(name=display, alt_text=display)
