import 'dart:async';
import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:video_player/video_player.dart';

// Adapted from video_converter's clips_previewer.dart with async-safe disposal.
class ClipsPreviewer extends StatefulWidget {
  const ClipsPreviewer({
    super.key,
    required this.proController,
    required this.videoConfigs,
    required this.videoClip,
  });
  final ProVideoController proController;
  final VideoEditorConfigs videoConfigs;
  final VideoClip videoClip;
  @override
  State<ClipsPreviewer> createState() => _ClipsPreviewerState();
}

class _ClipsPreviewerState extends State<ClipsPreviewer> {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _isSeeking = false;
  String? _error;
  String? _temporaryPath;
  TrimDurationSpan? _durationSpan;
  TrimDurationSpan? _pendingSpan;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  @override
  void dispose() {
    _controller?.removeListener(_onPosition);
    _controller?.dispose();
    final path = _temporaryPath;
    if (path != null) unawaited(_deleteTemporary(path));
    super.dispose();
  }

  Future<void> _deleteTemporary(String path) async {
    try {
      final file = io.File(path);
      if (await file.exists()) await file.delete();
    } on io.FileSystemException catch (_) {}
  }

  Future<void> _initializePlayer() async {
    try {
      final video = widget.videoClip.clip;
      if (video.hasFile) {
        _controller = VideoPlayerController.file(io.File(video.file!.path));
      } else if (video.hasAssetPath) {
        _controller = VideoPlayerController.asset(video.assetPath!);
      } else if (video.hasNetworkUrl) {
        _controller = VideoPlayerController.networkUrl(
          Uri.parse(video.networkUrl!),
        );
      } else {
        final directory = await getApplicationCacheDirectory();
        if (!mounted) return;
        final path =
            '${directory.path}/webp_clip_${DateTime.now().microsecondsSinceEpoch}.mp4';
        await io.File(path).writeAsBytes(video.bytes!);
        if (!mounted) {
          await _deleteTemporary(path);
          return;
        }
        _temporaryPath = path;
        _controller = VideoPlayerController.file(io.File(path));
      }
      final controller = _controller!;
      await controller.initialize();
      if (!mounted) return;
      await controller.setVolume(widget.videoConfigs.initialMuted ? 0 : 1);
      if (!mounted) return;
      widget.proController.initialize(
        callbacksAudioFunction: () => const AudioEditorCallbacks(),
        callbacksFunction: () => VideoEditorCallbacks(
          onPause: controller.pause,
          onPlay: controller.play,
          onMuteToggle: (muted) => controller.setVolume(muted ? 0 : 1),
          onTrimSpanUpdate: (_) {
            if (controller.value.isPlaying) widget.proController.pause();
          },
          onTrimSpanEnd: _seekToPosition,
        ),
        configsFunction: () => widget.videoConfigs,
      );
      controller.addListener(_onPosition);
      setState(() => _ready = true);
    } catch (error) {
      debugPrint('Clip preview failed: $error');
      if (mounted) setState(() => _error = 'Unable to play the clip.');
    }
  }

  void _onPosition() {
    final controller = _controller;
    if (!mounted || controller == null || _isSeeking) return;
    final position = controller.value.position;
    widget.proController.setPlayTime(position);
    final span = _durationSpan;
    if (span != null && position >= span.end) {
      _seekToPosition(span);
    } else if (position >= controller.value.duration) {
      _seekToPosition(
        TrimDurationSpan(start: Duration.zero, end: controller.value.duration),
      );
    }
  }

  Future<void> _seekToPosition(TrimDurationSpan span) async {
    _durationSpan = span;
    if (_isSeeking) {
      _pendingSpan = span;
      return;
    }
    _isSeeking = true;
    widget.proController.pause();
    widget.proController.setPlayTime(span.start);
    try {
      await _controller?.pause();
      if (mounted) await _controller?.seekTo(span.start);
    } finally {
      _isSeeking = false;
    }
    if (mounted && _pendingSpan != null) {
      final next = _pendingSpan!;
      _pendingSpan = null;
      await _seekToPosition(next);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return Center(child: Text(_error!));
    if (!_ready) return const Center(child: CircularProgressIndicator());
    return Center(
      child: AspectRatio(
        aspectRatio: _controller!.value.aspectRatio,
        child: VideoPlayer(_controller!),
      ),
    );
  }
}
