import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:chewie/chewie.dart';
import 'package:intl/intl.dart';
import '../utils/helpers.dart';
import '../providers/photos_provider.dart';

class PhotoViewerScreen extends ConsumerStatefulWidget {
  final List<RecordModel> photos;
  final int initialIndex;

  const PhotoViewerScreen({
    super.key,
    required this.photos,
    required this.initialIndex,
  });

  @override
  ConsumerState<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends ConsumerState<PhotoViewerScreen> {
  late PageController _pageController;
  late int _currentIndex;
  late List<RecordModel> _localPhotos;

  final Map<String, VideoPlayerController> _videoControllers = {};
  final Map<String, ChewieController> _chewieControllers = {};
  
  bool _isZoomed = false;
  bool _showUI = true;
  double _dragDistance = 0;
  
  int _pointerCount = 0;
  Offset? _dragStartPoint;
  bool _isDragging = false; 

  @override
  void initState() {
    super.initState();
    _localPhotos = List.from(widget.photos);
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _initializeVideoIfNeeded(_currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (var c in _chewieControllers.values) c.dispose();
    for (var c in _videoControllers.values) c.dispose();
    super.dispose();
  }

  void _initializeVideoIfNeeded(int index) {
    if (index >= _localPhotos.length) return;

    final photo = _localPhotos[index];
    final filename = photo.getStringValue('file');
    final photoId = photo.id;

    if (MediaHelper.isVideo(filename) && !_videoControllers.containsKey(photoId)) {
      final videoUrl = MediaHelper.getMediaUrl(photo);
      final videoController = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      _videoControllers[photoId] = videoController;

      videoController.initialize().then((_) {
        if (mounted) {
          final chewieController = ChewieController(
            videoPlayerController: videoController,
            autoPlay: true,
            looping: true,
            aspectRatio: videoController.value.aspectRatio,
            materialProgressColors: ChewieProgressColors(
              playedColor: Colors.blue,
              handleColor: Colors.blue,
              backgroundColor: Colors.grey,
              bufferedColor: Colors.white30,
            ),
            placeholder: const Center(child: CircularProgressIndicator()),
            errorBuilder: (context, errorMessage) => Center(
                child: Text(errorMessage, style: const TextStyle(color: Colors.white))),
          );

          setState(() {
            _chewieControllers[photoId] = chewieController;
          });
        }
      });
    }
  }

  void _onPageChanged(int index) {
    if (_currentIndex < _localPhotos.length) {
      final prevId = _localPhotos[_currentIndex].id;
      _chewieControllers[prevId]?.pause();
    }

    setState(() {
      _currentIndex = index;
      _isZoomed = false; 
      _initializeVideoIfNeeded(index);
      
      if (index < _localPhotos.length) {
        final newId = _localPhotos[index].id;
        _chewieControllers[newId]?.play();
      }
    });
  }

  void _toggleUI() {
    setState(() => _showUI = !_showUI);
  }

  Future<void> _deleteCurrentPhoto() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text("Delete?", style: TextStyle(color: Colors.white)),
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

    if (confirm != true) return;

    final photoToDelete = _localPhotos[_currentIndex];
    final deleteId = photoToDelete.id;

    ref.read(photosProvider.notifier).delete(deleteId);

    setState(() {
      _localPhotos.removeAt(_currentIndex);
      _isZoomed = false;
      
      _chewieControllers[deleteId]?.dispose();
      _chewieControllers.remove(deleteId);
      _videoControllers[deleteId]?.dispose();
      _videoControllers.remove(deleteId);

      if (_localPhotos.isEmpty) {
        Navigator.pop(context);
      } else {
        if (_currentIndex >= _localPhotos.length) {
          _currentIndex = _localPhotos.length - 1;
        }
        _initializeVideoIfNeeded(_currentIndex);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_localPhotos.isEmpty) return const SizedBox.shrink();
    
    final currentPhoto = _localPhotos[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      body: GestureDetector(
        onTap: _toggleUI,
        child: Stack(
          children: [
            Listener(
              onPointerDown: (event) {
                _pointerCount++;
                if (_pointerCount == 1) {
                  _dragStartPoint = event.position;
                  _isDragging = false;
                } else {
                  _dragStartPoint = null;
                  _isDragging = false;
                  if (_dragDistance != 0) setState(() => _dragDistance = 0);
                }
              },
              onPointerUp: (event) {
                _pointerCount--;
                if (_pointerCount == 0) {
                  if (_isDragging && _dragDistance.abs() > 100) {
                    Navigator.pop(context);
                  } else {
                    if (_dragDistance != 0) setState(() => _dragDistance = 0);
                  }
                  _dragStartPoint = null;
                  _isDragging = false;
                }
              },
              onPointerCancel: (event) {
                _pointerCount = 0;
                _dragStartPoint = null;
                _isDragging = false;
                if (_dragDistance != 0) setState(() => _dragDistance = 0);
              },
              onPointerMove: (event) {
                if (_pointerCount == 1 && !_isZoomed && _dragStartPoint != null) {
                  final delta = event.position.dy - _dragStartPoint!.dy;
                  if (!_isDragging && delta.abs() > 20) {
                    _isDragging = true;
                  }
                  if (_isDragging) {
                    setState(() {
                      _dragDistance = delta;
                    });
                  }
                }
              },
              child: Transform.scale(
                scale: 1 - (_dragDistance.abs() / 1000).clamp(0.0, 0.3),
                child: Transform.translate(
                  offset: Offset(0, _dragDistance),
                  child: PageView.builder(
                    controller: _pageController,
                    physics: _isZoomed 
                        ? const NeverScrollableScrollPhysics() 
                        : const BouncingScrollPhysics(),
                    onPageChanged: _onPageChanged,
                    itemCount: _localPhotos.length,
                    itemBuilder: (context, index) {
                      final photo = _localPhotos[index];
                      final filename = photo.getStringValue('file');
                      final isVideo = MediaHelper.isVideo(filename);

                      if (isVideo) {
                        return Container(
                          key: ValueKey(photo.id),
                          child: _buildVideoPlayer(photo),
                        );
                      } else {
                        return PhotoItem(
                          key: ValueKey(photo.id),
                          photo: photo,
                          onZoomChanged: (isZoomed) {
                            if (_isZoomed != isZoomed) {
                              setState(() => _isZoomed = isZoomed);
                            }
                          },
                        );
                      }
                    },
                  ),
                ),
              ),
            ),

            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              top: _showUI ? 0 : -100,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 4,
                  bottom: 24, 
                  left: 8, 
                  right: 8,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.8),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white, size: 26),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
            ),

            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              bottom: _showUI ? 0 : -100,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).padding.bottom + 16,
                  top: 24,
                  left: 20,
                  right: 20,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.8),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
                      onPressed: _deleteCurrentPhoto,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPlayer(RecordModel photo) {
    final photoId = photo.id;
    if (_chewieControllers.containsKey(photoId)) {
      return Center(child: Chewie(controller: _chewieControllers[photoId]!));
    }
    return const Center(child: CircularProgressIndicator(color: Colors.white));
  }
}

class PhotoItem extends StatefulWidget {
  final RecordModel photo;
  final ValueChanged<bool> onZoomChanged;

  const PhotoItem({
    super.key, 
    required this.photo, 
    required this.onZoomChanged
  });

  @override
  State<PhotoItem> createState() => _PhotoItemState();
}

class _PhotoItemState extends State<PhotoItem> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final TransformationController _controller = TransformationController();
  bool _enablePan = false;
  bool _loadHighRes = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onZoomChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onZoomChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onZoomChanged() {
    final scale = _controller.value.getMaxScaleOnAxis();
    final isZoomed = scale > 1.01;
    widget.onZoomChanged(isZoomed);
    
    if (isZoomed && !_loadHighRes) {
      setState(() {
        _loadHighRes = true;
      });
    }
    
    if (isZoomed != _enablePan) {
      setState(() {
        _enablePan = isZoomed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final previewUrl = MediaHelper.getPreviewUrl(widget.photo);
    final originalUrl = MediaHelper.getMediaUrl(widget.photo);

    return InteractiveViewer(
      transformationController: _controller,
      minScale: 1.0,
      maxScale: 4.0,
      panEnabled: _enablePan, 
      scaleEnabled: true,
      child: Center(
        child: Hero(
          tag: widget.photo.id,
          child: CachedNetworkImage(
            imageUrl: _loadHighRes ? originalUrl : previewUrl,
            fit: BoxFit.contain,
            placeholder: (context, url) {
              if (url == originalUrl) {
                return CachedNetworkImage(
                  imageUrl: previewUrl,
                  fit: BoxFit.contain,
                );
              }
              return const Center(
                child: CircularProgressIndicator(color: Colors.white),
              );
            },
            errorWidget: (context, url, error) => const Center(
              child: Icon(Icons.broken_image, color: Colors.grey, size: 64),
            ),
          ),
        ),
      ),
    );
  }
}
