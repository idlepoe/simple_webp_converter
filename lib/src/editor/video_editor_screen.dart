import 'dart:async';
import 'dart:io' as io;
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:video_player/video_player.dart';

import 'services/audio_helper_service.dart';
import 'widgets/clips_previewer.dart';
import 'widgets/sticker_picker.dart';
import 'widgets/video_initializing_widget.dart';
import 'widgets/video_progress_alert.dart';

// Adapted from video_converter's video_editor_grounded_page.dart.
// Rendering and tool callbacks are retained; custom Grounded UI is removed.
class VideoEditorScreen extends StatefulWidget {
  const VideoEditorScreen({super.key, required this.initialFilePath});
  final String initialFilePath;
  @override
  State<VideoEditorScreen> createState() => _VideoEditorScreenState();
}

class _VideoEditorScreenState extends State<VideoEditorScreen>
    with WidgetsBindingObserver {
  final _editorKey = GlobalKey<ProImageEditorState>();
  final _proVideoEditor = ProVideoEditor.instance;
  final _taskId = 'editor_${DateTime.now().microsecondsSinceEpoch}';
  final _cachedKeyFrames = <String, Uint8List>{};
  final _cachedKeyFrameList = <String, List<Uint8List>>{};
  final _temporaryPaths = <String>{};
  final _updateClipsNotifier = ValueNotifier(false);
  final _audioTracks = <AudioTrack>[];
  final _thumbnailCount = 7;
  late EditorVideo _video;
  late VideoPlayerController _videoController;
  late AudioHelperService _audioService;
  late VideoMetadata _videoMetadata;
  ProVideoController? _proVideoController;
  List<ImageProvider>? _thumbnails;
  TrimDurationSpan? _durationSpan;
  TrimDurationSpan? _tempDurationSpan;
  bool _isSeeking = false;
  bool _isRendering = false;
  bool _ignoreNextCloseAfterCancel = false;
  bool _readingAudio = false;
  String? _initializationError;
  String? _outputPath;

  late final _configs = ProImageEditorConfigs(
    // Material is the package default. Only functional settings are supplied.
    dialogConfigs: DialogConfigs(
      widgets: DialogWidgets(
        loadingDialog: (message, configs) =>
            VideoProgressAlert(taskId: _taskId),
      ),
    ),
    mainEditor: const MainEditorConfigs(
      tools: [
        SubEditorMode.videoClips,
        SubEditorMode.audio,
        SubEditorMode.paint,
        SubEditorMode.text,
        SubEditorMode.cropRotate,
        SubEditorMode.tune,
        SubEditorMode.filter,
        SubEditorMode.blur,
        SubEditorMode.emoji,
        SubEditorMode.sticker,
      ],
    ),
    paintEditor: const PaintEditorConfigs(
      tools: [
        PaintMode.freeStyle,
        PaintMode.arrow,
        PaintMode.line,
        PaintMode.rect,
        PaintMode.circle,
        PaintMode.dashLine,
        PaintMode.polygon,
        PaintMode.eraser,
      ],
    ),
    stickerEditor: StickerEditorConfigs(
      builder: (setLayer, scrollController) =>
          StickerPicker(setLayer: setLayer, scrollController: scrollController),
    ),
    audioEditor: AudioEditorConfigs(audioTracks: _audioTracks),
    clipsEditor: ClipsEditorConfigs(
      clips: [
        VideoClip(
          id: 'initial',
          title: io.File(widget.initialFilePath).uri.pathSegments.last,
          duration: Duration.zero,
          clip: EditorVideoClip.file(widget.initialFilePath),
        ),
      ],
    ),
    videoEditor: const VideoEditorConfigs(
      initialMuted: false,
      initialPlay: false,
      isAudioSupported: true,
      minTrimDuration: Duration(milliseconds: 100),
    ),
    imageGeneration: const ImageGenerationConfigs(
      captureImageByteFormat: ImageByteFormat.rawStraightRgba,
    ),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _video = EditorVideo.file(widget.initialFilePath);
    _videoController = VideoPlayerController.file(
      io.File(widget.initialFilePath),
    );
    _audioService = AudioHelperService(videoController: _videoController);
    _initializePlayer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_isRendering) {
      unawaited(_proVideoEditor.cancel(_taskId).catchError((Object _) {}));
    }
    _videoController.removeListener(_onDurationChange);
    _videoController.dispose();
    _audioService.dispose();
    _updateClipsNotifier.dispose();
    for (final path in _temporaryPaths) {
      unawaited(_deleteTemporary(path));
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      unawaited(_pausePlayback());
    }
  }

  Future<void> _pausePlayback() async {
    try {
      await _videoController.pause();
      await _audioService.pause();
    } catch (error) {
      debugPrint('Editor pause failed: $error');
    }
  }

  Future<void> _deleteTemporary(String path) async {
    try {
      final file = io.File(path);
      if (await file.exists()) await file.delete();
    } on io.FileSystemException catch (_) {
      /* The OS can clean remaining cache files. */
    }
  }

  Future<void> _setMetadata() async {
    _videoMetadata = await _proVideoEditor.getMetadata(_video);
    if (_videoMetadata.duration <= Duration.zero ||
        _videoMetadata.resolution.isEmpty) {
      throw const FormatException('This video is not playable.');
    }
  }

  Future<void> _generateThumbnails({bool updateClipThumbnails = true}) async {
    if (!mounted) return;
    final imageWidth =
        MediaQuery.sizeOf(context).width /
        _thumbnailCount *
        MediaQuery.devicePixelRatioOf(context);
    final segmentDuration =
        _videoMetadata.duration.inMilliseconds / _thumbnailCount;
    final thumbnailList = await _proVideoEditor.getThumbnails(
      ThumbnailConfigs(
        video: _video,
        outputSize: Size.square(imageWidth),
        boxFit: ThumbnailBoxFit.cover,
        timestamps: List.generate(
          _thumbnailCount,
          (i) => Duration(milliseconds: ((i + 0.5) * segmentDuration).round()),
        ),
        outputFormat: ThumbnailFormat.jpeg,
      ),
    );
    if (!mounted) return;
    _thumbnails = thumbnailList.map(MemoryImage.new).toList();
    if (updateClipThumbnails && _configs.clipsEditor.clips.isNotEmpty) {
      _configs.clipsEditor.clips.first = _configs.clipsEditor.clips.first
          .copyWith(thumbnails: _thumbnails);
    }
    _proVideoController?.thumbnails = _thumbnails;
  }

  Future<void> _initializePlayer() async {
    try {
      await Future.wait([
        _setMetadata(),
        _videoController.initialize(),
        _audioService.initialize(),
      ]);
      if (!mounted) return;
      await _videoController.setLooping(false);
      await _videoController.setVolume(1);
      if (!mounted) return;
      _configs.clipsEditor.clips.first = _configs.clipsEditor.clips.first
          .copyWith(duration: _videoMetadata.duration);
      try {
        await _generateThumbnails();
      } catch (error) {
        debugPrint('Timeline thumbnails failed: $error');
      }
      if (!mounted) return;
      _proVideoController = ProVideoController(
        videoPlayer: _buildVideoPlayer(),
        initialResolution: _videoMetadata.resolution,
        videoDuration: _videoMetadata.duration,
        fileSize: _videoMetadata.fileSize,
        thumbnails: _thumbnails,
      );
      _videoController.addListener(_onDurationChange);
      setState(() {});
    } catch (error) {
      debugPrint('Editor initialization failed: $error');
      if (mounted) {
        setState(
          () => _initializationError =
              'Unable to edit this video. Please select another file.',
        );
      }
    }
  }

  void _onDurationChange() {
    if (!mounted || _proVideoController == null || _isSeeking) return;
    final duration = _videoController.value.position;
    _proVideoController!.setPlayTime(duration);
    if (_durationSpan != null && duration >= _durationSpan!.end) {
      _seekToPosition(_durationSpan!);
    } else if (duration >= _videoMetadata.duration) {
      _seekToPosition(
        TrimDurationSpan(start: Duration.zero, end: _videoMetadata.duration),
      );
    }
  }

  Future<void> _seekToPosition(TrimDurationSpan span) async {
    _durationSpan = span;
    if (_isSeeking) {
      _tempDurationSpan = span;
      return;
    }
    _isSeeking = true;
    _proVideoController?.pause();
    _proVideoController?.setPlayTime(span.start);
    try {
      await _videoController.pause();
      if (mounted) await _videoController.seekTo(span.start);
    } finally {
      _isSeeking = false;
    }
    if (mounted && _tempDurationSpan != null) {
      final nextSeek = _tempDurationSpan!;
      _tempDurationSpan = null;
      await _seekToPosition(nextSeek);
    }
  }

  Future<void> generateVideo(CompleteParameters parameters) async {
    if (_isRendering) return;
    setState(() => _isRendering = true);
    _outputPath = null;
    try {
      await _videoController.pause();
      await _audioService.pause();
      final track = parameters.customAudioTrack;
      final audioPath = await _audioService.safeCustomAudioPath(track);
      if (!mounted) return;
      final exportModel = VideoRenderData(
        id: _taskId,
        // Keep the reference editor's render contract for this pinned version.
        // ignore: deprecated_member_use
        video: _video,
        outputFormat: VideoOutputFormat.mp4,
        enableAudio: _proVideoController?.isAudioEnabled ?? true,
        // ignore: deprecated_member_use
        imageBytes: parameters.layers.isNotEmpty ? parameters.image : null,
        blur: parameters.blur,
        // ignore: deprecated_member_use
        colorMatrixList: parameters.colorFilters,
        startTime: parameters.startTime,
        endTime: parameters.endTime,
        transform: parameters.isTransformed
            ? ExportTransform(
                width: parameters.cropWidth,
                height: parameters.cropHeight,
                rotateTurns: parameters.rotateTurns,
                x: parameters.cropX,
                y: parameters.cropY,
                flipX: parameters.flipX,
                flipY: parameters.flipY,
              )
            : null,
        // ignore: deprecated_member_use
        customAudioPath: audioPath,
        // ignore: deprecated_member_use
        customAudioStartTime: track?.startTime,
        // ignore: deprecated_member_use
        originalAudioVolume: track == null
            ? 1
            : 1 - track.volumeBalance.clamp(0, 1),
        // ignore: deprecated_member_use
        customAudioVolume: track == null
            ? 1
            : 1 + track.volumeBalance.clamp(-1, 0),
      );
      final directory = await getTemporaryDirectory();
      if (!mounted) return;
      final path =
          '${directory.path}/webp_editor_${DateTime.now().microsecondsSinceEpoch}.mp4';
      _temporaryPaths.add(path);
      final exported = await _proVideoEditor.renderVideoToFile(
        path,
        exportModel,
      );
      if (mounted) {
        _outputPath = exported;
      } else {
        await _deleteTemporary(exported);
      }
    } on RenderCanceledException {
      _ignoreNextCloseAfterCancel = true;
    } on PlatformException catch (error) {
      if (error.code.toUpperCase() == 'CANCELED' ||
          error.message?.contains('CancellationError') == true) {
        _ignoreNextCloseAfterCancel = true;
      } else {
        _handleExportError(error);
      }
    } catch (error) {
      _handleExportError(error);
    } finally {
      if (mounted) setState(() => _isRendering = false);
    }
  }

  void _handleExportError(Object error) {
    debugPrint('Editor export failed: $error');
    _ignoreNextCloseAfterCancel = true;
    LoadingDialog.instance.hide();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to save the edited video. Please try again.'),
        ),
      );
    }
  }

  void onCloseEditor(EditorMode mode) {
    if (!mounted) return;
    if (mode != EditorMode.main) {
      Navigator.pop(context);
      return;
    }
    if (_ignoreNextCloseAfterCancel) {
      _ignoreNextCloseAfterCancel = false;
      return;
    }
    if (_isRendering) return;
    final exported = _outputPath;
    if (exported != null) _temporaryPaths.remove(exported);
    Navigator.pop(context, exported == null ? null : XFile(exported));
  }

  Future<VideoClip?> _addClip() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: false,
    );
    if (!mounted || result == null || result.files.isEmpty) return null;
    final file = result.files.single;
    if (file.path == null) return null;
    try {
      final meta = await _proVideoEditor.getMetadata(
        EditorVideo.file(file.path!),
      );
      if (!mounted) return null;
      return VideoClip(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: file.name,
        clip: EditorVideoClip.file(file.path!),
        duration: meta.duration,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to read the video to add.')),
        );
      }
      return null;
    }
  }

  Future<void> _addAudio() async {
    if (_readingAudio || _isRendering) return;
    setState(() => _readingAudio = true);
    try {
      await _videoController.pause();
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );
      if (!mounted || result == null || result.files.isEmpty) return;
      final file = result.files.single;
      if (file.path == null) return;
      final metadata = await _proVideoEditor.getMetadata(
        EditorVideo.file(file.path!),
      );
      if (!mounted) return;
      _audioTracks.add(
        AudioTrack(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          title: file.name,
          subtitle: '',
          duration: metadata.duration,
          audio: EditorAudio.file(file.path!),
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select the added file from the Audio menu.'),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to read the audio file.')),
        );
      }
    } finally {
      if (mounted) setState(() => _readingAudio = false);
    }
  }

  Future<void> _mergeClips(
    List<VideoClip> clips,
    void Function(double) onProgress,
  ) async {
    if (_isRendering || clips.isEmpty) return;
    setState(() => _isRendering = true);
    _updateClipsNotifier.value = true;
    LoadingDialog.instance.show(context, configs: _configs);
    final subscription = _proVideoEditor
        .progressStreamById(_taskId)
        .listen((event) => onProgress(event.progress));
    VideoPlayerController? newController;
    AudioHelperService? newAudio;
    try {
      await _videoController.pause();
      await _audioService.pause();
      final directory = await getApplicationCacheDirectory();
      if (!mounted) return;
      final path =
          '${directory.path}/webp_editor_merge_${DateTime.now().microsecondsSinceEpoch}.mp4';
      _temporaryPaths.add(path);
      await _proVideoEditor.renderVideoToFile(
        path,
        VideoRenderData(
          id: _taskId,
          videoSegments: clips
              .map(
                (clip) => VideoSegment(
                  video: EditorVideo.autoSource(
                    networkUrl: clip.clip.networkUrl,
                    assetPath: clip.clip.assetPath,
                    byteArray: clip.clip.bytes,
                    file: clip.clip.file,
                  ),
                  startTime: clip.trimSpan?.start,
                  endTime: clip.trimSpan?.end,
                ),
              )
              .toList(),
        ),
      );
      if (!mounted) return;
      newController = VideoPlayerController.file(io.File(path));
      newAudio = AudioHelperService(videoController: newController);
      final metadata = await _proVideoEditor.getMetadata(
        EditorVideo.file(path),
      );
      await Future.wait([newController.initialize(), newAudio.initialize()]);
      if (!mounted) return;
      final oldController = _videoController;
      final oldAudio = _audioService;
      oldController.removeListener(_onDurationChange);
      _videoController = newController;
      _audioService = newAudio;
      newController = null;
      newAudio = null;
      _video = EditorVideo.file(path);
      _videoMetadata = metadata;
      _durationSpan = null;
      _tempDurationSpan = null;
      await oldAudio.dispose();
      await oldController.dispose();
      if (!mounted) return;
      try {
        await _generateThumbnails(updateClipThumbnails: false);
      } catch (error) {
        debugPrint('Merged timeline failed: $error');
      }
      if (!mounted) return;
      final editor = _editorKey.currentState;
      if (editor == null) return;
      _proVideoController =
          ProVideoController(
            videoPlayer: _buildVideoPlayer(),
            initialResolution: metadata.resolution,
            videoDuration: metadata.duration,
            fileSize: metadata.fileSize,
            thumbnails: _thumbnails,
          )..initialize(
            configsFunction: () => _configs.videoEditor,
            callbacksAudioFunction: () =>
                editor.audioEditorCallbacks ?? const AudioEditorCallbacks(),
            callbacksFunction: () =>
                editor.callbacks.videoEditorCallbacks ?? VideoEditorCallbacks(),
          );
      _videoController.addListener(_onDurationChange);
      editor.initializeVideoEditor();
    } on RenderCanceledException {
      // Keep the current video and allow another edit.
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to merge the videos. Please try again.'),
          ),
        );
      }
      debugPrint('Clip merge failed: $error');
    } finally {
      await subscription.cancel();
      await newAudio?.dispose();
      await newController?.dispose();
      LoadingDialog.instance.hide();
      if (mounted) {
        _updateClipsNotifier.value = false;
        setState(() => _isRendering = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_initializationError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit video')),
        body: Center(child: Text(_initializationError!)),
      );
    }
    if (_proVideoController == null) return const VideoInitializingWidget();
    return PopScope(
      canPop: !_isRendering,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Edit video'),
          actions: [
            IconButton(
              onPressed: _readingAudio || _isRendering ? null : _addAudio,
              icon: const Icon(Icons.audio_file_outlined),
              tooltip: 'Add audio file',
            ),
          ],
        ),
        body: ProImageEditor.video(
          _proVideoController!,
          key: _editorKey,
          callbacks: ProImageEditorCallbacks(
            onCompleteWithParameters: generateVideo,
            onCloseEditor: onCloseEditor,
            videoEditorCallbacks: VideoEditorCallbacks(
              onPause: _videoController.pause,
              onPlay: _videoController.play,
              onMuteToggle: (isMuted) {
                if (isMuted) {
                  _audioService.setVolume(0);
                  _videoController.setVolume(0);
                } else {
                  _audioService.balanceAudio();
                }
              },
              onTrimSpanUpdate: (durationSpan) {
                if (_videoController.value.isPlaying) {
                  _proVideoController!.pause();
                }
              },
              onTrimSpanEnd: _seekToPosition,
            ),
            audioEditorCallbacks: AudioEditorCallbacks(
              onBalanceChange: _audioService.balanceAudio,
              onStartTimeChange: (startTime) async {
                await Future.wait([
                  _audioService.seek(startTime),
                  _videoController.seekTo(Duration.zero),
                ]);
              },
              onPlay: _audioService.play,
              onStop: (audio) => _audioService.pause(),
            ),
            clipsEditorCallbacks: ClipsEditorCallbacks(
              onBuildPlayer: (controller, videoClip) {
                return ClipsPreviewer(
                  videoConfigs: _configs.videoEditor,
                  proController: controller,
                  videoClip: videoClip,
                );
              },
              onMergeClips: _mergeClips,
              onReadKeyFrame: (source) async {
                if (_cachedKeyFrames.containsKey(source.id)) {
                  return _cachedKeyFrames[source.id]!;
                }

                final result = await _proVideoEditor.getKeyFrames(
                  KeyFramesConfigs(
                    video: EditorVideo.autoSource(
                      assetPath: source.clip.assetPath,
                      byteArray: source.clip.bytes,
                      file: source.clip.file,
                      networkUrl: source.clip.networkUrl,
                    ),
                    outputSize: const Size.square(200),
                    boxFit: ThumbnailBoxFit.cover,
                    maxOutputFrames: 1,
                    outputFormat: ThumbnailFormat.jpeg,
                  ),
                );
                if (result.isEmpty) {
                  throw const FormatException('No thumbnails are available.');
                }
                _cachedKeyFrames[source.id] = result.first;
                return result.first;
              },
              onReadKeyFrames: (source) async {
                if (_cachedKeyFrameList.containsKey(source.id)) {
                  return _cachedKeyFrameList[source.id]!;
                }

                final result = await _proVideoEditor.getKeyFrames(
                  KeyFramesConfigs(
                    video: EditorVideo.autoSource(
                      assetPath: source.clip.assetPath,
                      byteArray: source.clip.bytes,
                      file: source.clip.file,
                      networkUrl: source.clip.networkUrl,
                    ),
                    outputSize: const Size.square(200),
                    boxFit: ThumbnailBoxFit.cover,
                    maxOutputFrames: _thumbnailCount,
                    outputFormat: ThumbnailFormat.jpeg,
                  ),
                );
                _cachedKeyFrameList[source.id] = result;
                return result;
              },
              onAddClip: _addClip,
            ),
          ),

          configs: _configs,
        ),
      ),
    );
  }

  Widget _buildVideoPlayer() => ValueListenableBuilder(
    valueListenable: _updateClipsNotifier,
    builder: (_, isLoading, _) => Center(
      child: isLoading
          ? const CircularProgressIndicator()
          : AspectRatio(
              aspectRatio: _videoController.value.aspectRatio,
              child: VideoPlayer(_videoController),
            ),
    ),
  );
}
