enum OutputResolution {
  original(0, 'Original'),
  p720(720, '720p'),
  p480(480, '480p'),
  p320(320, '320p');

  const OutputResolution(this.shortSide, this.label);
  final int shortSide;
  final String label;
}

class ConversionOptions {
  const ConversionOptions({
    this.resolution = OutputResolution.original,
    this.fps = 15,
    this.quality = 75,
    this.speed = 1,
  }) : assert(fps >= 10 && fps <= 60),
       assert(quality >= 50 && quality <= 100),
       assert(speed >= 1 && speed <= 3);

  final OutputResolution resolution;
  final double fps;
  final double quality;
  final double speed;

  ConversionOptions copyWith({
    OutputResolution? resolution,
    double? fps,
    double? quality,
    double? speed,
  }) => ConversionOptions(
    resolution: resolution ?? this.resolution,
    fps: fps ?? this.fps,
    quality: quality ?? this.quality,
    speed: speed ?? this.speed,
  );

  Map<String, Object> toMap() => {
    'selectedResolution': resolution.shortSide,
    'fps': fps,
    'quality': quality,
    'speed': speed,
  };

  factory ConversionOptions.fromMap(Map<String, dynamic> map) =>
      ConversionOptions(
        resolution: OutputResolution.values.firstWhere(
          (value) => value.shortSide == map['selectedResolution'],
          orElse: () => OutputResolution.original,
        ),
        fps: _readNumber(map['fps'], 15, 10, 60),
        quality: _readNumber(map['quality'], 75, 50, 100),
        speed: _readNumber(map['speed'], 1, 1, 3),
      );

  static double _readNumber(
    Object? value,
    double fallback,
    double min,
    double max,
  ) {
    if (value is! num || !value.isFinite) return fallback;
    return value.toDouble().clamp(min, max);
  }
}
