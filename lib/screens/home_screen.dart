import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:audio_service/audio_service.dart';
import '../providers/search_provider.dart';
import '../providers/player_provider.dart';
import '../providers/playlist_provider.dart';
import '../models/video_model.dart';
import 'player_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isSuggesting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final s = context.read<SearchProvider>().lastQuery;
      if (s.isNotEmpty) {
        _searchController.text = s;
      }
    });
    _searchFocusNode.addListener(() {
      setState(() {
        _isSuggesting = _searchFocusNode.hasFocus && _searchController.text.isNotEmpty;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
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
            actions: [
              Consumer<PlayerProvider>(
                builder: (context, playerProvider, child) {
                  return IconButton(
                    icon: Icon(
                      playerProvider.isAntiBlokirEnabled ? Icons.shield : Icons.shield_outlined,
                      color: playerProvider.isAntiBlokirEnabled ? const Color(0xFF1DB954) : Colors.white54,
                    ),
                    onPressed: () {
                      playerProvider.toggleAntiBlokir();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(playerProvider.isAntiBlokirEnabled 
                            ? 'Mode Anti-Blokir Aktif' 
                            : 'Mode Anti-Blokir Mati'),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                    tooltip: 'Mode Anti-Blokir (Gunakan jika Wi-Fi bermasalah)',
                  );
                },
              ),
            ],
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
                      focusNode: _searchFocusNode,
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
                            context.read<SearchProvider>().clearSuggestions();
                          },
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _isSuggesting = _searchFocusNode.hasFocus && value.isNotEmpty;
                        });
                        context.read<SearchProvider>().fetchSuggestions(value);
                      },
                      onSubmitted: (value) {
                        setState(() {
                          _isSuggesting = false;
                        });
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

              if (_isSuggesting && searchProvider.suggestions.isNotEmpty) {
                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final suggestion = searchProvider.suggestions[index];
                      return ListTile(
                        leading: const Icon(Icons.history, color: Colors.white24),
                        title: Text(suggestion, style: const TextStyle(color: Colors.white70)),
                        trailing: const Icon(Icons.north_west, color: Colors.white24, size: 18),
                        onTap: () {
                          _searchController.text = suggestion;
                          _searchFocusNode.unfocus();
                          setState(() {
                            _isSuggesting = false;
                          });
                          searchProvider.search(suggestion);
                        },
                      );
                    },
                    childCount: searchProvider.suggestions.length,
                  ),
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
      // Mini player is now handled by _AppShell overlay globally
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
      trailing: PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, color: Colors.white54),
        color: const Color(0xFF181818),
        onSelected: (value) {
          if (value == 'queue') {
            context.read<PlayerProvider>().addToQueue(video);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Ditambahkan ke Antrean'), duration: Duration(seconds: 1)),
            );
          } else if (value == 'playlist') {
            _showAddToPlaylistDialog(context, video);
          }
        },
        itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
          const PopupMenuItem<String>(
            value: 'queue',
            child: Text('Tambahkan ke Antrean', style: TextStyle(color: Colors.white)),
          ),
          const PopupMenuItem<String>(
            value: 'playlist',
            child: Text('Simpan ke Playlist', style: TextStyle(color: Colors.white)),
          ),
        ],
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

  void _showAddToPlaylistDialog(BuildContext context, VideoModel video) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF181818),
          title: const Text('Simpan ke Playlist'),
          content: SizedBox(
            width: double.maxFinite,
            child: Consumer<PlaylistProvider>(
              builder: (context, provider, child) {
                if (provider.playlists.isEmpty) {
                  return const Text('Belum ada playlist.', style: TextStyle(color: Colors.white54));
                }
                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: provider.playlists.length,
                  itemBuilder: (context, index) {
                    final playlist = provider.playlists[index];
                    return ListTile(
                      title: Text(playlist.name, style: const TextStyle(color: Colors.white)),
                      onTap: () {
                        provider.addVideoToPlaylist(playlist.id, video);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Tersimpan di ${playlist.name}')),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal', style: TextStyle(color: Colors.white54)),
            ),
          ],
        );
      },
    );
  }
}
