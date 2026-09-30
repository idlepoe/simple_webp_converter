import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

final videoPlayerProvider = FutureProvider.autoDispose
    .family<VideoPlayerController, String>((ref, path) async {
      final controller = VideoPlayerController.file(File(path));
      ref.onDispose(() => unawaited(controller.dispose()));
      await controller.initialize();
      if (ref.mounted) await controller.setLooping(true);
      if (ref.mounted) await controller.play();
      return controller;
    });
