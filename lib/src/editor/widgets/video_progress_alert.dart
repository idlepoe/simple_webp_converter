import 'package:flutter/material.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import '../utils/render_cancel_capability.dart';
import 'video_renderer_progress.dart';

// Adapted from the reference render dialog. Cancel only closes it on success.
class VideoProgressAlert extends StatefulWidget {
  const VideoProgressAlert({super.key, required this.taskId});
  final String taskId;
  @override
  State<VideoProgressAlert> createState() => _VideoProgressAlertState();
}

class _VideoProgressAlertState extends State<VideoProgressAlert> {
  bool _cancelling = false;
  String? _error;
  Future<void> _cancel() async {
    if (_cancelling) return;
    setState(() {
      _cancelling = true;
      _error = null;
    });
    try {
      await ProVideoEditor.instance.cancel(widget.taskId);
      LoadingDialog.instance.hide();
    } catch (error) {
      debugPrint('Render cancellation failed: $error');
      if (mounted) {
        setState(() {
          _cancelling = false;
          _error = 'Unable to cancel. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: Stack(
      children: [
        const ModalBarrier(dismissible: false, color: Colors.black54),
        Center(
          child: AlertDialog(
            title: const Text('Saving edited video'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                VideoRendererProgressPanel(
                  progressStream: ProVideoEditor.instance.progressStreamById(
                    widget.taskId,
                  ),
                  supportsCancel: false,
                ),
                if (_error != null) Text(_error!),
              ],
            ),
            actions: [
              if (canCancelOnCurrentPlatform())
                TextButton(
                  onPressed: _cancelling ? null : _cancel,
                  child: Text(_cancelling ? 'Cancelling' : 'Cancel'),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}
