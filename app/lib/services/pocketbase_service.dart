import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

class PocketBaseService {
  static final PocketBaseService _instance = PocketBaseService._internal();
  factory PocketBaseService() => _instance;
  PocketBaseService._internal();

  late final PocketBase pb;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final store = AsyncAuthStore(
      save: (String data) async => prefs.setString('pb_auth', data),
      initial: prefs.getString('pb_auth'),
    );
    pb = PocketBase(AppConfig.serverUrl, authStore: store);
  }
  
  bool get isAuthenticated {
    try {
      return pb.authStore.isValid;
    } catch (_) {
      return false;
    }
  }
  
  Future<void> login(String email, String password) async {
    await pb.collection('users').authWithPassword(email, password);
  }
  
  void logout() {
    pb.authStore.clear();
  }
  
  Future<ResultList<RecordModel>> getPhotos({
    required int page,
    required int perPage,
  }) async {
    return await pb.collection('photos').getList(
      page: page,
      perPage: perPage,
      sort: '-taken_at',
    );
  }

  // NEW: Delete method
  Future<void> deletePhoto(String id) async {
    await pb.collection('photos').delete(id);
  }
}
