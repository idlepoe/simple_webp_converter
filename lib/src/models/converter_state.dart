import 'conversion_options.dart';
import 'selected_video.dart';

enum ConversionStatus {
  idle,
  preparing,
  converting,
  saving,
  completed,
  cancelled,
  failed,
}

enum EstimateStatus { idle, calculating, ready, failed }

class SizeEstimate {
  const SizeEstimate({
    this.status = EstimateStatus.idle,
    this.bytes,
    this.isApproximate = true,
    this.error,
  });
  final EstimateStatus status;
  final int? bytes;
  final bool isApproximate;
  final String? error;
}

const _unchanged = Object();

class ConverterState {
  const ConverterState({
    this.video,
    this.options = const ConversionOptions(),
    this.status = ConversionStatus.idle,
    this.progress = 0,
    this.result,
    this.estimate = const SizeEstimate(),
    this.error,
    this.isLoadingVideo = false,
    this.isResultSaved = false,
  });

  final SelectedVideo? video;
  final ConversionOptions options;
  final ConversionStatus status;
  final double progress;
  final ConversionResult? result;
  final SizeEstimate estimate;
  final String? error;
  final bool isLoadingVideo;
  final bool isResultSaved;

  bool get isConverting =>
      status == ConversionStatus.preparing ||
      status == ConversionStatus.converting ||
      status == ConversionStatus.saving;

  bool get isBusy => isConverting || isLoadingVideo;

  ConverterState copyWith({
    Object? video = _unchanged,
    ConversionOptions? options,
    ConversionStatus? status,
    double? progress,
    Object? result = _unchanged,
    SizeEstimate? estimate,
    Object? error = _unchanged,
    bool? isLoadingVideo,
    bool? isResultSaved,
  }) => ConverterState(
    video: identical(video, _unchanged) ? this.video : video as SelectedVideo?,
    options: options ?? this.options,
    status: status ?? this.status,
    progress: progress ?? this.progress,
    result: identical(result, _unchanged)
        ? this.result
        : result as ConversionResult?,
    estimate: estimate ?? this.estimate,
    error: identical(error, _unchanged) ? this.error : error as String?,
    isLoadingVideo: isLoadingVideo ?? this.isLoadingVideo,
    isResultSaved: isResultSaved ?? this.isResultSaved,
  );
}
