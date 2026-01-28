import 'dart:io';
import 'dart:async'; 
import 'dart:ui' as ui; 
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart'; 
import 'package:path_provider/path_provider.dart';

import '../providers/auth_provider.dart';
import '../providers/photos_provider.dart';
import '../services/pocketbase_service.dart';
import '../utils/helpers.dart';
import '../providers/upload_provider.dart';

class HomeScreen extends HookConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photosAsync = ref.watch(photosProvider);
    final uploadState = ref.watch(uploadProvider);
    final selectedIds = useState<Set<String>>({});
    final scrollController = useScrollController();

    final isSelectionMode = selectedIds.value.isNotEmpty;

   //Selection Actions 
    void toggleSelection(String id) {
      final newSet = Set<String>.from(selectedIds.value);
      if (newSet.contains(id)) {
        newSet.remove(id);
      } else {
        newSet.add(id);
      }
      selectedIds.value = newSet;
    }

    void clearSelection() {
      selectedIds.value = {};
    }

    Future<void> deleteSelected() async {
      final count = selectedIds.value.length;
      if (count == 0) return;

      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Text("Delete $count items?", style: const TextStyle(color: Colors.white)),
          content: const Text("This cannot be undone.", style: TextStyle(color: Colors.grey)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Delete", style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );

      if (confirm == true) {
        await ref.read(photosProvider.notifier).deletePhotos(selectedIds.value.toList());
        clearSelection();
      }
    }

    Future<void> shareSelected(List<RecordModel> allPhotos) async {
      if (selectedIds.value.isEmpty) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Preparing files for sharing..."),
          duration: Duration(seconds: 1),
          backgroundColor: Colors.black87,
        ),
      );

      try {
        final tempDir = await getTemporaryDirectory();
        final xFiles = <XFile>[];
        final selectedRecords = allPhotos.where((p) => selectedIds.value.contains(p.id)).toList();

        for (final photo in selectedRecords) {
          final isVideo = MediaHelper.isVideo(photo.getStringValue('file'));
          String url = MediaHelper.getMediaUrl(photo);
          String filename = photo.getStringValue('file');

          if (isVideo) {
             final proxyUrl = MediaHelper.getVideoProxyUrl(photo);
             try {
               final head = await http.head(Uri.parse(proxyUrl));
               if (head.statusCode == 200) {
                 url = proxyUrl;
                 filename = '${filename}_proxy.mp4';
               }
             } catch (_) {}
          }

          final savePath = '${tempDir.path}/$filename';
          final file = File(savePath);

          if (!await file.exists()) {
             final response = await http.get(Uri.parse(url));
             if (response.statusCode == 200) {
               await file.writeAsBytes(response.bodyBytes);
             }
          }
          xFiles.add(XFile(savePath));
        }

        if (xFiles.isNotEmpty) {
          await Share.shareXFiles(xFiles);//, text: "Shared from Family Vault");
          clearSelection();
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Share failed: $e"), backgroundColor: Colors.red),
          );
        }
      }
    }

    // --- UPLOAD HELPER ---
    Future<void> triggerUpload(UploadSource source) async {
      final result = await ref.read(uploadProvider.notifier).pickAndUpload(source);
      
      if (result != null && context.mounted) {
         final success = result['success'];
         final fail = result['fail'];
         ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("✓ $success uploaded${fail! > 0 ? ' · ✗ $fail failed' : ''}"),
              backgroundColor: fail > 0 ? Colors.orange : const Color(0xFFD4A574),
            ),
         );
      }
    }

    // Upload Options
    void showUploadOptions() {
      showModalBottomSheet(
        context: context,
        backgroundColor: const Color(0xFF1A1A1A),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.photo_library, color: Color(0xFFD4A574), size: 30),
                    title: const Text("Visual Gallery", style: TextStyle(color: Colors.white, fontSize: 16)),
                    subtitle: const Text("Select photos/videos visually", style: TextStyle(color: Colors.grey)),
                    onTap: () {
                      Navigator.pop(ctx);
                      triggerUpload(UploadSource.gallery);
                    },
                  ),
                  const Divider(color: Colors.white24),
                  ListTile(
                    leading: const Icon(Icons.folder_open, color: Color(0xFFD4A574), size: 30),
                    title: const Text("File Browser", style: TextStyle(color: Colors.white, fontSize: 16)),
                    subtitle: const Text("Select from files/folders (Reliable)", style: TextStyle(color: Colors.grey)),
                    onTap: () {
                      Navigator.pop(ctx);
                      triggerUpload(UploadSource.files);
                    },
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: (scrollInfo) {
              if (scrollInfo.metrics.pixels >=
                  scrollInfo.metrics.maxScrollExtent - 200) {
                ref.read(photosProvider.notifier).loadNextPage();
              }
              return false;
            },
            child: RefreshIndicator(
              onRefresh: () async =>
                  ref.read(photosProvider.notifier).refresh(),
              color: const Color(0xFFD4A574),
              child: photosAsync.when(
                data: (photos) => _buildPhotoGrid(
                  context, 
                  ref, 
                  photos, 
                  scrollController,
                  selectedIds.value,
                  toggleSelection,
                  isSelectionMode,
                  clearSelection,
                  deleteSelected,
                  () => shareSelected(photos),
                ),
                loading: () => const Center(
                  child: CircularProgressIndicator(color: Color(0xFFD4A574)),
                ),
                error: (err, stack) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        "Error loading photos",
                        style: TextStyle(color: Colors.grey[400], fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          if (uploadState.isUploading)
            Container(
              color: Colors.black87,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: CircularProgressIndicator(
                        value: uploadState.progress > 0 ? uploadState.progress : null,
                        strokeWidth: 6,
                        color: const Color(0xFFD4A574),
                        backgroundColor: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      uploadState.progress > 0
                          ? '${(uploadState.progress * 100).toInt()}%'
                          : 'Starting...',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${uploadState.current} / ${uploadState.total} Processed',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: isSelectionMode 
        ? null 
        : Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE5B97F), Color(0xFFD4A574), Color(0xFFC39461)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD4A574).withOpacity(0.4),
                  blurRadius: 20,
                  spreadRadius: 2,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: uploadState.isUploading ? null : showUploadOptions,
                customBorder: const CircleBorder(),
                child: const Center(child: Icon(Icons.add, color: Colors.black, size: 32)),
              ),
            ),
          ),
    );
  }

  Widget _buildPhotoGrid(
    BuildContext context,
    WidgetRef ref,
    List<RecordModel> photos,
    ScrollController scrollController,
    Set<String> selectedIds,
    Function(String) onToggle,
    bool isSelectionMode,
    VoidCallback onClear,
    VoidCallback onDelete,
    VoidCallback onShare,
  ) {
    if (photos.isEmpty) return _buildEmptyState(ref);

    final groupedPhotos = _groupPhotosByDate(photos);

    return TimelineScrollbar(
      controller: scrollController,
      photos: photos,
      child: CustomScrollView(
        controller: scrollController,
        slivers: [
          isSelectionMode 
            ? _buildSelectionAppBar(selectedIds.length, onClear, onDelete, onShare)
            : _buildAppBar(ref),
          ..._buildPhotoSections(context, groupedPhotos, photos, selectedIds, onToggle, isSelectionMode),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  SliverAppBar _buildSelectionAppBar(int count, VoidCallback onClear, VoidCallback onDelete, VoidCallback onShare) {
    return SliverAppBar(
      expandedHeight: 80,
      floating: false,
      pinned: true,
      backgroundColor: Colors.grey[900],
      leading: IconButton(icon: const Icon(Icons.close), onPressed: onClear),
      flexibleSpace: FlexibleSpaceBar(
        title: Text("$count selected", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: false,
        titlePadding: const EdgeInsets.only(left: 72, bottom: 16),
      ),
      actions: [
        IconButton(icon: const Icon(Icons.share_outlined), onPressed: onShare),
        IconButton(icon: const Icon(Icons.delete_outline), onPressed: onDelete),
        const SizedBox(width: 8),
      ],
    );
  }

  SliverAppBar _buildAppBar(WidgetRef ref) {
    final user = PocketBaseService().pb.authStore.model;
    final email = user is RecordModel ? user.getStringValue('email') : '';
    final name = email.split('@').first;

    return SliverAppBar(
      expandedHeight: 80,
      floating: false,
      pinned: true,
      backgroundColor: Colors.black,
      flexibleSpace: FlexibleSpaceBar(
        title: const Text(
          "KIN VAULT",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            letterSpacing: 3.0,
          ),
        ),
        centerTitle: true,
        titlePadding: const EdgeInsets.only(bottom: 16),
      ),
      actions: [
        
        if (name.isNotEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                name.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white38, 
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ),
        IconButton(
          icon: const Icon(Icons.logout_rounded, size: 22),
          tooltip: 'Sign Out',
          onPressed: () => ref.read(authProvider.notifier).logout(),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildEmptyState(WidgetRef ref) {
     return CustomScrollView(
      slivers: [
        _buildAppBar(ref),
        SliverFillRemaining(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.photo_library_outlined, size: 64, color: Colors.grey[700]),
                const SizedBox(height: 24),
                Text("No photos yet", style: TextStyle(color: Colors.grey[400], fontSize: 20)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Map<String, List<RecordModel>> _groupPhotosByDate(List<RecordModel> photos) {
    final grouped = <String, List<RecordModel>>{};
    for (var photo in photos) {
      final key = DateHelper.formatPhotoDate(photo);
      if (!grouped.containsKey(key)) {
        grouped[key] = [];
      }
      grouped[key]!.add(photo);
    }
    return grouped;
  }

  List<Widget> _buildPhotoSections(
    BuildContext context,
    Map<String, List<RecordModel>> groupedPhotos,
    List<RecordModel> allPhotos,
    Set<String> selectedIds,
    Function(String) onToggle,
    bool isSelectionMode,
  ) {
    final sections = <Widget>[];
    for (var entry in groupedPhotos.entries) {
      sections.add(_buildSectionHeader(entry.key));
      sections.add(_buildPhotoGridSliver(context, entry.value, allPhotos, selectedIds, onToggle, isSelectionMode));
    }
    return sections;
  }

  Widget _buildSectionHeader(String title) {
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
        child: Text(
          title,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildPhotoGridSliver(
    BuildContext context,
    List<RecordModel> photos,
    List<RecordModel> allPhotos,
    Set<String> selectedIds,
    Function(String) onToggle,
    bool isSelectionMode,
  ) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 2,
          mainAxisSpacing: 2,
          childAspectRatio: 1.0,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final photo = photos[index];
            final isSelected = selectedIds.contains(photo.id);
            return _buildPhotoTile(context, photo, allPhotos, isSelected, isSelectionMode, onToggle);
          },
          childCount: photos.length,
        ),
      ),
    );
  }

  Widget _buildPhotoTile(
    BuildContext context,
    RecordModel photo,
    List<RecordModel> allPhotos,
    bool isSelected,
    bool isSelectionMode,
    Function(String) onToggle,
  ) {
    final filename = photo.getStringValue('file');
    final isVideo = MediaHelper.isVideo(filename);
    final thumbUrl = MediaHelper.getThumbUrl(photo);

    return GestureDetector(
      onLongPress: () => onToggle(photo.id),
      onTap: () {
        if (isSelectionMode) {
          onToggle(photo.id);
        } else {
          final globalIndex = allPhotos.indexOf(photo);
          context.push('/view', extra: {
            'photos': allPhotos,
            'index': globalIndex,
          });
        }
      },
      child: Hero(
        tag: photo.id,
        child: Container(
          decoration: const BoxDecoration(color: Color(0xFF1A1A1A)),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: thumbUrl,
                fit: BoxFit.cover,
                memCacheHeight: 256,
                memCacheWidth: 256,
                fadeInDuration: const Duration(milliseconds: 150),
                placeholder: (context, url) => Container(color: const Color(0xFF1A1A1A)),
                errorWidget: (context, url, error) {
                  CachedNetworkImage.evictFromCache(url);
                  return const Center(child: Icon(Icons.hourglass_empty_rounded, color: Colors.white24, size: 24));
                },
              ),
              if (isVideo)
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withOpacity(0.3)],
                    ),
                  ),
                  child: const Align(
                    alignment: Alignment.center,
                    child: Icon(Icons.play_circle_filled, color: Colors.white, size: 40),
                  ),
                ),
              if (isSelected)
                Container(color: Colors.black.withOpacity(0.4)),
              if (isSelectionMode)
                Positioned(
                  top: 8, left: 8,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 24, height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? Colors.blue : Colors.white24,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: isSelected ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// Scrollbar
class TimelineScrollbar extends StatefulWidget {
  final ScrollController controller;
  final List<RecordModel> photos;
  final Widget child;

  const TimelineScrollbar({
    super.key,
    required this.controller,
    required this.photos,
    required this.child,
  });

  @override
  State<TimelineScrollbar> createState() => _TimelineScrollbarState();
}

class _TimelineScrollbarState extends State<TimelineScrollbar> {
  final GlobalKey _trackKey = GlobalKey();
  bool _isDragging = false;
  double _scrollProgress = 0.0;
  Timer? _hideTimer;

  void _onScroll() {
    if (!widget.controller.hasClients) return;
    
    final maxScroll = widget.controller.position.maxScrollExtent;
    final currentScroll = widget.controller.position.pixels;
    
    if (maxScroll > 0) {
      setState(() {
        _scrollProgress = (currentScroll / maxScroll).clamp(0.0, 1.0);
      });
    }
  }

  void _onDragStart(DragStartDetails details) {
    setState(() => _isDragging = true);
    _updateScrollFromDrag(details.localPosition.dy);
  }

  void _onDragUpdate(DragUpdateDetails details) {
    _updateScrollFromDrag(details.localPosition.dy);
  }

  void _updateScrollFromDrag(double localY) {
    if (_trackKey.currentContext == null) return;
    
    final RenderBox renderBox = _trackKey.currentContext!.findRenderObject() as RenderBox;
    final trackHeight = renderBox.size.height;
    final progress = (localY / trackHeight).clamp(0.0, 1.0);
    final maxScroll = widget.controller.position.maxScrollExtent;
    widget.controller.jumpTo(progress * maxScroll);
  }

  void _onDragEnd(DragEndDetails details) {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _isDragging = false);
    });
  }

  String _getDateLabel() {
    if (widget.photos.isEmpty) return "";
    final index = (_scrollProgress * (widget.photos.length - 1)).floor();
    final photo = widget.photos[index];
    final dateStr = photo.getStringValue('taken_at');
    final date = dateStr.isEmpty ? DateTime.parse(photo.created) : DateTime.parse(dateStr);
    return DateFormat('MMM yyyy').format(date);
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onScroll);
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top + kToolbarHeight + 16.0;
    final bottomPadding = MediaQuery.of(context).padding.bottom + 80.0;

    return Stack(
      alignment: Alignment.centerRight,
      children: [
        widget.child,
        if (widget.photos.isNotEmpty)
          Positioned(
            right: 0,
            top: topPadding,
            bottom: bottomPadding,
            child: GestureDetector(
              onVerticalDragStart: _onDragStart,
              onVerticalDragUpdate: _onDragUpdate,
              onVerticalDragEnd: _onDragEnd,
              child: Container(
                key: _trackKey,
                width: 60,
                color: Colors.transparent, 
                child: CustomPaint(
                  painter: _ScrollbarPainter(
                    progress: _scrollProgress,
                    isDragging: _isDragging,
                    dateLabel: _getDateLabel(),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ScrollbarPainter extends CustomPainter {
  final double progress;
  final bool isDragging;
  final String dateLabel;

  _ScrollbarPainter({
    required this.progress,
    required this.isDragging,
    required this.dateLabel,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final thumbHeight = 40.0;
    final scrollableHeight = size.height - thumbHeight;
    final thumbY = (progress * scrollableHeight).clamp(0.0, scrollableHeight);
    
    final paint = Paint()
      ..color = isDragging ? const Color(0xFFD4A574) : Colors.grey.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    final visualThumbWidth = isDragging ? 24.0 : 6.0;
    final rightPadding = 4.0;
    
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width - visualThumbWidth - rightPadding, thumbY, visualThumbWidth, thumbHeight),
      const Radius.circular(12),
    );
    
    canvas.drawRRect(rrect, paint);

    if (isDragging) {
      final textSpan = TextSpan(
        text: dateLabel,
        style: const TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.bold),
      );
      final textPainter = TextPainter(text: textSpan, textDirection: ui.TextDirection.ltr);
      textPainter.layout();
      
      final bubblePaddingH = 12.0;
      final bubblePaddingV = 8.0;
      final bubbleWidth = textPainter.width + (bubblePaddingH * 2);
      final bubbleHeight = textPainter.height + (bubblePaddingV * 2);
      
      final bubbleX = size.width - visualThumbWidth - rightPadding - bubbleWidth - 12;
      final bubbleY = thumbY + (thumbHeight / 2) - (bubbleHeight / 2);

      final bubblePaint = Paint()..color = Colors.white..style = PaintingStyle.fill;
      final shadowPath = Path()..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(bubbleX + 2, bubbleY + 2, bubbleWidth, bubbleHeight),
          const Radius.circular(8)));
      canvas.drawShadow(shadowPath, Colors.black.withOpacity(0.5), 4.0, true);
        
      final bubbleRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(bubbleX, bubbleY, bubbleWidth, bubbleHeight),
        const Radius.circular(8),
      );
      canvas.drawRRect(bubbleRect, bubblePaint);
      textPainter.paint(canvas, Offset(bubbleX + bubblePaddingH, bubbleY + bubblePaddingV));
    }
  }

  @override
  bool shouldRepaint(covariant _ScrollbarPainter oldDelegate) {
    return oldDelegate.progress != progress || 
           oldDelegate.isDragging != isDragging ||
           oldDelegate.dateLabel != dateLabel;
  }
}
