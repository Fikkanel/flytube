import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../providers/player_provider.dart';
import '../screens/player_screen.dart';

/// A draggable mini video player that floats over other content.
/// Appears when user navigates back from player screen while in video mode.
class MiniVideoPlayer extends StatefulWidget {
  const MiniVideoPlayer({super.key});

  @override
  State<MiniVideoPlayer> createState() => _MiniVideoPlayerState();
}

class _MiniVideoPlayerState extends State<MiniVideoPlayer>
    with SingleTickerProviderStateMixin {
  Offset _position = const Offset(double.infinity, double.infinity);
  bool _initialized = false;
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  static const double _width = 180;
  static const double _height = 101; // 16:9

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _initPosition(BuildContext context) {
    if (!_initialized) {
      final size = MediaQuery.of(context).size;
      _position = Offset(
        size.width - _width - 16,
        size.height - _height - 140, // Above bottom nav
      );
      _initialized = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (context, provider, child) {
        if (!provider.showMiniPlayer || provider.videoController == null) {
          return const SizedBox.shrink();
        }

        _initPosition(context);

        return Positioned(
          left: _position.dx,
          top: _position.dy,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: GestureDetector(
              onPanUpdate: (details) {
                setState(() {
                  _position += details.delta;
                  // Clamp to screen bounds
                  final size = MediaQuery.of(context).size;
                  _position = Offset(
                    _position.dx.clamp(0, size.width - _width),
                    _position.dy.clamp(0, size.height - _height - 80),
                  );
                });
              },
              onTap: () {
                // Navigate to full player
                provider.hideMiniVideoPlayer();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PlayerScreen(),
                  ),
                );
              },
              child: _buildMiniPlayer(context, provider),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMiniPlayer(BuildContext context, PlayerProvider provider) {
    return Material(
      color: Colors.transparent,
      elevation: 12,
      borderRadius: BorderRadius.circular(12),
      shadowColor: Colors.black54,
      child: Container(
        width: _width,
        height: _height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.4),
            width: 1.5,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              // Video
              SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: provider.videoController!.value.size.width,
                    height: provider.videoController!.value.size.height,
                    child: VideoPlayer(provider.videoController!),
                  ),
                ),
              ),

              // Gradient overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.6),
                    ],
                  ),
                ),
              ),

              // Controls overlay
              Positioned(
                bottom: 4,
                left: 8,
                right: 8,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Play/Pause
                    GestureDetector(
                      onTap: () {
                        if (provider.isVideoPlaying) {
                          provider.videoPause();
                        } else {
                          provider.videoPlay();
                        }
                      },
                      child: Icon(
                        provider.isVideoPlaying
                            ? Icons.pause
                            : Icons.play_arrow,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    // Close button — switch to audio
                    GestureDetector(
                      onTap: () {
                        provider.switchToAudio();
                      },
                      child: const Icon(
                        Icons.close,
                        color: Colors.white70,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
