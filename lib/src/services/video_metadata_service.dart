import 'dart:io';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

import '../models/selected_video.dart';

final videoMetadataServiceProvider = Provider<VideoMetadataService>(
  (ref) => VideoMetadataService(),
);

class VideoMetadataService {
  Future<SelectedVideo> load(String path, {String? name}) async {
    final file = File(path);
    final size = await file.length();
    final metadata = await ProVideoEditor.instance.getMetadata(
      EditorVideo.file(path),
    );
    final width = metadata.resolution.width.round();
    final height = metadata.resolution.height.round();
    if (width <= 0 ||
        height <= 0 ||
        metadata.duration <= Duration.zero ||
        size == 0) {
      throw const FormatException('This file is not a playable video.');
    }
    var fps = metadata.frameRate;
    if (fps == null || !fps.isFinite || fps <= 0) {
      try {
        final session = await FFprobeKit.getMediaInformation(path);
        final streams = session.getMediaInformation()?.getStreams() ?? [];
        for (final stream in streams) {
          if (stream.getType() != 'video') continue;
          final rate = stream.getAverageFrameRate()?.split('/');
          if (rate != null && rate.length == 2) {
            final numerator = double.tryParse(rate[0]);
            final denominator = double.tryParse(rate[1]);
            if (numerator != null && denominator != null && denominator > 0) {
              fps = numerator / denominator;
            }
          }
          break;
        }
      } catch (_) {
        /* FPS is optional; loading remains usable. */
      }
    }
    return SelectedVideo(
      path: path,
      name: name ?? file.uri.pathSegments.last,
      width: width,
      height: height,
      duration: metadata.duration,
      sizeBytes: size,
      sourceFps: fps != null && fps.isFinite && fps > 0 ? fps : null,
    );
  }
}
