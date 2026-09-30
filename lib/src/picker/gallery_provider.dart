import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';

final gallerySourceProvider = Provider<GallerySource>((ref) => GallerySource());

/// Copied from the reference picker: permissions, sorted album and video loading.
class GallerySource {
  Future<bool> requestAccess() async =>
      (await PhotoManager.requestPermissionExtend(
        requestOption: const PermissionRequestOption(
          androidPermission: AndroidPermission(
            type: RequestType.video,
            mediaLocation: false,
          ),
        ),
      )).hasAccess;

  Future<List<AssetEntity>> loadVideos() async {
    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.video,
      onlyAll: true,
      filterOption: FilterOptionGroup(
        orders: [
          const OrderOption(type: OrderOptionType.createDate, asc: false),
        ],
      ),
    );
    if (albums.isEmpty) return [];
    // Page through the library instead of silently hiding videos after #500.
    final videos = <AssetEntity>[];
    var page = 0;
    while (true) {
      final batch = await albums.first.getAssetListPaged(
        page: page++,
        size: 200,
      );
      videos.addAll(batch);
      if (batch.length < 200) return videos;
    }
  }
}

class GalleryState {
  const GalleryState({
    this.assets = const [],
    this.selected,
    this.loading = true,
    this.permissionDenied = false,
    this.error,
  });
  final List<AssetEntity> assets;
  final AssetEntity? selected;
  final bool loading;
  final bool permissionDenied;
  final String? error;
}

final galleryProvider =
    NotifierProvider.autoDispose<GalleryController, GalleryState>(
      GalleryController.new,
    );

class GalleryController extends Notifier<GalleryState> {
  int _generation = 0;
  @override
  GalleryState build() => const GalleryState();

  Future<void> load() async {
    final token = ++_generation;
    state = const GalleryState();
    final source = ref.read(gallerySourceProvider);
    try {
      final permitted = await source.requestAccess();
      if (!ref.mounted || token != _generation) return;
      if (!permitted) {
        state = const GalleryState(loading: false, permissionDenied: true);
        return;
      }
      final videos = await source.loadVideos();
      if (!ref.mounted || token != _generation) return;
      state = GalleryState(assets: List.unmodifiable(videos), loading: false);
    } catch (_) {
      if (!ref.mounted || token != _generation) return;
      state = const GalleryState(
        loading: false,
        error: 'Unable to load videos. Please try again.',
      );
    }
  }

  void select(AssetEntity asset) {
    if (state.loading || !state.assets.any((item) => item.id == asset.id)) {
      return;
    }
    state = GalleryState(assets: state.assets, loading: false, selected: asset);
  }
}
