import 'package:pocketbase/pocketbase.dart';
import '../config/app_config.dart';
import '../services/pocketbase_service.dart';

class MediaHelper {
  static bool isVideo(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    return AppConfig.videoExtensions.map((e) => e.toLowerCase()).contains(ext);
  }

  // ORIGINALS: Used for Video Streaming or if Preview fails
  static String getOriginalUrl(RecordModel record) {
    final filename = record.getStringValue('file');
    final baseUrl = PocketBaseService().pb.baseUrl;
    return '$baseUrl/media/${record.collectionId}/${record.id}/$filename';
  }

  // Keep this for backward compatibility if code refers to 'getMediaUrl'
  static String getMediaUrl(RecordModel record) => getOriginalUrl(record);

  // PROXY VIDEO (720p): Used for fast Sharing
  static String getVideoProxyUrl(RecordModel record) {
    final filename = record.getStringValue('file');
    final baseUrl = PocketBaseService().pb.baseUrl;
    
    // Naming convention from main.go: "video.mp4" -> "video.mp4_proxy.mp4"
    final proxyFilename = '${filename}_proxy.mp4';
    
    // Maps to 'location /previews/' in nginx.conf (same folder as image previews)
    return '$baseUrl/previews/${record.collectionId}/${record.id}/$proxyFilename';
  }

  // THUMBNAILS (256px): Used for Grid
  static String getThumbUrl(RecordModel record) {
    final filename = record.getStringValue('file');
    final baseUrl = PocketBaseService().pb.baseUrl;
    final thumbFilename = '$filename.webp';
    // Removed token query parameter
    return '$baseUrl/thumbs/${record.collectionId}/${record.id}/$thumbFilename';
  }

  // PREVIEWS (1280px): Used for Full Screen Viewer
  static String getPreviewUrl(RecordModel record) {
    final filename = record.getStringValue('file');
    final baseUrl = PocketBaseService().pb.baseUrl;
    
    final thumbFilename = '$filename.webp';
    
    // Maps to 'location /previews/' in nginx.conf
    final url = '$baseUrl/previews/${record.collectionId}/${record.id}/$thumbFilename';
    return url;
  }
}

class DateHelper {
  static String monthName(int month) {
    const months = [
      "January", "February", "March", "April", "May", "June",
      "July", "August", "September", "October", "November", "December"
    ];
    return months[month - 1];
  }
  
  static String formatPhotoDate(RecordModel photo) {
    final dateStr = photo.getStringValue('taken_at');
    DateTime date;
    if (dateStr.isEmpty) {
      date = DateTime.parse(photo.created);
    } else {
      date = DateTime.parse(dateStr);
    }
    return "${monthName(date.month)} ${date.year}";
  }
}
