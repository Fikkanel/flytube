import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:audio_service/audio_service.dart';
import 'package:video_player/video_player.dart';
import '../providers/player_provider.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
       vsync: this,
       duration: const Duration(seconds: 15),
    )..repeat();

    // Hide mini player when entering full player
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PlayerProvider>().hideMiniVideoPlayer();
    });
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${duration.inHours > 0 ? '${duration.inHours}:' : ''}$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          final provider = context.read<PlayerProvider>();
          if (provider.currentMode == PlaybackMode.video) {
            provider.showMiniVideoPlayer();
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Playing From Search'),
          centerTitle: true,
        ),
        body: Consumer<PlayerProvider>(
          builder: (context, provider, child) {
            final video = provider.currentVideo;
            if (video == null) {
               return const Center(child: Text("No video selected."));
            }

            if (provider.errorMessage != null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.redAccent, size: 60),
                      const SizedBox(height: 16),
                      Text(
                        provider.errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              );
            }


            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Artwork / Video Display
                _buildMediaDisplay(context, provider, video),

                const SizedBox(height: 32),

                // Title and Author
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Text(
                    video.title,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  video.author,
                  style: const TextStyle(fontSize: 16, color: Colors.white54),
                ),
                
                const SizedBox(height: 32),

                // Progress Bar
                _buildProgressBar(context, provider, video),

                const SizedBox(height: 24),

                // Player Controls
                _buildControls(context, provider),
              ],
            );
          },
        ),
      ),
    );
  }

  // ===========================================================================
  // Media Display — Audio artwork or Video player
  // ===========================================================================

  Widget _buildMediaDisplay(BuildContext context, PlayerProvider provider, dynamic video) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: provider.currentMode == PlaybackMode.video
          ? _buildVideoPlayer(context, provider)
          : _buildRotatingArtwork(context, provider, video),
    );
  }

  Widget _buildRotatingArtwork(BuildContext context, PlayerProvider provider, dynamic video) {
    return StreamBuilder<PlaybackState>(
      key: const ValueKey('audio_artwork'),
      stream: provider.playbackStateStream,
      builder: (context, snapshot) {
        final playing = snapshot.data?.playing ?? false;
        if (playing) {
          if (!_rotationController.isAnimating) _rotationController.forward();
        } else {
          if (_rotationController.isAnimating) _rotationController.stop();
        }

        return AnimatedBuilder(
          animation: _rotationController,
          builder: (context, child) {
            return Transform.rotate(
              angle: _rotationController.value * 2.0 * 3.141592653589793,
              child: child,
            );
          },
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.4),
                  blurRadius: 40,
                  offset: const Offset(0, 10),
                )
              ],
              image: DecorationImage(
                image: CachedNetworkImageProvider(video.thumbnail),
                fit: BoxFit.cover,
              ),
            ),
          ),
        );
      }
    );
  }

  Widget _buildVideoPlayer(BuildContext context, PlayerProvider provider) {
    if (provider.isSwitchingMode || !provider.isVideoReady || provider.videoController == null) {
      return Container(
        key: const ValueKey('video_loading'),
        width: double.infinity,
        height: 220,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Color(0xFF1DB954)),
              SizedBox(height: 12),
              Text('Memuat video...', style: TextStyle(color: Colors.white54)),
            ],
          ),
        ),
      );
    }

    return Container(
      key: const ValueKey('video_player'),
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
            blurRadius: 30,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AspectRatio(
          aspectRatio: provider.videoController!.value.aspectRatio,
          child: VideoPlayer(provider.videoController!),
        ),
      ),
    );
  }

  // ===========================================================================
  // Progress Bar — unified for both modes
  // ===========================================================================

  Widget _buildProgressBar(BuildContext context, PlayerProvider provider, dynamic video) {
    if (provider.currentMode == PlaybackMode.video && provider.videoController != null) {
      // Video mode — use video controller for position
      return ValueListenableBuilder(
        valueListenable: provider.videoController!,
        builder: (context, VideoPlayerValue value, child) {
          final position = value.position;
          final duration = value.duration;

          return _buildSlider(
            context,
            provider,
            position,
            duration,
            onSeek: (pos) => provider.videoSeek(pos),
          );
        },
      );
    }

    // Audio mode — use audio service position stream
    return StreamBuilder<Duration>(
      stream: provider.positionStream,
      builder: (context, positionSnapshot) {
        final position = positionSnapshot.data ?? Duration.zero;
        final duration = Duration(seconds: video.lengthSeconds);
        
        return _buildSlider(
          context,
          provider,
          position,
          duration,
          onSeek: (pos) => provider.audioHandler.seek(pos),
        );
      }
    );
  }

  Widget _buildSlider(
    BuildContext context,
    PlayerProvider provider,
    Duration position,
    Duration duration, {
    required void Function(Duration) onSeek,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        children: [
          Slider(
            value: position.inSeconds.toDouble().clamp(
                0.0,
                duration.inSeconds.toDouble() > 0
                    ? duration.inSeconds.toDouble()
                    : 1.0),
            max: duration.inSeconds.toDouble() > 0
                ? duration.inSeconds.toDouble()
                : 1.0,
            onChanged: (value) {
              onSeek(Duration(seconds: value.toInt()));
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_formatDuration(position),
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 12)),
                Text(_formatDuration(duration),
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          )
        ],
      ),
    );
  }

  // ===========================================================================
  // Controls
  // ===========================================================================

  Widget _buildControls(BuildContext context, PlayerProvider provider) {
    if (provider.currentMode == PlaybackMode.video) {
      return _buildVideoControls(context, provider);
    }
    return _buildAudioControls(context, provider);
  }

  Widget _buildAudioControls(BuildContext context, PlayerProvider provider) {
    return StreamBuilder<PlaybackState>(
      stream: provider.playbackStateStream,
      builder: (context, snapshot) {
        final playing = snapshot.data?.playing ?? false;
        final processingState = snapshot.data?.processingState ?? AudioProcessingState.idle;

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Repeat
            IconButton(
              iconSize: 32,
              icon: Icon(
                 snapshot.data?.repeatMode == AudioServiceRepeatMode.one ? Icons.repeat_one : Icons.repeat,
                 color: snapshot.data?.repeatMode == AudioServiceRepeatMode.none ? Colors.white54 : Theme.of(context).primaryColor,
              ),
              onPressed: () {
                 final current = snapshot.data?.repeatMode ?? AudioServiceRepeatMode.none;
                 if (current == AudioServiceRepeatMode.none) {
                   provider.audioHandler.setRepeatMode(AudioServiceRepeatMode.all);
                 } else if (current == AudioServiceRepeatMode.all) {
                   provider.audioHandler.setRepeatMode(AudioServiceRepeatMode.one);
                 } else {
                   provider.audioHandler.setRepeatMode(AudioServiceRepeatMode.none);
                 }
              },
            ),
            // Previous
            IconButton(
              iconSize: 48,
              icon: const Icon(Icons.skip_previous),
              onPressed: () => provider.audioHandler.skipToPrevious(),
            ),
            const SizedBox(width: 8),
            // Play/Pause
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                iconSize: 64,
                color: Colors.white,
                icon: provider.isLoadingStream || processingState == AudioProcessingState.buffering
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Icon(playing ? Icons.pause : Icons.play_arrow),
                onPressed: () {
                  if (playing) {
                    provider.audioHandler.pause();
                  } else {
                    provider.audioHandler.play();
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            // Next
            IconButton(
              iconSize: 48,
              icon: const Icon(Icons.skip_next),
              onPressed: () => provider.audioHandler.skipToNext(),
            ),
            // Mode toggle — switch to video
            _buildModeToggleButton(context, provider),
          ],
        );
      }
    );
  }

  Widget _buildVideoControls(BuildContext context, PlayerProvider provider) {
    final playing = provider.isVideoPlaying;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Queue
        IconButton(
          iconSize: 32,
          icon: const Icon(Icons.queue_music, color: Colors.white54),
          onPressed: () => _showQueueBottomSheet(context, provider),
        ),
        // Previous
        IconButton(
          iconSize: 48,
          icon: const Icon(Icons.skip_previous),
          onPressed: () => provider.audioHandler.skipToPrevious(),
        ),
        const SizedBox(width: 8),
        // Play/Pause
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            iconSize: 64,
            color: Colors.white,
            icon: provider.isSwitchingMode
                ? const CircularProgressIndicator(color: Colors.white)
                : Icon(playing ? Icons.pause : Icons.play_arrow),
            onPressed: () {
              if (playing) {
                provider.videoPause();
              } else {
                provider.videoPlay();
              }
            },
          ),
        ),
        const SizedBox(width: 8),
        // Next
        IconButton(
          iconSize: 48,
          icon: const Icon(Icons.skip_next),
          onPressed: () => provider.audioHandler.skipToNext(),
        ),
        // Mode toggle — switch to audio
        _buildModeToggleButton(context, provider),
      ],
    );
  }

  /// Toggle button: MP3 ↔ MP4
  Widget _buildModeToggleButton(BuildContext context, PlayerProvider provider) {
    final isVideo = provider.currentMode == PlaybackMode.video;
    return IconButton(
      iconSize: 32,
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: Icon(
          isVideo ? Icons.music_note : Icons.videocam,
          key: ValueKey(isVideo),
          color: Theme.of(context).primaryColor,
        ),
      ),
      tooltip: isVideo ? 'Beralih ke MP3' : 'Beralih ke MP4',
      onPressed: provider.isSwitchingMode ? null : () => provider.toggleMode(),
    );
  }

  void _showQueueBottomSheet(BuildContext context, PlayerProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF181818),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StreamBuilder<List<MediaItem>>(
          stream: provider.audioHandler.queue,
          builder: (context, snapshot) {
            final queue = snapshot.data ?? [];
            if (queue.isEmpty) {
              return const SizedBox(height: 100, child: Center(child: Text("Antrean kosong")));
            }
            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 16),
              itemCount: queue.length,
              itemBuilder: (context, index) {
                final item = queue[index];
                return ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: CachedNetworkImage(
                      imageUrl: item.artUri.toString(),
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      errorWidget: (c, u, e) => const Icon(Icons.music_note),
                    ),
                  ),
                  title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white)),
                  subtitle: Text(item.artist ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54)),
                  trailing: IconButton(
                    icon: const Icon(Icons.play_arrow, color: Colors.white54),
                    onPressed: () {
                      provider.audioHandler.skipToQueueItem(index);
                      Navigator.pop(context);
                    },
                  ),
                );
              },
            );
          }
        );
      }
    );
  }
}
