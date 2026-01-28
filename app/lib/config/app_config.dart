import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static String get serverUrl {
    final ip = dotenv.env['SERVER_IP'];
    if (ip == null || ip.isEmpty) {
      throw Exception('SERVER_IP not found in .env file');
    }
    return 'http://$ip';
  }
  
  static const int photosPerPage = 40;
  static const int maxConcurrentUploads = 2;
  
  static const List<String> videoExtensions = [
    'mp4', 'mov', 'avi', '3gp', 'webm', 'mkv', 'mpeg', 'mpg'
  ];
}
