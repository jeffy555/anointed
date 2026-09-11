import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;

import '../core/config.dart';
import '../features/map/parchment_codex_tokens.dart';
import 'character_portrait.dart';

/// Loads a character illustration for ``image_clue`` questions.
///
/// Tries the server asset URL first, then falls back to a generated parchment
/// portrait so offline practice still shows a visual clue.
class CharacterImage extends StatefulWidget {
  const CharacterImage({
    super.key,
    this.imageAssetKey,
    this.imageAltText,
    this.height = 180,
  });

  final String? imageAssetKey;
  final String? imageAltText;
  final double height;

  @override
  State<CharacterImage> createState() => _CharacterImageState();
}

class _CharacterImageState extends State<CharacterImage> {
  String? _svgBody;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(CharacterImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageAssetKey != widget.imageAssetKey) {
      _svgBody = null;
      _failed = false;
      _load();
    }
  }

  Future<void> _load() async {
    final String? key = widget.imageAssetKey;
    if (key == null || key.isEmpty) return;

    final Uri uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/v1/content/assets/${Uri.encodeComponent(key)}',
    );
    try {
      final http.Response response = await http
          .get(uri)
          .timeout(AppConfig.apiTimeout);
      if (!mounted) return;
      if (response.statusCode == 200 && response.body.contains('<svg')) {
        setState(() => _svgBody = response.body);
      } else {
        setState(() => _failed = true);
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  String get _label {
    final String alt = (widget.imageAltText ?? '').trim();
    if (alt.isNotEmpty) return alt;
    final String? key = widget.imageAssetKey;
    if (key == null || !key.contains('/')) return 'Bible character';
    return key.split('/').last.replaceAll('-', ' ');
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: _label,
      image: true,
      child: Container(
        width: double.infinity,
        height: widget.height,
        decoration: BoxDecoration(
          color: ParchmentColors.strip,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ParchmentColors.gold.withOpacity(0.35), width: 2),
        ),
        clipBehavior: Clip.antiAlias,
        child: _svgBody != null
            ? SvgPicture.string(
                _svgBody!,
                fit: BoxFit.contain,
                semanticsLabel: _label,
              )
            : _failed || widget.imageAssetKey == null
                ? CharacterPortrait(
                    label: _label,
                    assetKey: widget.imageAssetKey,
                  )
                : Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: ParchmentColors.gold,
                      ),
                    ),
                  ),
      ),
    );
  }
}
