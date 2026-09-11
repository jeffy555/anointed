"""Semantic version comparison for the force-upgrade gate (design-spec §16)."""

from __future__ import annotations

import re

_SEMVER = re.compile(r"^(\d+)\.(\d+)\.(\d+)")


def parse_version(value: str) -> tuple[int, int, int]:
    """Parse ``major.minor.patch``, ignoring any pre-release/build suffix.

    Unparseable input yields ``(0, 0, 0)`` so a malformed client version is treated
    as below any real minimum and gets blocked rather than silently waved through.
    """
    match = _SEMVER.match((value or "").strip())
    if not match:
        return (0, 0, 0)
    return (int(match.group(1)), int(match.group(2)), int(match.group(3)))


def is_below_minimum(installed: str, minimum: str) -> bool:
    return parse_version(installed) < parse_version(minimum)
