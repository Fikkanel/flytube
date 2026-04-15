import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:audio_service/audio_service.dart';
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
    return Scaffold(
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
              // Artwork Box with Rotation
              StreamBuilder<PlaybackState>(
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
              ),
              const SizedBox(height: 48),

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
              StreamBuilder<Duration>(
                stream: provider.positionStream,
                builder: (context, positionSnapshot) {
                  final position = positionSnapshot.data ?? Duration.zero;
                  final duration = Duration(seconds: video.lengthSeconds);
                  
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      children: [
                        Slider(
                          value: position.inSeconds.toDouble().clamp(0.0, duration.inSeconds.toDouble() > 0 ? duration.inSeconds.toDouble() : 1.0),
                          max: duration.inSeconds.toDouble() > 0 ? duration.inSeconds.toDouble() : 1.0,
                          onChanged: (value) {
                            provider.audioHandler.seek(Duration(seconds: value.toInt()));
                          },
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_formatDuration(position), style: const TextStyle(color: Colors.white54, fontSize: 12)),
                              Text(_formatDuration(duration), style: const TextStyle(color: Colors.white54, fontSize: 12)),
                            ],
                          ),
                        )
                      ],
                    ),
                  );
                }
              ),

              const SizedBox(height: 24),

              // Player Controls
              StreamBuilder<PlaybackState>(
                stream: provider.playbackStateStream,
                builder: (context, snapshot) {
                  final playing = snapshot.data?.playing ?? false;
                  final processingState = snapshot.data?.processingState ?? AudioProcessingState.idle;

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
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
                      IconButton(
                        iconSize: 48,
                        icon: const Icon(Icons.skip_previous),
                        onPressed: () => provider.audioHandler.skipToPrevious(),
                      ),
                      const SizedBox(width: 8),
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
                      IconButton(
                        iconSize: 48,
                        icon: const Icon(Icons.skip_next),
                        onPressed: () => provider.audioHandler.skipToNext(),
                      ),
                      IconButton(
                        iconSize: 32,
                        icon: const Icon(Icons.queue_music, color: Colors.white54),
                        onPressed: () => _showQueueBottomSheet(context, provider),
                      ),
                    ],
                  );
                }
              ),
            ],
          );
        },
      ),
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
