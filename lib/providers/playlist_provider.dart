import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/playlist_model.dart';
import '../models/video_model.dart';

class PlaylistProvider extends ChangeNotifier {
  static const String _playlistsKey = 'flytube_playlists';
  List<PlaylistModel> _playlists = [];
  bool _isLoading = true;

  List<PlaylistModel> get playlists => _playlists;
  bool get isLoading => _isLoading;

  PlaylistProvider() {
    _loadPlaylists();
  }

  Future<void> _loadPlaylists() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String>? playlistsJson = prefs.getStringList(_playlistsKey);
      
      if (playlistsJson != null) {
        _playlists = playlistsJson.map((jsonStr) => PlaylistModel.fromJson(jsonStr)).toList();
      }
    } catch (e) {
      debugPrint("Gagal memuat playlist: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _savePlaylists() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final playlistsJson = _playlists.map((p) => p.toJson()).toList();
      await prefs.setStringList(_playlistsKey, playlistsJson);
    } catch (e) {
      debugPrint("Gagal menyimpan playlist: $e");
    }
  }

  Future<void> createPlaylist(String name) async {
    final newPlaylist = PlaylistModel(
      id: const Uuid().v4(),
      name: name,
      videos: [],
    );
    _playlists.add(newPlaylist);
    notifyListeners();
    await _savePlaylists();
  }

  Future<void> deletePlaylist(String id) async {
    _playlists.removeWhere((p) => p.id == id);
    notifyListeners();
    await _savePlaylists();
  }

  Future<void> addVideoToPlaylist(String playlistId, VideoModel video) async {
    final index = _playlists.indexWhere((p) => p.id == playlistId);
    if (index != -1) {
      final playlist = _playlists[index];
      // Hindari duplikat video dalam satu playlist
      if (!playlist.videos.any((v) => v.videoId == video.videoId)) {
        final updatedVideos = List<VideoModel>.from(playlist.videos)..add(video);
        _playlists[index] = playlist.copyWith(videos: updatedVideos);
        notifyListeners();
        await _savePlaylists();
      }
    }
  }

  Future<void> removeVideoFromPlaylist(String playlistId, String videoId) async {
    final index = _playlists.indexWhere((p) => p.id == playlistId);
    if (index != -1) {
      final playlist = _playlists[index];
      final updatedVideos = playlist.videos.where((v) => v.videoId != videoId).toList();
      _playlists[index] = playlist.copyWith(videos: updatedVideos);
      notifyListeners();
      await _savePlaylists();
    }
  }
}
