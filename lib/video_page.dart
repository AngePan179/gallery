import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gallery/design_colors.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

class VideoPage extends StatefulWidget {
  final AssetEntity asset;
  final VoidCallback onToggleUi;

  const VideoPage({super.key, required this.asset, required this.onToggleUi});

  @override
  State<VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<VideoPage> {
  VideoPlayerController? _controller;
  bool _isLoading = true;
  String? _error;
  Duration? _savedPosition;
  bool _showResumeButton = false;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMs = prefs.getInt('video_pos_${widget.asset.id}');
    if (savedMs != null && savedMs > 0) {
      _savedPosition = Duration(milliseconds: savedMs);
    }

    final File? file = await widget.asset.file;

    if (file == null) {
      setState(() {
        _isLoading = false;
        _error = 'Файл недоступен';
      });
      return;
    }

    final controller = VideoPlayerController.file(file);
    try {
      await controller.initialize();
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _isLoading = false;
      });
    } catch (e) {
      controller.dispose();
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Ошибка воспроизведения';
        });
      }
    }
  }

  void _seekRelative(int seconds) {
    if (_controller == null || !_controller!.value.isInitialized) return;

    final position = _controller!.value.position;
    final duration = _controller!.value.duration;
    Duration target = position + Duration(seconds: seconds);

    if (target < Duration.zero) target = Duration.zero;
    if (target > duration) target = duration;

    _controller!.seekTo(target);
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  void _resumeFromSaved() {
    if (_controller == null || _savedPosition == null) return;
    _controller!.seekTo(_savedPosition!);
    _controller!.play();
    setState(() {
      _showResumeButton = false;
      _savedPosition = null;
    });
  }

  @override
  void dispose() {
    _saveCurrentPosition();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _saveCurrentPosition() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    final pos = _controller!.value.position;
    if (pos > const Duration(seconds: 3) &&
        pos < _controller!.value.duration - const Duration(seconds: 3)) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('video_pos_${widget.asset.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Text(_error!, style: const TextStyle(color: Colors.white)),
      );
    }
    final controller = _controller!;
    final isPlaying = controller.value.isPlaying;

    return GestureDetector(
      onTap: () {
        if (!_showControls) {
          setState(() {
            _showControls = true;
          });
        } else {
          setState(() {
            controller.value.isPlaying ? controller.pause() : controller.play();
          });
        }
      },
      onLongPress: () {
        setState(() {
          _showControls = !_showControls;
        });
        widget.onToggleUi();
      },
      child: Center(
        child: AspectRatio(
          aspectRatio: controller.value.aspectRatio,
          child: Stack(
            alignment: Alignment.center,
            children: [
              VideoPlayer(controller),
              if (_showControls) ...[
                Positioned(
                  left: 16,
                  child: _buildSeekButton(
                    Icons.replay_10,
                    () => _seekRelative(-10),
                  ),
                ),
                Positioned(
                  right: 16,
                  child: _buildSeekButton(
                    Icons.forward_10,
                    () => _seekRelative(10),
                  ),
                ),
                if (!isPlaying)
                  const Icon(Icons.play_arrow, size: 80, color: Colors.white70),
                if (_showResumeButton && _savedPosition != null && !isPlaying)
                  Positioned(
                    bottom: 80,
                    child: ElevatedButton.icon(
                      onPressed: _resumeFromSaved,
                      icon: const Icon(Icons.play_arrow),
                      label: Text(
                        'Продолжить с ${_formatDuration(_savedPosition!)}',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: DesignColors.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      VideoProgressIndicator(
                        controller,
                        allowScrubbing: true,
                        colors: const VideoProgressColors(
                          playedColor: DesignColors.primary,
                          bufferedColor: Colors.white54,
                          backgroundColor: Colors.white24,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            ValueListenableBuilder<VideoPlayerValue>(
                              valueListenable: controller,
                              builder: (context, value, _) {
                                return Text(
                                  _formatDuration(value.position),
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                );
                              },
                            ),
                            Text(
                              _formatDuration(controller.value.duration),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSeekButton(IconData icon, VoidCallback onPressed) {
    return Container(
      decoration: BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white),
      ),
    );
  }
}
