import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';
import '../config/app_config.dart';
import '../services/pocketbase_service.dart';
import 'auth_provider.dart';

final photosProvider = AsyncNotifierProvider<PhotosNotifier, List<RecordModel>>(
  PhotosNotifier.new,
);

class PhotosNotifier extends AsyncNotifier<List<RecordModel>> {
  final _service = PocketBaseService();
  int _page = 1;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  @override
  Future<List<RecordModel>> build() async {
    _page = 1;
    _hasMore = true;
    _isLoadingMore = false;
    
    final isLoggedIn = ref.watch(authProvider);
    if (!isLoggedIn) return [];

    return _fetchPage(1);
  }

  Future<List<RecordModel>> _fetchPage(int page) async {
    final result = await _service.getPhotos(
      page: page,
      perPage: AppConfig.photosPerPage,
    );

    if (result.items.length < AppConfig.photosPerPage) {
      _hasMore = false;
    }
    return result.items;
  }

  Future<void> loadNextPage() async {
    if (!_hasMore || _isLoadingMore || state.isLoading) return;

    _isLoadingMore = true;
    
    try {
      final newItems = await _fetchPage(_page + 1);
      _page++;
      
      final currentList = state.value ?? [];
      state = AsyncData([...currentList, ...newItems]);
    } catch (e) {
      print("Pagination error: $e");
    } finally {
      _isLoadingMore = false;
    }
  }

  Future<void> refresh() async {
    _page = 1;
    _hasMore = true;
    ref.invalidateSelf();
  }

  // Single Delete
  Future<void> delete(String id) async {
    final currentList = state.value ?? [];
    state = AsyncData(currentList.where((p) => p.id != id).toList());

    _service.deletePhoto(id).catchError((e) {
      print("Background delete failed: $e");
      refresh();
    });
  }

  // Batch Delete
  Future<void> deletePhotos(List<String> ids) async {
    final currentList = state.value ?? [];
    
    //Remove all selected IDs from UI
    state = AsyncData(currentList.where((p) => !ids.contains(p.id)).toList());

    //Delete from Server in parallel
    for (final id in ids) {
      _service.deletePhoto(id).catchError((e) {
        print("Failed to delete $id: $e");
      });
    }
  }
}
