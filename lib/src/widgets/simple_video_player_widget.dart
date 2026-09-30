import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

// Adapted from simple_video_player_widget.dart. The provider owns the controller;
// this widget only handles seeking and playback UI using default Material widgets.
class SimpleVideoPlayerWidget extends StatefulWidget {
  const SimpleVideoPlayerWidget({super.key, required this.videoController});
  final VideoPlayerController videoController;
  @override
  State<SimpleVideoPlayerWidget> createState() =>
      _SimpleVideoPlayerWidgetState();
}

class _SimpleVideoPlayerWidgetState extends State<SimpleVideoPlayerWidget> {
  double? _dragValue;
  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<VideoPlayerValue>(
        valueListenable: widget.videoController,
        builder: (context, value, _) {
          if (value.hasError) {
            return const Text(
              'Unable to play this video. Please select another file.',
            );
          }
          if (!value.isInitialized) {
            return const Center(child: CircularProgressIndicator());
          }
          final duration = value.duration.inMilliseconds;
          final position = duration == 0
              ? 0.0
              : (value.position.inMilliseconds / duration).clamp(0.0, 1.0);
          return Column(
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.4,
                ),
                child: AspectRatio(
                  aspectRatio: value.aspectRatio,
                  child: VideoPlayer(widget.videoController),
                ),
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: () => value.isPlaying
                        ? widget.videoController.pause()
                        : widget.videoController.play(),
                    icon: Icon(
                      value.isPlaying ? Icons.pause : Icons.play_arrow,
                    ),
                    tooltip: value.isPlaying ? 'Pause' : 'Play',
                  ),
                  Text(_formatDuration(value.position)),
                  Expanded(
                    child: Slider(
                      value: _dragValue ?? position,
                      onChanged: duration == 0
                          ? null
                          : (number) => setState(() => _dragValue = number),
                      onChangeEnd: (number) {
                        widget.videoController.seekTo(
                          Duration(milliseconds: (number * duration).round()),
                        );
                        setState(() => _dragValue = null);
                      },
                    ),
                  ),
                  Text(_formatDuration(value.duration)),
                ],
              ),
            ],
          );
        },
      );
  static String _formatDuration(Duration duration) =>
      '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
}
