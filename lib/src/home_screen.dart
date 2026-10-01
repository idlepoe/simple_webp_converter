import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'editor/video_editor_screen.dart';
import 'models/converter_state.dart';
import 'models/selected_video.dart';
import 'picker/video_gallery_picker_screen.dart';
import 'providers/converter_provider.dart';
import 'providers/video_player_provider.dart';
import 'widgets/simple_video_player_widget.dart';
import 'widgets/conversion_options_sheet.dart';
import 'providers/options_provider.dart';
import 'services/result_service.dart';
import 'widgets/playful_theme.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  bool _routeOpen = false;
  bool _resultBusy = false;

  Future<void> _convert() async {
    if (_routeOpen || ref.read(converterProvider).isBusy) return;
    setState(() => _routeOpen = true);
    final subscription = ref.listenManual(optionsDraftProvider, (_, _) {});
    try {
      await _pausePreview();
      if (!mounted) return;
      final options = await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => const ConversionOptionsSheet(),
      );
      await ref.read(optionsDraftProvider.notifier).stop();
      if (!mounted || options == null) return;
      unawaited(ref.read(converterProvider.notifier).convert(options));
    } finally {
      subscription.close();
      if (mounted) setState(() => _routeOpen = false);
    }
  }

  Future<void> _useResult(String path, bool save) async {
    if (_resultBusy) return;
    setState(() => _resultBusy = true);
    try {
      final service = ResultService();
      if (save) {
        await ref.read(converterProvider.notifier).retrySave();
      } else {
        final box = context.findRenderObject() as RenderBox;
        await service.share(path, box.localToGlobal(Offset.zero) & box.size);
      }
    } catch (error) {
      debugPrint('Result action failed: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              save
                  ? 'Unable to save. Check permissions and available storage.'
                  : 'Unable to share. Please try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _resultBusy = false);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _pausePreview() async {
    if (!mounted) return;
    try {
      final video = ref.read(converterProvider).video;
      if (video != null) {
        await ref.read(videoPlayerProvider(video.path)).asData?.value.pause();
      }
    } catch (error) {
      debugPrint('Preview pause failed: $error');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) unawaited(_pausePreview());
  }

  Future<void> _pickVideo() async {
    if (_routeOpen || ref.read(converterProvider).isBusy) return;
    setState(() => _routeOpen = true);
    try {
      await _pausePreview();
      if (!mounted) return;
      final selected = await Navigator.push<PickedVideo>(
        context,
        MaterialPageRoute(builder: (_) => const VideoGalleryPickerScreen()),
      );
      if (!mounted || selected == null) return;
      await ref
          .read(converterProvider.notifier)
          .loadVideo(selected.path, name: selected.name);
    } catch (error) {
      debugPrint('Video selection failed: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to select a video. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _routeOpen = false);
    }
  }

  Future<void> _editVideo() async {
    final state = ref.read(converterProvider);
    final video = state.video;
    if (_routeOpen || state.isBusy || video == null) return;
    setState(() => _routeOpen = true);
    try {
      await _pausePreview();
      if (!mounted) return;
      final exported = await Navigator.push<XFile>(
        context,
        MaterialPageRoute(
          builder: (_) => VideoEditorScreen(initialFilePath: video.path),
        ),
      );
      if (!mounted || exported == null) return;
      await ref
          .read(converterProvider.notifier)
          .loadVideo(exported.path, name: 'Edited_${video.name}');
    } catch (error) {
      debugPrint('Video editing failed: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to edit the video. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _routeOpen = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(converterProvider);
    final video = state.video;
    final preview = video == null
        ? null
        : ref.watch(videoPlayerProvider(video.path));
    return Scaffold(
      appBar: AppBar(
        title: const Text('VidToWebp'),
        leading: Padding(
          padding: const EdgeInsets.all(10),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset('assets/icon/icon.png'),
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (video == null)
              Card(
                color: const Color(0xFFEDFACD),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 36,
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.movie_creation_rounded,
                        size: 80,
                        color: Color(0xFF58A700),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Make your video pop!',
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Pick a video. Make a WebP.\nSaved to your gallery, just like that.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              Card(
                child: ListTile(
                  leading: const Icon(Icons.video_file_outlined),
                  title: Text(video.name),
                  subtitle: Text(
                    '${video.width} × ${video.height} · ${(video.duration.inMilliseconds / 1000).toStringAsFixed(1)}s · ${_megabytes(video.sizeBytes)} MB'
                    '${video.sourceFps == null ? '' : ' · ${video.sourceFps!.toStringAsFixed(1)} FPS'}',
                  ),
                ),
              ),
            const SizedBox(height: 16),
            if (state.isLoadingVideo)
              const Center(child: CircularProgressIndicator())
            else if (preview != null)
              preview.when(
                data: (controller) => SimpleVideoPlayerWidget(
                  key: ValueKey(video!.path),
                  videoController: controller,
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => const Text(
                  'Unable to play this video. Please select another file.',
                ),
              ),
            const SizedBox(height: 16),
            PlayfulButton.icon(
              onPressed: state.isBusy || _routeOpen ? null : _pickVideo,
              icon: const Icon(Icons.folder_open),
              label: Text(
                video == null ? 'Select video' : 'Select another video',
              ),
            ),
            if (video != null) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: state.isBusy || _routeOpen || preview?.asData == null
                    ? null
                    : _editVideo,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit video'),
              ),
              const SizedBox(height: 8),
              PlayfulButton.icon(
                onPressed: state.isBusy || _routeOpen || _resultBusy
                    ? null
                    : _convert,
                icon: const Icon(Icons.transform),
                label: const Text('Convert to WebP'),
              ),
            ],
            if (state.isConverting) ...[
              const SizedBox(height: 24),
              Text(
                state.status == ConversionStatus.preparing
                    ? 'Preparing conversion'
                    : state.status == ConversionStatus.saving
                    ? 'Saving to gallery'
                    : 'Converting',
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value:
                    state.status == ConversionStatus.preparing ||
                        state.status == ConversionStatus.saving
                    ? null
                    : state.progress,
              ),
              Text('${(state.progress * 100).round()}%'),
              if (state.status != ConversionStatus.saving)
                OutlinedButton(
                  onPressed: () =>
                      ref.read(converterProvider.notifier).cancel(),
                  child: const Text('Cancel'),
                ),
            ],
            if (state.status == ConversionStatus.cancelled)
              const Text('Conversion cancelled.'),
            if (state.error != null) Text(state.error!),
            if (state.result case final result?) ...[
              const SizedBox(height: 24),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.check_circle_outline),
                  title: const Text('Conversion complete'),
                  subtitle: Text(
                    'Actual size: ${_megabytes(result.sizeBytes)} MB',
                  ),
                ),
              ),
              if (state.isResultSaved)
                const Text('Saved to Pictures/WebP Converter.'),
              Image.file(
                File(result.path),
                key: ValueKey(result.path),
                height: 240,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Text(
                  'Unable to display the preview. Save or share the file to view it.',
                ),
              ),
              Wrap(
                spacing: 8,
                children: [
                  if (!state.isResultSaved)
                    PlayfulButton(
                      onPressed: _resultBusy || state.isBusy
                          ? null
                          : () => _useResult(result.path, true),
                      child: const Text('Retry save'),
                    ),
                  OutlinedButton(
                    onPressed: _resultBusy || state.isBusy
                        ? null
                        : () => _useResult(result.path, false),
                    child: const Text('Share'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _megabytes(int bytes) => (bytes / 1000000).toStringAsFixed(1);
}
