import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/playlist_model.dart';
import '../models/video_model.dart';
import '../providers/playlist_provider.dart';
import '../providers/player_provider.dart';
import 'player_screen.dart';

class PlaylistDetailScreen extends StatelessWidget {
  final PlaylistModel playlist;

  const PlaylistDetailScreen({super.key, required this.playlist});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(playlist.name),
      ),
      body: Consumer<PlaylistProvider>(
        builder: (context, provider, child) {
          // Find the updated playlist from provider
          final currentPlaylist = provider.playlists.firstWhere(
            (p) => p.id == playlist.id,
            orElse: () => playlist,
          );

          if (currentPlaylist.videos.isEmpty) {
            return const Center(
              child: Text('Playlist ini masih kosong.', style: TextStyle(color: Colors.white54)),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: currentPlaylist.videos.length,
            itemBuilder: (context, index) {
              final video = currentPlaylist.videos[index];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: video.thumbnail,
                    width: 80,
                    height: 60,
                    fit: BoxFit.cover,
                    errorWidget: (c, u, e) => Container(
                      color: Colors.white10,
                      width: 80,
                      height: 60,
                      child: const Icon(Icons.music_note, color: Colors.white54),
                    ),
                  ),
                ),
                title: Text(
                  video.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  video.author,
                  style: const TextStyle(color: Colors.white54),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                  onPressed: () {
                    provider.removeVideoFromPlaylist(currentPlaylist.id, video.videoId);
                  },
                ),
                onTap: () {
                  // Replace queue with playlist and play this video
                  final playerProvider = context.read<PlayerProvider>();
                  playerProvider.clearQueue();
                  for (var v in currentPlaylist.videos) {
                    playerProvider.addToQueue(v);
                  }
                  playerProvider.playVideo(video);
                  
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const PlayerScreen()),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
