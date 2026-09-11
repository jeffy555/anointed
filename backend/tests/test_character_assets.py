"""Character portrait SVG assets."""

from app.services.character_assets import asset_key_for_character, portrait_svg, resolve_asset, slugify


def test_slugify():
    assert slugify("King David") == "king-david"


def test_asset_key_for_character():
    assert asset_key_for_character("Adam") == "character/adam"


def test_portrait_svg_contains_name():
    body = portrait_svg(name="Moses", alt_text="The lawgiver")
    assert "Moses" in body
    assert "<svg" in body


def test_resolve_asset_known_slug():
    body = resolve_asset("character/adam", character_names={"Adam": "character/adam"})
    assert body is not None
    assert "Adam" in body


def test_resolve_asset_unknown():
    assert resolve_asset("unknown/key") is None
