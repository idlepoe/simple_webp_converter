import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_player/video_player.dart';

import '../models/selected_video.dart';
import 'gallery_provider.dart';
import '../widgets/playful_theme.dart';

// Adapted from video_converter's video_gallery_picker_screen.dart.
class VideoGalleryPickerScreen extends ConsumerStatefulWidget {
  const VideoGalleryPickerScreen({super.key});
  @override
  ConsumerState<VideoGalleryPickerScreen> createState() =>
      _VideoGalleryPickerScreenState();
}

class _VideoGalleryPickerScreenState
    extends ConsumerState<VideoGalleryPickerScreen>
    with WidgetsBindingObserver {
  final _thumbnailController = ScrollController();
  final _pageController = PageController();
  bool _appActive = true;
  bool _settingsOpened = false;
  bool _confirming = false;
  int _playbackCount = 1;
  int _gridColumns = 1;
  int _currentGroup = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() {
      if (mounted) ref.read(galleryProvider.notifier).load();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final active = state == AppLifecycleState.resumed;
    if (mounted && active != _appActive) setState(() => _appActive = active);
    if (active && _settingsOpened) {
      _settingsOpened = false;
      _currentGroup = 0;
      ref.read(galleryProvider.notifier).load();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    _thumbnailController.dispose();
    super.dispose();
  }

  Future<void> _confirm(AssetEntity asset) async {
    if (_confirming) return;
    setState(() => _confirming = true);
    try {
      final file = await asset.file;
      if (!mounted) return;
      if (file == null) {
        throw const FormatException('Unable to open the video file.');
      }
      Navigator.pop(
        context,
        PickedVideo(
          path: file.path,
          name: asset.title?.isNotEmpty == true
              ? asset.title!
              : file.uri.pathSegments.last,
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to open the video file. Please select it again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  Future<void> _pickFile() async {
    if (_confirming) return;
    setState(() => _confirming = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );
      if (!mounted || result == null || result.files.isEmpty) return;
      final file = result.files.single;
      if (file.path == null) {
        throw const FormatException('The file path is missing.');
      }
      Navigator.pop(context, PickedVideo(path: file.path!, name: file.name));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to select the file. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(galleryProvider);
    final groupCount = (state.assets.length / _playbackCount).ceil();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select video'),
        actions: [
          IconButton(
            onPressed: _confirming ? null : _pickFile,
            icon: const Icon(Icons.folder_open),
            tooltip: 'Choose file',
          ),
          IconButton(
            onPressed: _confirming ? null : _showSettings,
            icon: const Icon(Icons.tune),
            tooltip: 'Playback layout',
          ),
        ],
      ),
      body: _confirming
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(state, groupCount),
      bottomNavigationBar: state.loading || state.assets.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            state.selected == null
                                ? 'Select one video'
                                : state.selected!.title?.isNotEmpty == true
                                ? state.selected!.title!
                                : 'Selected video',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          Text(
                            state.selected == null
                                ? 'Tap a video or thumbnail.'
                                : '${state.selected!.duration}s · ${state.selected!.width} × ${state.selected!.height}',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    PlayfulButton.icon(
                      onPressed: _confirming || state.selected == null
                          ? null
                          : () => _confirm(state.selected!),
                      icon: const Icon(Icons.check),
                      label: const Text('Use video'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildBody(GalleryState state, int groupCount) {
    if (state.loading) return const Center(child: CircularProgressIndicator());
    if (state.permissionDenied || state.error != null || state.assets.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              state.error ??
                  (state.permissionDenied
                      ? 'Video access permission is required.'
                      : 'No videos are available.'),
            ),
            if (state.permissionDenied)
              TextButton(
                onPressed: () async {
                  _settingsOpened = true;
                  await PhotoManager.openSetting();
                },
                child: const Text('Open settings'),
              ),
            TextButton(
              onPressed: () {
                _currentGroup = 0;
                ref.read(galleryProvider.notifier).load();
              },
              child: const Text('Reload'),
            ),
            PlayfulButton(
              onPressed: _pickFile,
              child: const Text('Choose file'),
            ),
          ],
        ),
      );
    }
    final selectedIds = {if (state.selected != null) state.selected!.id};
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: groupCount,
            onPageChanged: (group) {
              setState(() => _currentGroup = group);
              if (_thumbnailController.hasClients) {
                _thumbnailController.animateTo(
                  (group * _playbackCount * 80.0).clamp(
                    0,
                    _thumbnailController.position.maxScrollExtent,
                  ),
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOut,
                );
              }
            },
            itemBuilder: (_, group) {
              final start = group * _playbackCount;
              return _PlayingVideoGrid(
                key: ValueKey('group_${group}_${_playbackCount}_$_gridColumns'),
                assets: state.assets.sublist(
                  start,
                  math.min(start + _playbackCount, state.assets.length),
                ),
                columns: _gridColumns,
                active: _appActive && group == _currentGroup,
                selectedIds: selectedIds,
                onSelect: ref.read(galleryProvider.notifier).select,
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            '${_currentGroup + 1} / $groupCount · Swipe up or down, or tap a thumbnail.',
          ),
        ),
        SizedBox(
          height: 96,
          child: ListView.separated(
            controller: _thumbnailController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(8),
            itemCount: state.assets.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, index) => _VideoNavigationThumbnail(
              key: ValueKey(state.assets[index].id),
              asset: state.assets[index],
              selected: selectedIds.contains(state.assets[index].id),
              onNavigate: () {
                ref.read(galleryProvider.notifier).select(state.assets[index]);
                _pageController.animateToPage(
                  index ~/ _playbackCount,
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOut,
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  void _showSettings() {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Simultaneous playback'),
              Wrap(
                spacing: 8,
                children: [1, 2, 4, 6, 8, 10, 12]
                    .map(
                      (count) => ChoiceChip(
                        label: Text('$count'),
                        selected: _playbackCount == count,
                        onSelected: (_) {
                          final anchor = _currentGroup * _playbackCount;
                          setState(() {
                            _playbackCount = count;
                            _currentGroup = anchor ~/ count;
                          });
                          setSheetState(() {});
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted && _pageController.hasClients) {
                              _pageController.jumpToPage(_currentGroup);
                            }
                          });
                        },
                      ),
                    )
                    .toList(),
              ),
              Text('Playback columns: $_gridColumns'),
              Slider(
                value: _gridColumns.toDouble(),
                min: 1,
                max: 6,
                divisions: 5,
                label: '$_gridColumns',
                onChanged: (value) {
                  setState(() => _gridColumns = value.round());
                  setSheetState(() {});
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayingVideoGrid extends StatelessWidget {
  const _PlayingVideoGrid({
    super.key,
    required this.assets,
    required this.columns,
    required this.active,
    required this.selectedIds,
    required this.onSelect,
  });
  final List<AssetEntity> assets;
  final int columns;
  final bool active;
  final Set<String> selectedIds;
  final ValueChanged<AssetEntity> onSelect;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, constraints) {
      final actualColumns = math.min(columns, math.max(1, assets.length));
      final rows = (assets.length / actualColumns).ceil();
      final tileWidth =
          (constraints.maxWidth - (actualColumns - 1) * 4) / actualColumns;
      final tileHeight =
          (constraints.maxHeight - (rows - 1) * 4) / math.max(1, rows);
      return GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: actualColumns,
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
          childAspectRatio: tileWidth / math.max(1, tileHeight),
        ),
        itemCount: assets.length,
        itemBuilder: (_, index) => _PlayingVideoTile(
          key: ValueKey('${assets[index].id}_$active'),
          asset: assets[index],
          active: active,
          selected: selectedIds.contains(assets[index].id),
          onSelect: () => onSelect(assets[index]),
        ),
      );
    },
  );
}

class _PlayingVideoTile extends StatefulWidget {
  const _PlayingVideoTile({
    super.key,
    required this.asset,
    required this.active,
    required this.selected,
    required this.onSelect,
  });
  final AssetEntity asset;
  final bool active;
  final bool selected;
  final VoidCallback onSelect;
  @override
  State<_PlayingVideoTile> createState() => _PlayingVideoTileState();
}

class _PlayingVideoTileState extends State<_PlayingVideoTile> {
  VideoPlayerController? _controller;
  late final Future<Uint8List?> _thumbnail;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _thumbnail = widget.asset.thumbnailDataWithSize(
      const ThumbnailSize.square(500),
      quality: 78,
    );
    if (widget.active) _startPlayback();
  }

  Future<void> _startPlayback() async {
    final token = ++_generation;
    VideoPlayerController? controller;
    try {
      final file = await widget.asset.file;
      if (!mounted || !widget.active || token != _generation || file == null) {
        return;
      }
      controller = VideoPlayerController.file(
        file,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      await controller.initialize();
      if (!mounted || !widget.active || token != _generation) {
        await controller.dispose();
        return;
      }
      await controller.setVolume(0);
      await controller.setLooping(true);
      await controller.play();
      if (!mounted || !widget.active || token != _generation) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
    } catch (error) {
      debugPrint('Gallery playback failed: $error');
      await controller?.dispose();
    }
  }

  @override
  void didUpdateWidget(covariant _PlayingVideoTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) _startPlayback();
    if (!widget.active && oldWidget.active) {
      _generation++;
      _controller?.dispose();
      _controller = null;
    }
  }

  @override
  void dispose() {
    _generation++;
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: widget.selected,
    label: widget.asset.title ?? 'Video preview',
    child: InkWell(
      onTap: widget.onSelect,
      child: Stack(
        fit: StackFit.expand,
        children: [
          FutureBuilder<Uint8List?>(
            future: _thumbnail,
            builder: (_, snapshot) => snapshot.data == null
                ? const Center(child: Icon(Icons.video_file_outlined))
                : Image.memory(snapshot.data!, fit: BoxFit.contain),
          ),
          if (_controller?.value.isInitialized == true)
            Center(
              child: AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: VideoPlayer(_controller!),
              ),
            ),
          Positioned(
            left: 8,
            bottom: 8,
            child: Chip(
              label: Text(
                '${widget.asset.duration ~/ 60}:${(widget.asset.duration % 60).toString().padLeft(2, '0')}',
              ),
            ),
          ),
          if (widget.selected)
            Positioned(
              right: 8,
              top: 8,
              child: const Card(
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.check_circle),
                ),
              ),
            ),
          if (widget.selected)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 3,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class _VideoNavigationThumbnail extends StatefulWidget {
  const _VideoNavigationThumbnail({
    super.key,
    required this.asset,
    required this.selected,
    required this.onNavigate,
  });
  final AssetEntity asset;
  final bool selected;
  final VoidCallback onNavigate;
  @override
  State<_VideoNavigationThumbnail> createState() =>
      _VideoNavigationThumbnailState();
}

class _VideoNavigationThumbnailState extends State<_VideoNavigationThumbnail> {
  late final Future<Uint8List?> _thumbnail;
  @override
  void initState() {
    super.initState();
    _thumbnail = widget.asset.thumbnailDataWithSize(
      const ThumbnailSize.square(200),
      quality: 70,
    );
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 72,
    child: InkWell(
      onTap: widget.onNavigate,
      child: Stack(
        fit: StackFit.expand,
        children: [
          FutureBuilder<Uint8List?>(
            future: _thumbnail,
            builder: (_, snapshot) => snapshot.data == null
                ? const Icon(Icons.video_file_outlined)
                : Image.memory(snapshot.data!, fit: BoxFit.cover),
          ),
          if (widget.selected)
            Align(
              alignment: Alignment.topRight,
              child: const Card(
                child: Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(Icons.check, size: 18),
                ),
              ),
            ),
          if (widget.selected)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 3,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
