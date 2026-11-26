// The catalog photo of a part: the `image` address that GET /api/parts returns for a photo uploaded in the admin
// dashboard (a public Supabase Storage URL). Only the photos that are on screen are fetched, each one is decoded at the
// size it is shown (an upload may be 5 MB), and a quiet placeholder keeps the layout still while a photo loads or when
// it cannot be loaded (offline, deleted, private bucket), so a broken address never breaks a card.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/palette.dart';

/// True when [url] is an absolute http(s) address that can be fetched (the API already drops anything else).
bool isShowableImageUrl(String? url) {
  final String value = (url ?? '').trim();
  if (value.isEmpty) {
    return false;
  }
  final Uri? uri = Uri.tryParse(value);
  return uri != null && uri.host.isNotEmpty && (uri.scheme == 'https' || uri.scheme == 'http');
}

/// A photo of a part in a rounded frame. With [size] it is a square thumbnail; without it the photo takes the width it
/// is given and keeps [aspectRatio] (the details screen).
class PartImage extends StatelessWidget {
  const PartImage({
    super.key,
    required this.url,
    this.size,
    this.aspectRatio = 4 / 3,
    this.fit = BoxFit.cover,
    this.radius = 14,
  });

  /// Address of the photo (see [isShowableImageUrl]).
  final String url;

  /// Side of a square thumbnail, or null to fill the available width.
  final double? size;
  final double aspectRatio;
  final BoxFit fit;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    final double? side = size;
    final double shownWidth = side ?? MediaQuery.sizeOf(context).width;
    final int decodeWidth = math.max(96, math.min(1600, (shownWidth * MediaQuery.devicePixelRatioOf(context)).ceil()));

    final Widget photo = Stack(
      fit: StackFit.expand,
      children: <Widget>[
        // Visible while the photo loads and when it fails: the photo is drawn over it.
        Center(
          child: Icon(
            Icons.image_outlined,
            size: side == null ? 44 : side * 0.34,
            color: p.muted.withValues(alpha: 0.45),
          ),
        ),
        Image.network(
          url.trim(),
          fit: fit,
          cacheWidth: decodeWidth,
          gaplessPlayback: true,
          excludeFromSemantics: true,
          frameBuilder: (BuildContext context, Widget child, int? frame, bool wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded) {
              return child;
            }
            return AnimatedOpacity(
              opacity: frame == null ? 0 : 1,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              child: child,
            );
          },
          errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) => const SizedBox.shrink(),
        ),
      ],
    );

    final Widget framed = Container(
      decoration: BoxDecoration(color: p.glass2, borderRadius: BorderRadius.circular(radius)),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: p.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: photo,
    );

    return Semantics(
      image: true,
      label: 'صورة القطعة',
      child: side == null
          ? AspectRatio(aspectRatio: aspectRatio, child: framed)
          : SizedBox(width: side, height: side, child: framed),
    );
  }
}
