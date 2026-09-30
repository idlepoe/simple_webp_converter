class PickedVideo {
  const PickedVideo({required this.path, required this.name});
  final String path;
  final String name;
}

class SelectedVideo {
  const SelectedVideo({
    required this.path,
    required this.name,
    required this.width,
    required this.height,
    required this.duration,
    required this.sizeBytes,
    this.sourceFps,
  }) : assert(width > 0),
       assert(height > 0),
       assert(sizeBytes >= 0),
       assert(
         sourceFps == null || (sourceFps > 0 && sourceFps < double.infinity),
       );

  final String path;
  final String name;
  final int width;
  final int height;
  final Duration duration;
  final int sizeBytes;
  final double? sourceFps;
}

class ConversionResult {
  const ConversionResult({
    required this.path,
    required this.sizeBytes,
    required this.width,
    required this.height,
    required this.duration,
  }) : assert(sizeBytes >= 0),
       assert(width > 0),
       assert(height > 0);

  final String path;
  final int sizeBytes;
  final int width;
  final int height;
  final Duration duration;
}
