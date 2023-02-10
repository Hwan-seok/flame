import 'dart:ui';

import 'package:collection/collection.dart';
import 'package:flame/flame.dart';
import 'package:flame/image_composition.dart';
import 'package:flame/sprite.dart';
import 'package:flame_tiled/src/rectangle_bin_packer.dart';
import 'package:meta/meta.dart';
import 'package:tiled/tiled.dart';

/// One image atlas for all Tiled image sets in a map.
class TiledAtlas {
  /// Single atlas for all renders.
  // Retain this as SpriteBatch can dispose of the original image for flips.
  final Image? atlas;

  /// Map of all source images to their new offset.
  final Map<String, Offset> offsets;

  /// The single batch operation for this atlas.
  final SpriteBatch? batch;

  /// Image key for this atlas.
  final String key;

  /// Track one atlas for all images in the Tiled map.
  ///
  /// See [fromTiledMap] for asynchronous loading.
  TiledAtlas._({
    required this.atlas,
    required this.offsets,
    required this.key,
  }) : batch = atlas == null ? null : SpriteBatch(atlas, imageKey: key);

  /// Returns whether or not this atlas contains [source].
  bool contains(String? source) => offsets.containsKey(source);

  /// Create a new atlas from this object with the intent of getting a new
  /// [SpriteBatch].
  TiledAtlas clone() => TiledAtlas._(
        atlas: atlas?.clone(),
        offsets: offsets,
        key: key,
      );

  /// Maps of tilesets compiled to [TiledAtlas].
  ///
  /// This is recommended to be cleared on test setup. Otherwise it
  /// could lead to unexpected behavior.
  @visibleForTesting
  static final atlasMap = <String, TiledAtlas>{};

  @visibleForTesting
  static String atlasKey(Iterable<TiledImage> images) {
    final files = ([...images.map((e) => e.source)]..sort()).join(',');
    return 'atlas{$files}';
  }

  static Future<TiledAtlas> fromLayer(
    TiledMap map,
    TileLayer layer,
  ) async {
    final uniqueTilesets = <Tileset>{};
    layer.tileData?.forEach((row) {
      row.forEach((gid) {
        if (gid.tile == 0) return;
        uniqueTilesets.add(map.tilesetByTileGId(gid.tile));
      });
    });

    final images = uniqueTilesets
        .map((e) => [e.image, ...e.tiles.map((e) => e.image)].whereNotNull())
        .expand((element) => element)
        .toList();

    if (images.isEmpty) {
      // so this map has no tiles... Ok.
      return TiledAtlas._(atlas: null, offsets: {}, key: 'atlas{empty}');
    }
    final key = atlasKey(images);

    if (atlasMap.containsKey(key)) {
      return atlasMap[key]!.clone();
    }

    if (images.length == 1) {
      // The map contains one image, so its either an atlas already, or a
      // really boring map.
      final tiledImage = images.first;
      final image = await Flame.images.load(tiledImage.source!, key: key);

      return atlasMap[key] = TiledAtlas._(
        atlas: image,
        offsets: {tiledImage.source!: Offset.zero},
        key: key,
      );
    }

    final bin = RectangleBinPacker();
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    final _emptyPaint = Paint();

    final offsetMap = <String, Offset>{};

    var pictureRect = Rect.zero;

    images.sort((b, a) {
      final height = a.height! - b.height!;
      return height != 0 ? height : a.width! - b.width!;
    });

    for (final tiledImage in images) {
      final image = await Flame.images.load(tiledImage.source!);
      final rect = bin.pack(image.width.toDouble(), image.height.toDouble());

      pictureRect = pictureRect.expandToInclude(rect);

      final offset =
          offsetMap[tiledImage.source!] = Offset(rect.left, rect.top);

      canvas.drawImage(image, offset, _emptyPaint);
    }
    final picture = recorder.endRecording();
    final image = await picture.toImageSafe(
      pictureRect.width.toInt(),
      pictureRect.height.toInt(),
    );
    Flame.images.add(key, image);
    return atlasMap[key] =
        TiledAtlas._(atlas: image, offsets: offsetMap, key: key);
  }

  /// Loads all the tileset images for the [map] into one [TiledAtlas].
  static Future<TiledAtlas> fromTiledMap(TiledMap map) async {
    final imageList = map.getTileImages().toList();

    if (imageList.isEmpty) {
      // so this map has no tiles... Ok.
      return TiledAtlas._(
        atlas: null,
        offsets: {},
        key: 'atlas{empty}',
      );
    }

    final key = atlasKey(imageList);
    if (atlasMap.containsKey(key)) {
      return atlasMap[key]!.clone();
    }

    if (imageList.length == 1) {
      // The map contains one image, so its either an atlas already, or a
      // really boring map.
      final tiledImage = imageList.first;
      final image =
          (await Flame.images.load(tiledImage.source!, key: key)).clone();

      return atlasMap[key] ??= TiledAtlas._(
        atlas: image,
        offsets: {tiledImage.source!: Offset.zero},
        key: key,
      );
    }

    final bin = RectangleBinPacker();
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    final _emptyPaint = Paint();

    final offsetMap = <String, Offset>{};

    var pictureRect = Rect.zero;

    imageList.sort((b, a) {
      final height = a.height! - b.height!;
      return height != 0 ? height : a.width! - b.width!;
    });

    // parallelize the download of images.
    await Future.wait([
      ...imageList.map((tiledImage) => Flame.images.load(tiledImage.source!))
    ]);

    for (final tiledImage in imageList) {
      final image = await Flame.images.load(tiledImage.source!);
      final rect = bin.pack(image.width.toDouble(), image.height.toDouble());

      pictureRect = pictureRect.expandToInclude(rect);

      final offset =
          offsetMap[tiledImage.source!] = Offset(rect.left, rect.top);

      canvas.drawImage(image, offset, _emptyPaint);
    }
    final picture = recorder.endRecording();
    final image = await picture.toImageSafe(
      pictureRect.width.toInt(),
      pictureRect.height.toInt(),
    );
    Flame.images.add(key, image);
    return atlasMap[key] = TiledAtlas._(
      atlas: image,
      offsets: offsetMap,
      key: key,
    );
  }
}

extension TiledMapHelper on TiledMap {
  /// Collect images that we'll use in tiles - exclude image layers.
  Set<TiledImage> getTileImages() {
    final imageSet = <TiledImage>{};
    for (var i = 0; i < tilesets.length; ++i) {
      final image = tilesets[i].image;
      if (image?.source != null) {
        imageSet.add(image!);
      }
      for (var j = 0; j < tilesets[i].tiles.length; ++j) {
        final image = tilesets[i].tiles[j].image;
        if (image?.source != null) {
          imageSet.add(image!);
        }
      }
    }
    return imageSet;
  }
}
