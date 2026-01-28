import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../services/pocketbase_service.dart';

final authProvider = NotifierProvider<AuthNotifier, bool>(AuthNotifier.new);

class AuthNotifier extends Notifier<bool> {
  final _service = PocketBaseService();
  
  @override
  bool build() => _service.isAuthenticated;

  Future<void> login(String email, String password) async {
    await _service.login(email, password);
    state = true;
  }

  void logout() {
    _service.logout();
    state = false;
  }
}
