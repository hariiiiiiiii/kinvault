import 'dart:io';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';   
import 'package:http/http.dart' as http;
import '../services/pocketbase_service.dart';
import 'photos_provider.dart';

enum UploadSource { gallery, files }

class UploadState {
  final bool isUploading;
  final int total;
  final int current;
  final int success;
  final int fail;

  const UploadState({
    this.isUploading = false,
    this.total = 0,
    this.current = 0,
    this.success = 0,
    this.fail = 0,
  });
  
  double get progress => total == 0 ? 0.0 : current / total;
}

class UploadNotifier extends Notifier<UploadState> {
  
  @override
  UploadState build() {
    return const UploadState();
  }

  
  Future<Map<String, int>?> pickAndUpload(UploadSource source) async {
    List<File> filesToUpload = [];

    // Pick Files based on Source
    try {
      if (source == UploadSource.gallery) {
        print("Opening Visual Gallery (ImagePicker)...");
        final picker = ImagePicker();
        final pickedXFiles = await picker.pickMultipleMedia(
          limit: 100,
          requestFullMetadata: false, //Stability
        );
        filesToUpload = pickedXFiles.map((x) => File(x.path)).toList();
      } else {
        print("Opening File Browser (FilePicker)...");
        final result = await FilePicker.platform.pickFiles(
          allowMultiple: true,
          type: FileType.media,
          withData: false, 
        );
        if (result != null) {
          filesToUpload = result.files
              .where((f) => f.path != null)
              .map((f) => File(f.path!))
              .toList();
        }
      }
      
      print("Selection closed. Count: ${filesToUpload.length}");
    } catch (e) {
      print("CRITICAL: Error picking files: $e");
      return null;
    }
    
    if (filesToUpload.isEmpty) {
      print("No files selected.");
      return null;
    }

    // Init State
    state = UploadState(isUploading: true, total: filesToUpload.length);

    final service = PocketBaseService();
    final ownerId = service.pb.authStore.model?.id;
    
    if (ownerId == null) {
        state = const UploadState();
        return null;
    }

    int successCount = 0;
    int failCount = 0;

    // Process Queue
    print("Starting upload queue for ${filesToUpload.length} files.");

    for (var i = 0; i < filesToUpload.length; i++) {
      final file = filesToUpload[i];
      final filename = file.path.split('/').last;
      
      print("Processing [${i + 1}/${filesToUpload.length}]: $filename");
      
      try {

        String dateStr;
        try {
          final fileDate = await file.lastModified();
          dateStr = fileDate.toIso8601String();
        } catch (e) {
          dateStr = DateTime.now().toIso8601String();
        }

        // Stream Upload
        final multipartFile = await http.MultipartFile.fromPath(
          'file',
          file.path,
          filename: filename,
        );

        await service.pb.collection('photos').create(
          body: {
            'owner': ownerId,
            'taken_at': dateStr,
          },
          files: [multipartFile],
        );
        
        successCount++;
        print("SUCCESS: $filename");
        
      } catch (e) {
        print("FAIL: $filename - Error: $e");
        failCount++;
      }

      // Update State
      try {
        state = UploadState(
          isUploading: true,
          total: filesToUpload.length,
          current: i + 1,
          success: successCount,
          fail: failCount,
        );
      } catch (_) {}

      await Future.delayed(const Duration(milliseconds: 150));
    }

    // Refresh Gallery
    try {
      ref.read(photosProvider.notifier).refresh();
    } catch (_) {}
    
    // Reset UI
    await Future.delayed(const Duration(milliseconds: 1000));
    state = const UploadState();

    return {'success': successCount, 'fail': failCount};
  }
}

final uploadProvider = NotifierProvider<UploadNotifier, UploadState>(UploadNotifier.new);
