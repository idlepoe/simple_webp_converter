import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../models/conversion_options.dart';
import '../models/selected_video.dart';

final webpServiceProvider = Provider<WebpService>((ref) => WebpService());

class ConversionCancelled implements Exception {}

/// Each operation owns its native session. Cancellation also covers startup.
class WebpOperation {
  bool cancelled = false;
  int? _sessionId;
  Future<void> cancel() async {
    cancelled = true;
    final id = _sessionId;
    if (id != null) await FFmpegKit.cancel(id);
  }

  void check() {
    if (cancelled) throw ConversionCancelled();
  }
}

class WebpService {
  Future<void>? _cleanup;

  Future<void> _cleanPreviousResults(
    Directory directory,
    String inputPath,
  ) async {
    await for (final entry in directory.list()) {
      if (entry is! File) continue;
      final name = entry.uri.pathSegments.last;
      if (entry.path == inputPath) continue;
      if (!RegExp(r'^webp_(\d+\.webp|editor_\d+\.mp4)$').hasMatch(name)) {
        continue;
      }
      try {
        await entry.delete();
      } catch (error) {
        debugPrint('Old WebP cleanup failed: $error');
      }
    }
  }

  static ({int width, int height}) dimensions(
    SelectedVideo video,
    ConversionOptions options,
  ) {
    final short = math.min(video.width, video.height);
    final scale = options.resolution.shortSide == 0
        ? 1.0
        : math.min(1.0, options.resolution.shortSide / short);
    return (
      width: math.max(2, (video.width * scale / 2).floor() * 2),
      height: math.max(2, (video.height * scale / 2).floor() * 2),
    );
  }

  Future<ConversionResult> convert(
    SelectedVideo video,
    ConversionOptions options,
    WebpOperation operation, {
    double startSeconds = 0,
    double? sampleSeconds,
    void Function(double)? onProgress,
  }) async {
    operation.check();
    final directory = await getTemporaryDirectory();
    await (_cleanup ??= _cleanPreviousResults(directory, video.path));
    operation.check();
    final path =
        '${directory.path}/webp_${DateTime.now().microsecondsSinceEpoch}.webp';
    final size = dimensions(video, options);
    final inputSeconds =
        sampleSeconds ?? video.duration.inMicroseconds / 1000000;
    final outputSeconds = inputSeconds / options.speed;
    final args = <String>[
      '-y',
      '-hide_banner',
      '-loglevel',
      onProgress == null ? 'error' : 'info',
      if (startSeconds > 0) ...['-ss', '$startSeconds'],
      if (sampleSeconds != null) ...['-t', '$sampleSeconds'],
      '-i',
      video.path,
      '-an',
      '-vf',
      'setpts=(PTS-STARTPTS)/${options.speed},fps=${options.fps},scale=${size.width}:${size.height}:flags=lanczos${onProgress == null ? '' : ',showinfo=checksum=0'}',
      '-c:v',
      'libwebp_anim',
      '-quality',
      '${options.quality.round()}',
      '-compression_level',
      '4',
      '-loop',
      '0',
      path,
    ];
    final done = Completer<void>();
    try {
      operation.check();
      final session = await FFmpegKit.executeWithArgumentsAsync(
        args,
        (session) async {
          try {
            final code = await session.getReturnCode();
            if (operation.cancelled || ReturnCode.isCancel(code)) {
              throw ConversionCancelled();
            }
            if (!ReturnCode.isSuccess(code)) {
              debugPrint(
                'WebP FFmpeg failed: ${await session.getAllLogsAsString()}',
              );
              throw StateError(
                'WebP encoding failed. Lower the options or select another video.',
              );
            }
            done.complete();
          } catch (error, stack) {
            done.completeError(error, stack);
          }
        },
        (log) {
          // Animated WebP may buffer frames until the end. Filter timestamps
          // provide actual frame-processing progress while encoding is active.
          if (operation.cancelled || onProgress == null) return;
          final match = RegExp(
            r'pts_time:([\d.]+)',
          ).firstMatch(log.getMessage());
          final time = match == null ? null : double.tryParse(match.group(1)!);
          if (time != null && outputSeconds > 0) {
            onProgress((time / outputSeconds).clamp(0, 0.99));
          }
        },
        (statistics) {
          if (!operation.cancelled && outputSeconds > 0) {
            onProgress?.call(
              math
                  .max(
                    statistics.getTime() / (outputSeconds * 1000),
                    statistics.getVideoFrameNumber() /
                        (outputSeconds * options.fps),
                  )
                  .clamp(0, 0.99),
            );
          }
        },
      );
      operation._sessionId = session.getSessionId();
      if (operation.cancelled) await FFmpegKit.cancel(operation._sessionId);
      await done.future;
      operation.check();
      final file = File(path);
      final bytes = await file.length();
      if (bytes <= 12) throw StateError('The converted file is empty.');
      return ConversionResult(
        path: path,
        sizeBytes: bytes,
        width: size.width,
        height: size.height,
        duration: Duration(microseconds: (outputSeconds * 1000000).round()),
      );
    } catch (_) {
      final file = File(path);
      if (await file.exists()) await file.delete();
      rethrow;
    } finally {
      operation._sessionId = null;
    }
  }
}
