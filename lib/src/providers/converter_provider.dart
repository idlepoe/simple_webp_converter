import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../models/conversion_options.dart';
import '../models/converter_state.dart';
import '../models/selected_video.dart';
import '../services/video_metadata_service.dart';
import '../services/options_repository.dart';
import '../services/webp_service.dart';
import '../services/notification_service.dart';

final converterProvider = NotifierProvider<ConverterController, ConverterState>(
  ConverterController.new,
);

/// Tokens reject callbacks from replaced selections and cancelled conversions.
class ConverterController extends Notifier<ConverterState> {
  int _conversionGeneration = 0;
  int _estimateGeneration = 0;
  int _videoGeneration = 0;
  WebpOperation? _operation;
  final Set<String> _ownedResults = {};
  final Set<String> _ownedEdits = {};

  @override
  ConverterState build() {
    ref.onDispose(() {
      unawaited(_operation?.cancel());
      for (final path in _ownedResults) {
        unawaited(_deleteFile(path));
      }
      for (final path in _ownedEdits) {
        unawaited(_deleteFile(path));
      }
    });
    return const ConverterState();
  }

  Future<void> convert(ConversionOptions options) async {
    if (state.video == null || state.isBusy) return;
    setOptions(options);
    final video = state.video!;
    final previous = state.result;
    if (previous != null) {
      _ownedResults.remove(previous.path);
      unawaited(_deleteFile(previous.path));
    }
    final token = beginConversion();
    final operation = WebpOperation();
    _operation = operation;
    final notifications = ref.read(notificationServiceProvider);
    try {
      await notifications.prepare();
      operation.check();
      await ref.read(optionsRepositoryProvider).save(options);
      operation.check();
      final result = await ref
          .read(webpServiceProvider)
          .convert(
            video,
            options,
            operation,
            onProgress: (value) => updateProgress(token, value),
          );
      _ownedResults.add(result.path);
      finishConversion(token, result);
      debugPrint('WebP conversion: ${result.sizeBytes} bytes');
      await notifications.showCompleted(result.sizeBytes);
    } on ConversionCancelled {
      markConversionCancelled(token);
    } catch (error) {
      debugPrint('Conversion failed: $error');
      failConversion(
        token,
        'Conversion failed. Check the video file and available storage, then try again.',
      );
    } finally {
      if (identical(_operation, operation)) _operation = null;
    }
  }

  Future<void> cancel() async {
    await _operation?.cancel();
  }

  Future<void> _deleteFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (error) {
      debugPrint('Temporary file cleanup failed: $error');
    }
  }

  void _clearResults() {
    for (final path in _ownedResults) {
      unawaited(_deleteFile(path));
    }
    _ownedResults.clear();
  }

  void selectVideo(SelectedVideo video) {
    if (state.isBusy) {
      throw StateError('Cannot replace the video during conversion.');
    }
    _videoGeneration++;
    _conversionGeneration++;
    _estimateGeneration++;
    _clearResults();
    state = ConverterState(video: video, options: state.options);
  }

  void clearVideo() {
    if (state.isBusy) {
      throw StateError('Cannot remove the video during conversion.');
    }
    _conversionGeneration++;
    _estimateGeneration++;
    _videoGeneration++;
    _clearResults();
    state = ConverterState(options: state.options);
  }

  /// Selection and editor exports share this path, including metadata refresh.
  Future<bool> loadVideo(String path, {String? name}) async {
    if (state.isConverting) return false;
    final token = ++_videoGeneration;
    _estimateGeneration++;
    state = state.copyWith(
      isLoadingVideo: true,
      error: null,
      estimate: const SizeEstimate(),
    );
    final service = ref.read(videoMetadataServiceProvider);
    try {
      final video = await service.load(path, name: name);
      final directory = await getTemporaryDirectory();
      if (!ref.mounted || token != _videoGeneration || state.isConverting) {
        return false;
      }
      _conversionGeneration++;
      _clearResults();
      for (final previous
          in _ownedEdits.where((value) => value != video.path).toList()) {
        _ownedEdits.remove(previous);
        unawaited(_deleteFile(previous));
      }
      final file = File(video.path);
      if (file.parent.absolute.path == directory.absolute.path &&
          RegExp(
            r'^webp_editor_\d+\.mp4$',
          ).hasMatch(file.uri.pathSegments.last)) {
        _ownedEdits.add(video.path);
      }
      state = ConverterState(video: video, options: state.options);
      return true;
    } catch (_) {
      if (!ref.mounted || token != _videoGeneration) return false;
      state = state.copyWith(
        isLoadingVideo: false,
        error: 'Unable to load the video. Select another file or try again.',
      );
      return false;
    }
  }

  void setOptions(ConversionOptions options) {
    if (state.isBusy) {
      throw StateError('Cannot change options during conversion.');
    }
    _estimateGeneration++;
    state = state.copyWith(options: options, estimate: const SizeEstimate());
  }

  int beginEstimate() {
    if (state.video == null || state.isBusy) {
      throw StateError('No video is available for size estimation.');
    }
    final token = ++_estimateGeneration;
    state = state.copyWith(
      estimate: SizeEstimate(
        status: EstimateStatus.calculating,
        bytes: state.estimate.bytes,
      ),
    );
    return token;
  }

  void finishEstimate(int token, int bytes) {
    if (!ref.mounted ||
        token != _estimateGeneration ||
        state.video == null ||
        state.isBusy) {
      return;
    }
    if (bytes < 0) throw ArgumentError.value(bytes, 'bytes');
    state = state.copyWith(
      estimate: SizeEstimate(status: EstimateStatus.ready, bytes: bytes),
    );
  }

  void failEstimate(int token, String error) {
    if (!ref.mounted || token != _estimateGeneration || state.isBusy) return;
    state = state.copyWith(
      estimate: SizeEstimate(status: EstimateStatus.failed, error: error),
    );
  }

  int beginConversion() {
    if (state.video == null || state.isBusy) {
      throw StateError('Unable to start conversion.');
    }
    _estimateGeneration++;
    final token = ++_conversionGeneration;
    state = state.copyWith(
      status: ConversionStatus.preparing,
      progress: 0,
      result: null,
      error: null,
      estimate: const SizeEstimate(),
    );
    return token;
  }

  void updateProgress(int token, double progress) {
    if (!_isCurrentConversion(token) || !progress.isFinite) return;
    state = state.copyWith(
      status: ConversionStatus.converting,
      progress: progress.clamp(state.progress, 1),
    );
  }

  void finishConversion(int token, ConversionResult result) {
    if (!_isCurrentConversion(token)) return;
    state = state.copyWith(
      status: ConversionStatus.completed,
      progress: 1,
      result: result,
    );
  }

  void failConversion(int token, String error) {
    if (!_isCurrentConversion(token)) return;
    state = state.copyWith(status: ConversionStatus.failed, error: error);
  }

  /// Called after native cancellation has settled, before another job starts.
  void markConversionCancelled(int token) {
    if (!_isCurrentConversion(token)) return;
    _conversionGeneration++;
    state = state.copyWith(status: ConversionStatus.cancelled, result: null);
  }

  bool _isCurrentConversion(int token) =>
      ref.mounted && token == _conversionGeneration && state.isBusy;
}
