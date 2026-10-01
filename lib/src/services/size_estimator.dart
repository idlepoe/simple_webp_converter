import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';

import '../models/conversion_options.dart';
import '../models/selected_video.dart';
import 'webp_service.dart';

class SizeEstimator {
  SizeEstimator(this._service);
  final WebpService _service;
  final Map<String, int> _cache = {};
  ({SelectedVideo video, ConversionOptions options, int bytes})? _last;

  String _key(SelectedVideo video, ConversionOptions options) =>
      '${video.path}:${video.sizeBytes}:${video.duration.inMicroseconds}:${options.toMap()}';

  int? cached(SelectedVideo video, ConversionOptions options) =>
      _cache[_key(video, options)];

  int? approximate(SelectedVideo video, ConversionOptions options) {
    final last = _last;
    if (last == null || last.video.path != video.path) return null;
    final before = WebpService.dimensions(video, last.options);
    final after = WebpService.dimensions(video, options);
    final ratio =
        after.width *
        after.height /
        (before.width * before.height) *
        options.fps /
        last.options.fps *
        last.options.speed /
        options.speed *
        math.pow((options.quality + 20) / (last.options.quality + 20), 1.3);
    return math.max(1, (last.bytes * ratio).round());
  }

  Future<int> estimate(
    SelectedVideo video,
    ConversionOptions options,
    WebpOperation operation,
  ) async {
    final hit = cached(video, options);
    if (hit != null) return hit;
    final seconds = video.duration.inMicroseconds / 1000000;
    // Short videos are encoded in full; longer videos sample three distinct regions.
    final sample = math.min(seconds / 3, 0.8 * options.speed);
    final positions = seconds <= 2.4 * options.speed
        ? [0.0]
        : [0.0, (seconds - sample) / 2, seconds - sample];
    final span = positions.length == 1 ? seconds : sample;
    var totalBytes = 0;
    final watch = Stopwatch()..start();
    for (final position in positions) {
      operation.check();
      final result = await _service.convert(
        video,
        options,
        operation,
        startSeconds: position,
        sampleSeconds: span,
      );
      try {
        totalBytes += result.sizeBytes;
      } finally {
        await File(result.path).delete();
      }
    }
    operation.check();
    final bytes = math.max(
      1,
      (totalBytes * seconds / (span * positions.length)).round(),
    );
    if (_cache.length >= 24) _cache.remove(_cache.keys.first);
    _cache[_key(video, options)] = bytes;
    _last = (video: video, options: options, bytes: bytes);
    // Diagnostic output contains no user file paths.
    debugPrint(
      'WebP estimate: $bytes bytes, ${watch.elapsedMilliseconds} ms, ${positions.length} samples',
    );
    return bytes;
  }
}
