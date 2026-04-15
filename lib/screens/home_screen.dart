import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:audio_service/audio_service.dart';
import '../providers/search_provider.dart';
import '../providers/player_provider.dart';
import '../models/video_model.dart';
import 'player_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final s = context.read<SearchProvider>().lastQuery;
      if (s.isNotEmpty) {
        _searchController.text = s;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            pinned: false,
            snap: true,
            title: const Text('FlyTube', style: TextStyle(fontWeight: FontWeight.bold)),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(60),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Search song or video...",
                      hintStyle: const TextStyle(color: Colors.white54),
                      prefixIcon: const Icon(Icons.search, color: Colors.white54),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(16),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white54),
                        onPressed: () {
                          _searchController.clear();
                        },
                      ),
                    ),
                    onSubmitted: (value) {
                      context.read<SearchProvider>().search(value);
                    },
                  ),
                ),
              ),
            ),
          ),
          Consumer<SearchProvider>(
            builder: (context, searchProvider, child) {
              if (searchProvider.isLoading) {
                return const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator(color: Color(0xFF1DB954))),
                );
              }

              if (searchProvider.errorMessage != null) {
                return SliverFillRemaining(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        searchProvider.errorMessage!,
                        style: const TextStyle(color: Colors.redAccent),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                );
              }

              if (searchProvider.results.isEmpty && searchProvider.lastQuery.isEmpty) {
                return const SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                         Icon(Icons.library_music_rounded, size: 72, color: Color(0xFF1DB954)),
                         SizedBox(height: 24),
                         Text(
                           'Selamat Datang di FlyTube',
                           style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                         ),
                         SizedBox(height: 8),
                         Text(
                           'Cari dan putar lagu bebas iklan sekarang!',
                           style: TextStyle(color: Colors.white54),
                         ),
                      ],
                    ),
                  ),
                );
              }

              if (searchProvider.results.isEmpty) {
                return const SliverFillRemaining(
                  child: Center(child: Text('Tidak ada hasil ditemukan.', style: TextStyle(color: Colors.white54))),
                );
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final video = searchProvider.results[index];
                    return _buildVideoItem(context, video);
                  },
                  childCount: searchProvider.results.length,
                ),
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: _buildMiniPlayer(),
    );
  }

  Widget _buildVideoItem(BuildContext context, VideoModel video) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: video.thumbnail,
          width: 80,
          height: 60,
          fit: BoxFit.cover,
          errorWidget: (c, u, e) => Container(color: Colors.white10, width: 80, height: 60, child: const Icon(Icons.music_note, color: Colors.white54)),
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
        icon: const Icon(Icons.playlist_add, color: Colors.white54),
        onPressed: () {
          context.read<PlayerProvider>().addToQueue(video);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ditambahkan ke Antrean'), 
              duration: Duration(seconds: 1),
            ),
          );
        },
      ),
      onTap: () {
        context.read<PlayerProvider>().playVideo(video);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const PlayerScreen()),
        );
      },
    );
  }

  Widget _buildMiniPlayer() {
    return Consumer<PlayerProvider>(
      builder: (context, playerProvider, child) {
        final currentVideo = playerProvider.currentVideo;
        if (currentVideo == null) return const SizedBox.shrink();

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const PlayerScreen()),
            );
          },
          child: Container(
            color: const Color(0xFF181818),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: CachedNetworkImage(
                    imageUrl: currentVideo.thumbnail,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    errorWidget: (context, url, error) => const Icon(Icons.music_note),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentVideo.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        currentVideo.author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                StreamBuilder<PlaybackState>(
                  stream: playerProvider.playbackStateStream,
                  builder: (context, snapshot) {
                    final playing = snapshot.data?.playing ?? false;
                    return IconButton(
                      icon: Icon(playing ? Icons.pause : Icons.play_arrow, color: Colors.white),
                      onPressed: () {
                        if (playing) {
                          playerProvider.audioHandler.pause();
                        } else {
                          playerProvider.audioHandler.play();
                        }
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
